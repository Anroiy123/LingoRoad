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
            var exerciseType = string.IsNullOrWhiteSpace(req.Type) ? "mcq" : req.Type.Trim();
            if (exerciseType is not ("mcq" or "cloze" or "reorder"))
                return ApiResults.Error("unsupported_exercise_type");
            List<Exercise> rows;
            try
            {
                var res = await ml.GenerateExercisesAsync(new ExerciseGenRequest(
                    skill.Code, skill.Name, skill.CefrLevel, exerciseType, 3));
                rows = res.Exercises.Select(e => new Exercise
                {
                    UserId = user.UserId(),
                    SkillId = skill.Id,
                    CefrLevel = skill.CefrLevel,
                    Type = exerciseType,
                    Stem = e.Stem,
                    OptionsJson = JsonSerializer.Serialize(e.Options),
                    CorrectAnswer = e.CorrectAnswer,
                    ExplanationVi = e.ExplanationVi
                }).ToList();
            }
            catch (MlInputRejectedException error) { return ApiResults.MlRejected(error); }
            catch (MlServiceUnavailableException)
            {
                var fallbackItems = await db.Items
                    .Where(item => item.SkillId == skill.Id && !item.IsDeleted &&
                        item.Type == exerciseType)
                    .OrderBy(item => item.StableId).Take(3).ToListAsync();
                if (fallbackItems.Count == 0) return ApiResults.MlUnavailable();
                rows = fallbackItems.Select((item, index) => new Exercise
                {
                    UserId = user.UserId(),
                    SourceItemId = item.Id,
                    Sequence = index,
                    SkillId = item.SkillId,
                    CefrLevel = item.CefrLevel,
                    Type = item.Type,
                    Stem = item.Stem,
                    OptionsJson = item.OptionsJson,
                    CorrectAnswer = item.CorrectAnswer,
                    ExplanationVi = item.ExplanationVi
                }).ToList();
            }
            db.Exercises.AddRange(rows);
            await db.SaveChangesAsync();
            return Results.Ok(rows.Select(r => new
            {
                r.Id,
                r.Stem,
                options = JsonSerializer.Deserialize<string[]>(r.OptionsJson)
            }));
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

        app.MapPost("/writing/evaluate", async (WritingEvalRequest req, IMlClient ml,
            System.Security.Claims.ClaimsPrincipal user, IConfiguration configuration,
            IWebHostEnvironment environment) =>
        {
            if (string.IsNullOrWhiteSpace(req.TaskPrompt) ||
                req.TaskPrompt.Trim().Length > 2000 ||
                string.IsNullOrWhiteSpace(req.Essay) || req.Essay.Trim().Length > 10000)
                return ApiResults.Error("invalid_writing_submission");
            if (!MlFeatureRollout.IsEnabled(configuration, environment,
                "Writing", user.UserId())) return ApiResults.FeatureDisabled();
            try
            {
                return Results.Ok(await ml.EvaluateWritingAsync(
                    new AweRequest(req.TaskPrompt.Trim(), req.Essay.Trim())));
            }
            catch (MlInputRejectedException error) { return ApiResults.MlRejected(error); }
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
