using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record CreateSavedWordRequest(string SkillCode, string Word, string Definition);

public static class SavedWordEndpoints
{
    public static void MapSavedWords(this WebApplication app)
    {
        var g = app.MapGroup("/words").RequireAuthorization();

        g.MapPost("/", async (CreateSavedWordRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var skill = await db.Skills.SingleOrDefaultAsync(s => s.Code == req.SkillCode);
            if (skill is null) return Results.BadRequest(new { error = "unknown_skill" });
            var word = new SavedWord
            {
                UserId = user.UserId(),
                SkillId = skill.Id,
                Word = req.Word,
                Definition = req.Definition,
            };
            db.SavedWords.Add(word);
            await db.SaveChangesAsync();
            return Results.Created($"/words/{word.Id}", Snapshot(word));
        });
    }

    private static object Snapshot(SavedWord word) => new
    {
        word.Id,
        word.Word,
        word.Definition,
        word.Note,
        word.CreatedAt,
        word.UpdatedAt,
    };
}
