using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Endpoints;

public record RecordConsentRequest(string? ConsentType, bool Granted, string? PolicyVersion);

public static class PrivacyEndpoints
{
    private static readonly HashSet<string> ConsentTypes =
        ["privacy_policy", "analytics", "ai_processing", "speaking_processing"];

    public static void MapPrivacy(this WebApplication app)
    {
        var privacy = app.MapGroup("/privacy").RequireAuthorization();

        privacy.MapGet("/consents", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
            await db.ConsentRecords.Where(c => c.UserId == principal.UserId())
                .OrderByDescending(c => c.RecordedAt)
                .Select(c => new
                {
                    c.Id,
                    c.ConsentType,
                    c.Granted,
                    c.PolicyVersion,
                    c.Source,
                    c.RecordedAt
                }).ToListAsync());

        privacy.MapPost("/consents", async (RecordConsentRequest req,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var consentType = req.ConsentType?.Trim().ToLowerInvariant() ?? string.Empty;
            var policyVersion = req.PolicyVersion?.Trim() ?? string.Empty;
            if (!ConsentTypes.Contains(consentType))
                return ApiResults.Error("invalid_consent_type");
            if (policyVersion.Length is < 1 or > 100)
                return ApiResults.Error("invalid_policy_version");
            var record = new ConsentRecord
            {
                UserId = principal.UserId(),
                ConsentType = consentType,
                Granted = req.Granted,
                PolicyVersion = policyVersion,
                Source = "authenticated_api"
            };
            db.ConsentRecords.Add(record);
            await db.SaveChangesAsync();
            return Results.Created($"/privacy/consents/{record.Id}", new
            {
                record.Id,
                record.ConsentType,
                record.Granted,
                record.PolicyVersion,
                record.RecordedAt
            });
        });

        privacy.MapGet("/export", ExportAsync);

        app.MapDelete("/auth/me", RequestDeletionAsync).RequireAuthorization();
    }

    private static async Task<IResult> RequestDeletionAsync(
        System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
        IConfiguration configuration, CancellationToken cancellationToken)
    {
        var userId = principal.UserId();
        var user = await db.Users.FindAsync([userId], cancellationToken);
        if (user is null) return Results.NotFound();
        if (user.Role == UserRoles.Admin)
            return Results.Conflict(new { error = "admin_deletion_requires_role_transfer" });
        var existing = await db.AccountDeletionRequests.SingleOrDefaultAsync(
            r => r.UserId == userId, cancellationToken);
        if (existing is not null)
            return Results.Accepted($"/privacy/deletion/{existing.Id}", DeletionSnapshot(existing));

        var graceDays = Math.Clamp(
            configuration.GetValue<int?>("Privacy:DeletionGraceDays") ?? 7, 0, 30);
        var now = DateTime.UtcNow;
        var request = new AccountDeletionRequest
        {
            UserId = userId,
            UserEmailHash = Convert.ToHexStringLower(
                SHA256.HashData(Encoding.UTF8.GetBytes(user.Email))),
            RequestedAt = now,
            ScheduledFor = now.AddDays(graceDays),
        };
        db.AccountDeletionRequests.Add(request);
        await db.RefreshSessions.Where(s => s.UserId == userId && s.RevokedAt == null)
            .ExecuteUpdateAsync(update => update.SetProperty(s => s.RevokedAt, now),
                cancellationToken);
        db.SecurityAuditEvents.Add(new SecurityAuditEvent
            { UserId = userId, EventType = "account_deletion_requested" });
        await db.SaveChangesAsync(cancellationToken);
        return Results.Accepted($"/privacy/deletion/{request.Id}", DeletionSnapshot(request));
    }

    private static object DeletionSnapshot(AccountDeletionRequest request) => new
    {
        request.Id,
        request.Status,
        request.RequestedAt,
        request.ScheduledFor,
        completionDeadline = request.RequestedAt.AddDays(30)
    };

