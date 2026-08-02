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
            var card = new ReviewCard
            {
                UserId = user.UserId(),
                SkillId = skill.Id,
                Front = req.Front,
                Back = req.Back
            };
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
                if (!Matches(replay, cardId, req))
                    return Results.Conflict(new { error = "idempotency_conflict" });
                return Results.Ok(Snapshot(replay));
            }
            var card = await db.ReviewCards.SingleOrDefaultAsync(
                c => c.Id == cardId && c.UserId == userId);
            if (card is null) return Results.NotFound();
            var now = DateTime.UtcNow;
            if (card.Due > now || card.Reps != req.ExpectedReps)
            {
                // A matching concurrent request may have committed after the first
                // operation lookup but before this card snapshot was read.
                replay = await db.ReviewGradeOperations.AsNoTracking().SingleOrDefaultAsync(
                    o => o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null)
                    return Matches(replay, cardId, req)
                        ? Results.Ok(Snapshot(replay))
                        : Results.Conflict(new { error = "idempotency_conflict" });
                if (card.Due > now)
                    return Results.Conflict(new { error = "review_not_due" });
                return Results.Conflict(new { error = "review_already_graded" });
            }
            Fsrs.Review(card, (Grade)req.Rating, now);
            var operation = new ReviewGradeOperation
            {
                UserId = userId,
                CardId = card.Id,
                OperationId = req.OperationId,
                Rating = req.Rating,
                ExpectedReps = req.ExpectedReps,
                Due = card.Due,
                State = card.State,
                Stability = card.Stability,
                Difficulty = card.Difficulty,
                Reps = card.Reps,
            };
            db.ReviewGradeOperations.Add(operation);
            db.LearningEvents.Add(new LearningEvent
            {
                UserId = userId,
                OperationId = req.OperationId,
                EventType = LearningEventTypes.ReviewGraded,
                ExerciseId = card.SourceExerciseId,
                SkillId = card.SkillId,
                Rating = req.Rating,
            });
            db.RewardLedgerEntries.Add(new RewardLedgerEntry
            {
                UserId = userId,
                SourceOperationId = req.OperationId,
                SourceType = RewardSources.ReviewGrade,
                SourceEntityId = card.Id,
                Xp = 5,
                Coins = 1,
                StreakQualified = true,
                QuestCode = "daily_review",
            });
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ReviewGradeOperations.SingleOrDefaultAsync(
                    o => o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && Matches(replay, cardId, req))
                    return Results.Ok(Snapshot(replay));
                return Results.Conflict(new { error = "review_already_graded" });
            }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ReviewGradeOperations.SingleOrDefaultAsync(
                    o => o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && Matches(replay, cardId, req))
                    return Results.Ok(Snapshot(replay));
                return Results.Conflict(new { error = "idempotency_conflict" });
            }
            return Results.Ok(Snapshot(operation));
        });
    }

    private static bool Matches(ReviewGradeOperation operation, Guid cardId, GradeRequest request) =>
        operation.CardId == cardId && operation.Rating == request.Rating &&
        operation.ExpectedReps == request.ExpectedReps;

    private static object Snapshot(ReviewGradeOperation operation) => new
    {
        id = operation.CardId,
        operation.OperationId,
        operation.Due,
        operation.State,
        stability = operation.Stability,
        difficulty = operation.Difficulty,
        operation.Reps,
    };
}
