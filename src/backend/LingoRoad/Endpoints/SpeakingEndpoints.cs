using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public static class SpeakingEndpoints
{
    public static void MapSpeaking(this WebApplication app)
    {
        var g = app.MapGroup("/speaking").RequireAuthorization();

        g.MapPost("/attempts", async (IFormFile audio, [Microsoft.AspNetCore.Mvc.FromForm] string promptText,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db,
            IMlClient ml, IWebHostEnvironment env) =>
        {
            var dir = Path.Combine(env.ContentRootPath, "wwwroot", "uploads");
            Directory.CreateDirectory(dir);
            var path = Path.Combine(dir, $"{Guid.NewGuid():N}{Path.GetExtension(audio.FileName)}");
            await using (var fs = File.Create(path))
                await audio.CopyToAsync(fs);

            try
            {
                await using var stream = File.OpenRead(path);
                var score = await ml.ScoreSpeakingAsync(stream, audio.FileName, promptText);
                var attempt = new SpeakingAttempt
                {
                    UserId = user.UserId(), PromptText = promptText, AudioPath = path,
                    Transcript = score.Transcript, Total = score.Total,
                    ScoresJson = JsonSerializer.Serialize(score)
                };
                db.SpeakingAttempts.Add(attempt);
                await db.SaveChangesAsync();
                return Results.Ok(new { attemptId = attempt.Id, score.Transcript,
                    score.Accuracy, score.Completeness, score.Fluency, score.Total,
                    feedbackVi = score.FeedbackVi });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).DisableAntiforgery();

        g.MapGet("/attempts", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.SpeakingAttempts.Where(a => a.UserId == user.UserId())
                .OrderByDescending(a => a.CreatedAt)
                .Select(a => new { a.Id, a.PromptText, a.Transcript, a.Total, a.CreatedAt })
                .ToListAsync());
    }
}
