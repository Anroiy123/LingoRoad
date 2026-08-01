using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record CreateCardRequest(string SkillCode, string Front, string Back);
public record GradeRequest(int Rating, Guid OperationId, int ExpectedReps);

public static class ReviewEndpoints
{
    public static void MapReviews(this WebApplication app)
    {
        var g = app.MapGroup("/reviews").RequireAuthorization();

        g.MapPost("/cards", async (CreateCardRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var skill = await db.Skills.SingleOrDefaultAsync(s => s.Code == req.SkillCode);
            if (skill is null) return Results.BadRequest(new { error = "unknown_skill" });
            var card = new ReviewCard { UserId = user.UserId(), SkillId = skill.Id,
                Front = req.Front, Back = req.Back };
            db.ReviewCards.Add(card);
            await db.SaveChangesAsync();
            return Results.Created($"/reviews/{card.Id}",
                new { card.Id, card.Front, card.Back, card.Due, card.State });
        });

        g.MapGet("/due", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.ReviewCards
                .Where(c => c.UserId == user.UserId() && c.Due <= DateTime.UtcNow)
                .OrderBy(c => c.Due)
                .Select(c => new { c.Id, c.Front, c.Back, c.Due, c.State, c.Reps })
                .ToListAsync());

        g.MapPost("/{cardId:guid}/grade", async (Guid cardId, GradeRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            if (req.Rating is < 1 or > 4) return Results.BadRequest(new { error = "rating_1_to_4" });
            if (req.OperationId == Guid.Empty || req.ExpectedReps < 0)
                return Results.BadRequest(new { error = "invalid_grade_request" });
            var userId = user.UserId();
            var replay = await db.ReviewGradeOperations.SingleOrDefaultAsync(
                o => o.UserId == userId && o.OperationId == req.OperationId);
            if (replay is not null)
            {
                if (replay.CardId != cardId || replay.Rating != req.Rating || replay.ExpectedReps != req.ExpectedReps)
                    return Results.Conflict(new { error = "idempotency_conflict" });
                return Results.Ok(Snapshot(replay));
            }
            var card = await db.ReviewCards.SingleOrDefaultAsync(
                c => c.Id == cardId && c.UserId == userId);
            if (card is null) return Results.NotFound();
            if (card.Due > DateTime.UtcNow)
                return Results.Conflict(new { error = "review_not_due" });
            if (card.Reps != req.ExpectedReps)
                return Results.Conflict(new { error = "review_already_graded" });
            Fsrs.Review(card, (Grade)req.Rating, DateTime.UtcNow);
            var operation = new ReviewGradeOperation
            {
                UserId = userId, CardId = card.Id, OperationId = req.OperationId,
                Rating = req.Rating, ExpectedReps = req.ExpectedReps, Due = card.Due,
                State = card.State, Stability = card.Stability, Difficulty = card.Difficulty, Reps = card.Reps,
            };
            db.ReviewGradeOperations.Add(operation);
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ReviewGradeOperations.SingleOrDefaultAsync(
                    o => o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.CardId == cardId && replay.Rating == req.Rating && replay.ExpectedReps == req.ExpectedReps)
                    return Results.Ok(Snapshot(replay));
                return Results.Conflict(new { error = "review_already_graded" });
            }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ReviewGradeOperations.SingleOrDefaultAsync(
                    o => o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.CardId == cardId && replay.Rating == req.Rating && replay.ExpectedReps == req.ExpectedReps)
                    return Results.Ok(Snapshot(replay));
                return Results.Conflict(new { error = "idempotency_conflict" });
            }
            return Results.Ok(Snapshot(operation));
        });
    }

    private static object Snapshot(ReviewGradeOperation operation) => new
    {
        id = operation.CardId, operation.OperationId, operation.Due, operation.State,
        stability = operation.Stability, difficulty = operation.Difficulty, operation.Reps,
    };
}