    private static async Task<IResult> ExportAsync(
        System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
        CancellationToken cancellationToken)
    {
        var userId = principal.UserId();
        var user = await db.Users.FindAsync([userId], cancellationToken);
        if (user is null) return Results.NotFound();
        var sessions = await db.TestSessions.Where(s => s.UserId == userId)
            .Select(s => new
            {
                s.Id,
                s.Status,
                s.ResultCefr,
                s.StartedAt,
                s.CompletedAt
            }).ToListAsync(cancellationToken);
        var sessionIds = sessions.Select(s => s.Id).ToArray();
        var payload = new
        {
            schemaVersion = 1,
            generatedAt = DateTime.UtcNow,
            profile = new
            {
                user.Id,
                user.Email,
                user.Name,
                user.TargetCefr,
                user.TargetCefrConfirmed,
                user.DailyGoalMinutes,
                user.LearningPurpose,
                user.StudyReminderEnabled,
                user.ReminderTime,
                user.TimeZone,
                user.EmailNotifications,
                user.AppUpdates,
                user.CreatedAt
            },
            consents = await db.ConsentRecords.Where(c => c.UserId == userId)
                .Select(c => new
                {
                    c.ConsentType,
                    c.Granted,
                    c.PolicyVersion,
                    c.Source,
                    c.RecordedAt
                }).ToListAsync(cancellationToken),
            placementSessions = sessions,
            placementAnswers = await db.Responses.Where(r => sessionIds.Contains(r.SessionId))
                .Select(r => new
                {
                    r.SessionId,
                    r.ItemId,
                    r.Answer,
                    r.Correct,
                    r.ThetaAfter,
                    r.SeAfter,
                    r.AnsweredAt
                }).ToListAsync(cancellationToken),
            mastery = await db.Masteries.Where(m => m.UserId == userId)
                .Select(m => new { m.SkillId, m.PCorrect, m.UpdatedAt })
                .ToListAsync(cancellationToken),
            lessonProgress = await db.UserLessonProgresses.Where(p => p.UserId == userId)
                .Select(p => new
                {
                    p.LessonId,
                    p.CompletionCount,
                    p.CorrectAnswers,
                    p.TotalAnswers,
                    p.LastCompletedAt
                }).ToListAsync(cancellationToken),
            submittedExercises = await db.Exercises.Where(e => e.UserId == userId &&
                    e.AnsweredAt != null)
                .Select(e => new
                {
                    e.Id,
                    e.LessonAttemptId,
                    e.SourceItemId,
                    e.SkillId,
                    e.CefrLevel,
                    e.Type,
                    e.SubmittedAnswer,
                    e.IsCorrect,
                    e.ModelVersion,
                    e.CreatedAt,
                    e.AnsweredAt
                }).ToListAsync(cancellationToken),
            reviews = await db.ReviewCards.Where(r => r.UserId == userId)
                .Select(r => new
                {
                    r.Id,
                    r.SkillId,
                    r.Due,
                    r.LastReview,
                    r.Reps,
                    r.State
                }).ToListAsync(cancellationToken),
            speaking = await db.SpeakingAttempts.Where(s => s.UserId == userId)
                .Select(s => new
                {
                    s.Id,
                    s.PromptText,
                    s.Transcript,
                    s.Total,
                    s.DurationSeconds,
                    s.ModelVersion,
                    s.FeedbackVi,
                    s.CreatedAt
                }).ToListAsync(cancellationToken),
            rewards = await db.RewardLedgerEntries.Where(r => r.UserId == userId)
                .Select(r => new
                {
                    r.SourceType,
                    r.SourceEntityId,
                    r.Xp,
                    r.Coins,
                    r.StreakQualified,
                    r.QuestCode,
                    r.CreatedAt
                }).ToListAsync(cancellationToken),
            learningEvents = await db.LearningEvents.Where(e => e.UserId == userId)
                .Select(e => new
                {
                    e.EventId,
                    e.EventType,
                    e.LessonId,
                    e.LessonAttemptId,
                    e.ExerciseId,
                    e.ItemId,
                    e.SkillId,
                    e.Correct,
                    e.PredictedCorrectness,
                    e.Rating,
                    e.Score,
                    e.LatencyMs,
                    e.CefrLevel,
                    e.ModelVersion,
                    e.ContentVersion,
                    e.OccurredAt
                }).ToListAsync(cancellationToken)
        };

        var json = JsonSerializer.SerializeToUtf8Bytes(payload,
            new JsonSerializerOptions(JsonSerializerDefaults.Web) { WriteIndented = true });
        using var output = new MemoryStream();
        using (var archive = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: true))
        {
            var entry = archive.CreateEntry("lingoroad-data.json", CompressionLevel.Optimal);
            await using var stream = entry.Open();
            await stream.WriteAsync(json, cancellationToken);
        }
        return Results.File(output.ToArray(), "application/zip",
            $"lingoroad-export-{DateTime.UtcNow:yyyyMMdd}.zip");
    }
}
