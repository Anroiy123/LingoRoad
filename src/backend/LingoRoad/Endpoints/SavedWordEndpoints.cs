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
            word.NextReviewAt = SavedWordSchedule.InitialDue(word.CreatedAt);
            db.SavedWords.Add(word);
            await db.SaveChangesAsync();
            return Results.Created($"/words/{word.Id}", Snapshot(word));
        });

        g.MapGet("/", async (bool? due,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var now = DateTime.UtcNow;
            var userId = user.UserId();
            var query = db.SavedWords.Where(w => w.UserId == userId);
            if (due == true) query = query.Where(w => w.NextReviewAt <= now);
            return await query
                .OrderByDescending(w => w.CreatedAt)
                .Select(w => new
                {
                    w.Id,
                    w.Word,
                    w.Definition,
                    w.Note,
                    w.CreatedAt,
                    w.UpdatedAt,
                    w.ReviewStage,
                    w.NextReviewAt,
                    IsDue = w.NextReviewAt <= now,
                })
                .ToListAsync();
        });

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

        g.MapDelete("/{id:guid}", async (Guid id,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var word = await db.SavedWords.SingleOrDefaultAsync(
                w => w.Id == id && w.UserId == user.UserId());
            if (word is null) return Results.NotFound();
            db.SavedWords.Remove(word);
            await db.SaveChangesAsync();
            return Results.NoContent();
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
        word.ReviewStage,
        word.NextReviewAt,
    };
}
