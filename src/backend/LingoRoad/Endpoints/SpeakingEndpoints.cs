using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public static class SpeakingEndpoints
{
    private const long MaxAudioBytes = 10 * 1024 * 1024;
    private const double MaxDurationSeconds = 120;
    private static readonly Dictionary<string, (string Canonical, string Extension)> AudioTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["audio/webm"] = ("audio/webm", ".webm"),
            ["audio/mpeg"] = ("audio/mpeg", ".mp3"),
            ["audio/wav"] = ("audio/wav", ".wav"),
            ["audio/x-wav"] = ("audio/wav", ".wav"),
            ["audio/mp4"] = ("audio/mp4", ".m4a"),
            ["audio/x-m4a"] = ("audio/mp4", ".m4a"),
            ["audio/ogg"] = ("audio/ogg", ".ogg")
        };

    public static void MapSpeaking(this WebApplication app)
    {
        var g = app.MapGroup("/speaking").RequireAuthorization();

        g.MapPost("/attempts", UploadAsync)
            .DisableAntiforgery()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAudioBytes + 1024 * 1024))
            .WithMetadata(new RequestFormLimitsAttribute
            { MultipartBodyLengthLimit = MaxAudioBytes + 1024 * 1024 })
            .RequireRateLimiting("ml-upload");

        g.MapGet("/attempts", async (System.Security.Claims.ClaimsPrincipal user,
            AppDbContext db) =>
            await db.SpeakingAttempts.Where(a => a.UserId == user.UserId())
                .OrderByDescending(a => a.CreatedAt)
                .Select(a => new
                {
                    a.Id,
                    a.PromptText,
                    a.Transcript,
                    a.Total,
                    a.DurationSeconds,
                    a.ModelVersion,
                    a.FeedbackVi,
                    a.CreatedAt
                }).ToListAsync());
    }

    private static async Task<IResult> UploadAsync(IFormFile audio,
        [FromForm] string promptText, System.Security.Claims.ClaimsPrincipal user,
        AppDbContext db, IMlClient ml, IWebHostEnvironment env,
        IConfiguration configuration, ILoggerFactory loggerFactory,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(promptText) || promptText.Trim().Length > 1000)
            return ApiResults.Error("invalid_prompt");
        if (!MlFeatureRollout.IsEnabled(configuration, env,
            "Speaking", user.UserId())) return ApiResults.FeatureDisabled();
        if (audio.Length == 0) return ApiResults.Error("audio_empty");
        if (audio.Length > MaxAudioBytes)
            return Results.Json(new { error = "audio_too_large" }, statusCode: 413);

        var declaredType = audio.ContentType.Split(';', 2)[0].Trim();
        if (!AudioTypes.TryGetValue(declaredType, out var audioType))
            return Results.Json(new { error = "unsupported_audio_type" }, statusCode: 415);

        var tempDirectory = ResolveTempDirectory(configuration, env);
        Directory.CreateDirectory(tempDirectory);
        var path = Path.Combine(tempDirectory, $"{Guid.NewGuid():N}{audioType.Extension}");
        var logger = loggerFactory.CreateLogger("SpeakingUpload");
        try
        {
            await using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write,
                FileShare.None, 81920, FileOptions.Asynchronous))
                await audio.CopyToAsync(output, cancellationToken);

            SpeakingScoreResponse score;
            await using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read,
                FileShare.Read, 81920, FileOptions.Asynchronous | FileOptions.DeleteOnClose))
            {
                var header = new byte[Math.Min(16, checked((int)stream.Length))];
                _ = await stream.ReadAsync(header, cancellationToken);
                stream.Position = 0;
                if (!string.Equals(DetectMime(header), audioType.Canonical,
                    StringComparison.OrdinalIgnoreCase))
                    return Results.Json(new { error = "audio_signature_mismatch" }, statusCode: 415);
                score = await ml.ScoreSpeakingAsync(stream,
                    $"speaking{audioType.Extension}", promptText.Trim(), cancellationToken);
            }

            if (score.DurationSeconds <= 0)
                return ApiResults.Error("audio_duration_invalid");
            if (score.DurationSeconds > MaxDurationSeconds)
                return Results.Json(new { error = "audio_too_long" }, statusCode: 413);

            var attempt = new SpeakingAttempt
            {
                UserId = user.UserId(),
                PromptText = promptText.Trim(),
                Transcript = score.Transcript,
                Total = score.Total,
                DurationSeconds = score.DurationSeconds,
                ModelVersion = score.ModelVersion,
                FeedbackVi = score.FeedbackVi,
                ScoresJson = JsonSerializer.Serialize(score)
            };
            db.SpeakingAttempts.Add(attempt);
            await db.SaveChangesAsync(cancellationToken);
            return Results.Ok(new
            {
                attemptId = attempt.Id,
                score.Transcript,
                score.Accuracy,
                score.Completeness,
                score.Fluency,
                score.Total,
                score.DurationSeconds,
                score.ModelVersion,
                feedbackVi = score.FeedbackVi
            });
        }
        catch (MlInputRejectedException error)
        {
            return ApiResults.MlRejected(error);
        }
        catch (MlServiceUnavailableException)
        {
            return ApiResults.MlUnavailable();
        }
        finally
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch (Exception error)
            {
                logger.LogError(error, "Không thể xóa speaking audio tạm {AudioPath}", path);
            }
        }
    }

    private static string ResolveTempDirectory(IConfiguration configuration,
        IWebHostEnvironment environment)
    {
        var configured = configuration["Storage:TempPath"] ?? "temp/speaking";
        var directory = Path.GetFullPath(Path.IsPathRooted(configured)
            ? configured
            : Path.Combine(environment.ContentRootPath, configured));
        var webRoot = Path.GetFullPath(environment.WebRootPath ??
            Path.Combine(environment.ContentRootPath, "wwwroot"));
        if (directory.Equals(webRoot, StringComparison.OrdinalIgnoreCase) ||
            directory.StartsWith(webRoot + Path.DirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Storage:TempPath must be outside the web root.");
        return directory;
    }

    private static string? DetectMime(ReadOnlySpan<byte> header)
    {
        if (header.Length >= 12 && header[..4].SequenceEqual("RIFF"u8) &&
            header.Slice(8, 4).SequenceEqual("WAVE"u8)) return "audio/wav";
        if (header.Length >= 4 &&
            header[..4].SequenceEqual(new byte[] { 0x1A, 0x45, 0xDF, 0xA3 }))
            return "audio/webm";
        if (header.Length >= 4 && header[..4].SequenceEqual("OggS"u8)) return "audio/ogg";
        if (header.Length >= 12 && header.Slice(4, 4).SequenceEqual("ftyp"u8))
            return "audio/mp4";
        if (header.Length >= 3 && header[..3].SequenceEqual("ID3"u8)) return "audio/mpeg";
        if (header.Length >= 2 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0)
            return "audio/mpeg";
        return null;
    }
}
