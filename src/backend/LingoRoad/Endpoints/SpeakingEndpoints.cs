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
            var ext = Path.GetExtension(audio.FileName).ToLowerInvariant();
            if (ext is not (".webm" or ".mp3" or ".wav" or ".m4a" or ".ogg")) ext = ".bin";
            var fileName = $"{Guid.NewGuid():N}{ext}";
            var path = Path.Combine(dir, fileName);
            await using (var fs = File.Create(path))
                await audio.CopyToAsync(fs);

            try
            {
                await using var stream = File.OpenRead(path);
                var score = await ml.ScoreSpeakingAsync(stream, audio.FileName, promptText);
                var attempt = new SpeakingAttempt
                {
                    UserId = user.UserId(), PromptText = promptText,
                    AudioPath = Path.Combine("uploads", fileName),
                    Transcript = score.Transcript, Total = score.Total,
                    ScoresJson = JsonSerializer.Serialize(score)
                };
                db.SpeakingAttempts.Add(attempt);
                await db.SaveChangesAsync();
                return Results.Ok(new { attemptId = attempt.Id, score.Transcript,
                    score.Accuracy, score.Completeness, score.Fluency, score.Total,
                    feedbackVi = score.FeedbackVi });
            }
            catch (MlServiceUnavailableException)
            {
                try { File.Delete(path); } catch { /* best effort */ }
                return ApiResults.MlUnavailable();
            }
        }).DisableAntiforgery();

        g.MapGet("/attempts", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.SpeakingAttempts.Where(a => a.UserId == user.UserId())
                .OrderByDescending(a => a.CreatedAt)
                .Select(a => new { a.Id, a.PromptText, a.Transcript, a.Total, a.CreatedAt })
                .ToListAsync());
    }
}
