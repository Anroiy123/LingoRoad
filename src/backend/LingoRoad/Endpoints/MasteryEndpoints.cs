using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public static class MasteryEndpoints
{
    public static void MapMastery(this WebApplication app)
    {
        app.MapGet("/mastery", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.Masteries.Where(m => m.UserId == user.UserId())
                .Join(db.Skills, m => m.SkillId, s => s.Id, (m, s) => new
                    { skillCode = s.Code, skillName = s.Name, pCorrect = m.PCorrect, updatedAt = m.UpdatedAt })
                .ToListAsync()).RequireAuthorization();
    }
}
