using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record GenerateExercisesRequest(string SkillCode, string? Type);
public record SubmitExerciseRequest(string Answer);
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
                    UserId = user.UserId(), SkillId = skill.Id, CefrLevel = skill.CefrLevel,
                    Type = req.Type ?? "mcq", Stem = e.Stem,
                    OptionsJson = JsonSerializer.Serialize(e.Options),
                    CorrectAnswer = e.CorrectAnswer, ExplanationVi = e.ExplanationVi
                }).ToList();
                db.Exercises.AddRange(rows);
                await db.SaveChangesAsync();
                return Results.Ok(rows.Select(r => new { r.Id, r.Stem,
                    options = JsonSerializer.Deserialize<string[]>(r.OptionsJson) }));
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });

        g.MapPost("/{id:guid}/submit", async (Guid id, SubmitExerciseRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db,
            MasteryService masteries) =>
        {
            var ex = await db.Exercises.SingleOrDefaultAsync(
                e => e.Id == id && e.UserId == user.UserId());
            if (ex is null) return Results.NotFound();
            var correct = string.Equals(req.Answer.Trim(), ex.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            if (ex.AnsweredAt is null)
            {
                ex.AnsweredAt = DateTime.UtcNow;
                await masteries.RecordAnswerAsync(user.UserId(), ex.SkillId, correct);
                await db.SaveChangesAsync();
            }
            return Results.Ok(new { correct, correctAnswer = ex.CorrectAnswer,
                explanationVi = ex.ExplanationVi });
        });

        app.MapPost("/writing/evaluate", async (WritingEvalRequest req, IMlClient ml) =>
        {
            try { return Results.Ok(await ml.EvaluateWritingAsync(
                new AweRequest(req.TaskPrompt, req.Essay))); }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).RequireAuthorization();
    }
}
