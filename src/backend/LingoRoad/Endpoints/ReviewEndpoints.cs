using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record CreateCardRequest(string SkillCode, string Front, string Back);
public record GradeRequest(int Rating, Guid OperationId, int ExpectedReps, string? Answer = null);
public record CheckReviewAnswerRequest(string? Answer);

public static class ReviewEndpoints
{
    private static readonly string[] QuestionTypes = ["mcq", "cloze", "reorder"];

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

        g.MapGet("/mistakes", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.ReviewCards
                .Where(c => c.UserId == user.UserId() && c.SourceExerciseId != null)
                .OrderBy(c => c.Due)
                .Select(c => new { c.Id, c.Front, c.Back, c.Due, c.State, c.Reps })
                .ToListAsync());

        g.MapGet("/questions/due", async (int? limit,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var take = limit ?? 10;
            if (take is < 1 or > 10) return Results.BadRequest(new { error = "limit_1_to_10" });
            var userId = user.UserId();
            var due = await (from card in db.ReviewCards
                             join exercise in db.Exercises on card.SourceExerciseId equals exercise.Id
                             where card.UserId == userId && card.Due <= DateTime.UtcNow &&
                                   exercise.UserId == userId && exercise.LessonAttemptId != null &&
                                   exercise.IsCorrect == false && QuestionTypes.Contains(exercise.Type)
                             orderby card.Due
                             select new { card.Id, card.Reps, exercise.Type, exercise.Stem,
                                 exercise.OptionsJson }).ToListAsync();
            return Results.Ok(new
            {
                items = due.Take(take).Select(x => new
                {
                    x.Id,
                    x.Reps,
                    x.Type,
                    x.Stem,
                    options = JsonSerializer.Deserialize<string[]>(x.OptionsJson) ?? [],
                }),
                totalDue = due.Count,
            });
        });

        g.MapPost("/{cardId:guid}/check", async (Guid cardId, CheckReviewAnswerRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            if (string.IsNullOrWhiteSpace(req.Answer))
                return Results.BadRequest(new { error = "answer_required" });
            var userId = user.UserId();
            var card = await db.ReviewCards.SingleOrDefaultAsync(c => c.Id == cardId && c.UserId == userId);
            if (card is null) return Results.NotFound();
            if (card.Due > DateTime.UtcNow) return Results.Conflict(new { error = "review_not_due" });
            var exercise = await db.Exercises.SingleOrDefaultAsync(e =>
                e.Id == card.SourceExerciseId && e.UserId == userId && e.LessonAttemptId != null &&
                e.IsCorrect == false && QuestionTypes.Contains(e.Type));
            if (exercise is null) return Results.NotFound();
            var answer = req.Answer.Trim();
            return Results.Ok(new
            {
                correct = string.Equals(answer, exercise.CorrectAnswer.Trim(), StringComparison.OrdinalIgnoreCase),
                correctAnswer = exercise.CorrectAnswer,
                exercise.ExplanationVi,
            });
        });

        g.MapPost("/{cardId:guid}/grade", async (Guid cardId, GradeRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, MasteryService masteries) =>
        {
            if (req.Rating is < 1 or > 4) return Results.BadRequest(new { error = "rating_1_to_4" });
            if (req.OperationId == Guid.Empty || req.ExpectedReps < 0)
                return Results.BadRequest(new { error = "invalid_grade_request" });
            var userId = user.UserId();
            var submittedAnswer = string.IsNullOrWhiteSpace(req.Answer) ? null : req.Answer.Trim();
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
            var question = card.SourceExerciseId is null ? null : await db.Exercises.SingleOrDefaultAsync(e =>
                e.Id == card.SourceExerciseId && e.UserId == userId && e.LessonAttemptId != null &&
                e.IsCorrect == false && QuestionTypes.Contains(e.Type));
            if (card.SourceExerciseId is not null && question is null) return Results.NotFound();
            bool? correct = null;
            if (question is not null)
            {
                if (submittedAnswer is null) return Results.BadRequest(new { error = "answer_required" });
                correct = string.Equals(submittedAnswer, question.CorrectAnswer.Trim(),
                    StringComparison.OrdinalIgnoreCase);
                if ((!correct.Value && req.Rating != (int)Grade.Again) ||
                    (correct.Value && req.Rating is < (int)Grade.Hard or > (int)Grade.Easy))
                    return Results.BadRequest(new { error = "rating_does_not_match_answer" });
            }
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
            if (question is not null)
                await masteries.RecordAnswerAsync(userId, card.SkillId, correct!.Value, saveChanges: false);
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
                SubmittedAnswer = submittedAnswer,
                Correct = correct,
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
                Correct = correct,
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
        operation.ExpectedReps == request.ExpectedReps &&
        string.Equals(operation.SubmittedAnswer, Normalize(request.Answer), StringComparison.OrdinalIgnoreCase);

    private static string? Normalize(string? answer) => string.IsNullOrWhiteSpace(answer) ? null : answer.Trim();

    private static object Snapshot(ReviewGradeOperation operation) => new
    {
        id = operation.CardId,
        operation.OperationId,
        operation.Due,
        operation.State,
        stability = operation.Stability,
        difficulty = operation.Difficulty,
        operation.Reps,
        xp = 5,
        coins = 1,
    };
}
