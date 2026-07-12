using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record AdvisorQuestion(string Question);

public static class PathEndpoints
{
    private static async Task<List<PathStep>> BuildForUserAsync(
        AppDbContext db, Guid userId, int limit)
    {
        var user = await db.Users.FindAsync(userId);
        var mastery = await db.Masteries.Where(m => m.UserId == userId)
            .ToDictionaryAsync(m => m.SkillId, m => m.PCorrect);
        return PathBuilder.Build(await db.Skills.ToListAsync(),
            await db.SkillEdges.ToListAsync(), mastery, user!.TargetCefr, limit);
    }

    public static void MapPath(this WebApplication app)
    {
        var g = app.MapGroup("/path").RequireAuthorization();

        g.MapGet("", async (int? limit,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            (await BuildForUserAsync(db, user.UserId(), limit ?? 10))
            .Select(p => new { code = p.Skill.Code, name = p.Skill.Name,
                nameVi = p.Skill.NameVi, cefr = p.Skill.CefrLevel,
                mastery = p.Mastery, reason = p.Reason }));

        g.MapPost("/advisor", async (AdvisorQuestion req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml) =>
        {
            var path = await BuildForUserAsync(db, user.UserId(), 10);
            try
            {
                var res = await ml.AdvisorAsync(new AdvisorRequest(req.Question,
                    path.Select(p => new AdvisorSkillContext(
                        p.Skill.Code, p.Skill.Name, p.Mastery, p.Reason)).ToList(), "vi"));
                return Results.Ok(new { answer = res.Answer });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });
    }
}
