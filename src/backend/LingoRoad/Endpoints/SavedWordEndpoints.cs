using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record CreateSavedWordRequest(string SkillCode, string Word, string Definition);
public record UpdateSavedWordNoteRequest(string? Note);

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

        g.MapGet("/", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.SavedWords
                .Where(w => w.UserId == user.UserId())
                .OrderByDescending(w => w.CreatedAt)
                .Select(w => new
                {
                    w.Id,
                    w.Word,
                    w.Definition,
                    w.Note,
                    w.CreatedAt,
                    w.UpdatedAt,
                })
                .ToListAsync());

        g.MapPatch("/{id:guid}", async (Guid id, UpdateSavedWordNoteRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var word = await db.SavedWords.SingleOrDefaultAsync(
                w => w.Id == id && w.UserId == user.UserId());
            if (word is null) return Results.NotFound();
            word.Note = req.Note;
            word.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
            return Results.Ok(Snapshot(word));
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
