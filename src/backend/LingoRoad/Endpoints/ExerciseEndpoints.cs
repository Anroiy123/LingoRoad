using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record GenerateExercisesRequest(string SkillCode, string? Type);
public record SubmitExerciseRequest(string? Answer, Guid OperationId);
public record WritingEvalRequest(string TaskPrompt, string Essay);

public static class ExerciseEndpoints
{
    public static void MapExercises(this WebApplication app)
    {
        var g = app.MapGroup("/exercises").RequireAuthorization();

        g.MapPost("/generate", async (GenerateExercisesRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml) =>
        {
            var skill = await db.Skills.SingleOrDefaultAsync(s => s.Code == req.SkillCode);
            if (skill is null) return Results.BadRequest(new { error = "unknown_skill" });
            try
            {
                var res = await ml.GenerateExercisesAsync(new ExerciseGenRequest(
                    skill.Code, skill.Name, skill.CefrLevel, req.Type ?? "mcq", 3));
                var rows = res.Exercises.Select(e => new Exercise
                {
                    UserId = user.UserId(),
                    SkillId = skill.Id,
                    CefrLevel = skill.CefrLevel,
                    Type = req.Type ?? "mcq",
                    Stem = e.Stem,
                    OptionsJson = JsonSerializer.Serialize(e.Options),
                    CorrectAnswer = e.CorrectAnswer,
                    ExplanationVi = e.ExplanationVi
                }).ToList();
                db.Exercises.AddRange(rows);
                await db.SaveChangesAsync();
                return Results.Ok(rows.Select(r => new
                {
                    r.Id,
                    r.Stem,
                    options = JsonSerializer.Deserialize<string[]>(r.OptionsJson)
                }));
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).RequireRateLimiting("ml-upload");

        g.MapPost("/{id:guid}/submit", async (Guid id, SubmitExerciseRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db,
            MasteryService masteries) =>
        {
            if (req.OperationId == Guid.Empty || string.IsNullOrWhiteSpace(req.Answer))
                return ApiResults.Error("answer_and_operation_id_required");
            var userId = user.UserId();
            var answer = req.Answer.Trim();
            var replay = await db.ExerciseAnswerOperations.SingleOrDefaultAsync(o =>
                o.UserId == userId && o.OperationId == req.OperationId);
            if (replay is not null)
            {
                if (replay.ExerciseId != id || replay.Answer != answer)
                    return Results.Conflict(new { error = "idempotency_conflict" });
                return Results.Ok(AnswerSnapshot(replay));
            }
            var ex = await db.Exercises.SingleOrDefaultAsync(
                e => e.Id == id && e.UserId == userId);
            if (ex is null) return Results.NotFound();
            if (ex.AnsweredAt is not null)
                return Results.Conflict(new { error = "exercise_already_answered" });
            var correct = string.Equals(answer, ex.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            ex.AnsweredAt = DateTime.UtcNow;
            ex.SubmittedAnswer = answer;
            ex.IsCorrect = correct;
            await masteries.RecordAnswerAsync(userId, ex.SkillId, correct, saveChanges: false);
            var operation = new ExerciseAnswerOperation
            {
                UserId = userId,
                OperationId = req.OperationId,
                ExerciseId = id,
                Answer = answer,
                Correct = correct,
                CorrectAnswer = ex.CorrectAnswer,
                ExplanationVi = ex.ExplanationVi,
            };
            db.ExerciseAnswerOperations.Add(operation);
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ExerciseAnswerOperations.SingleOrDefaultAsync(o =>
                    o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.ExerciseId == id && replay.Answer == answer)
                    return Results.Ok(AnswerSnapshot(replay));
                return Results.Conflict(new { error = "exercise_already_answered" });
            }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                replay = await db.ExerciseAnswerOperations.SingleOrDefaultAsync(o =>
                    o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.ExerciseId == id && replay.Answer == answer)
                    return Results.Ok(AnswerSnapshot(replay));
                return Results.Conflict(new { error = "idempotency_conflict" });
            }
            return Results.Ok(AnswerSnapshot(operation));
        });

        app.MapPost("/writing/evaluate", async (WritingEvalRequest req, IMlClient ml) =>
        {
            try
            {
                return Results.Ok(await ml.EvaluateWritingAsync(
                new AweRequest(req.TaskPrompt, req.Essay)));
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).RequireAuthorization().RequireRateLimiting("ml-upload");
    }

    private static object AnswerSnapshot(ExerciseAnswerOperation operation) => new
    {
        operation.ExerciseId,
        operation.OperationId,
        operation.Correct,
        operation.CorrectAnswer,
        operation.ExplanationVi,
    };
}
