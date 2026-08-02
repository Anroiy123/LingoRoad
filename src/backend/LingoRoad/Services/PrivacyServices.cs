using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Services;

public sealed class PrivacyDeletionService(AppDbContext db, ILogger<PrivacyDeletionService> logger)
{
    public async Task<int> ProcessDueAsync(CancellationToken cancellationToken = default)
    {
        var due = await db.AccountDeletionRequests
            .Where(r => r.Status == AccountDeletionStatuses.Pending &&
                r.ScheduledFor <= DateTime.UtcNow)
            .OrderBy(r => r.RequestedAt)
            .Take(20)
            .ToListAsync(cancellationToken);
        var completed = 0;
        foreach (var request in due)
        {
            await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                var user = await db.Users.SingleOrDefaultAsync(u => u.Id == request.UserId,
                    cancellationToken);
                if (user is not null && user.Role == UserRoles.Admin)
                {
                    request.Status = AccountDeletionStatuses.Failed;
                    request.FailureCode = "admin_deletion_requires_role_transfer";
                    await db.SaveChangesAsync(cancellationToken);
                    await transaction.CommitAsync(cancellationToken);
                    continue;
                }

                await DeleteLearnerDataAsync(request.UserId, cancellationToken);
                request.Status = AccountDeletionStatuses.Completed;
                request.CompletedAt = DateTime.UtcNow;
                request.FailureCode = null;
                await db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                completed++;
            }
            catch (Exception error)
            {
                await transaction.RollbackAsync(cancellationToken);
                db.ChangeTracker.Clear();
                var failed = await db.AccountDeletionRequests.FindAsync(
                    [request.Id], cancellationToken);
                if (failed is not null)
                {
                    failed.Status = DateTime.UtcNow >= failed.RequestedAt.AddDays(30)
                        ? AccountDeletionStatuses.Failed
                        : AccountDeletionStatuses.Pending;
                    failed.FailureCode = "deletion_failed";
                    await db.SaveChangesAsync(cancellationToken);
                }
                logger.LogError(error, "Account deletion {DeletionRequestId} failed", request.Id);
            }
        }
        return completed;
    }

    private async Task DeleteLearnerDataAsync(Guid userId, CancellationToken cancellationToken)
    {
        var sessionIds = db.TestSessions.Where(s => s.UserId == userId).Select(s => s.Id);
        await db.Responses.Where(r => sessionIds.Contains(r.SessionId))
            .ExecuteDeleteAsync(cancellationToken);
        await db.ReviewGradeOperations.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.ReviewCards.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.ExerciseAnswerOperations.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.LessonCompletionOperations.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.RewardLedgerEntries.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.SpeakingAttempts.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.Exercises.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.UserLessonProgresses.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.LessonAttempts.Where(r => r.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);
        await db.Masteries.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.TestSessions.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.UserFocusSkills.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.RefreshSessions.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.ConsentRecords.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.LearningEvents.Where(r => r.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await db.SecurityAuditEvents.Where(r => r.UserId == userId)
            .ExecuteUpdateAsync(update => update.SetProperty(r => r.UserId, (Guid?)null),
                cancellationToken);
        await db.Users.Where(r => r.Id == userId).ExecuteDeleteAsync(cancellationToken);
    }
}

public sealed class DataRetentionService(AppDbContext db, IConfiguration configuration)
{
    public async Task<(int SecurityEvents, int AdminEvents, int DeletionReceipts)>
        ProcessAsync(CancellationToken cancellationToken = default)
    {
        var securityDays = Math.Clamp(
            configuration.GetValue<int?>("Privacy:SecurityLogRetentionDays") ?? 90,
            1, 365);
        var receiptDays = Math.Clamp(
            configuration.GetValue<int?>("Privacy:DeletionReceiptRetentionDays") ?? 90,
            30, 365);
        var now = DateTime.UtcNow;
        var security = await db.SecurityAuditEvents
            .Where(e => e.CreatedAt < now.AddDays(-securityDays))
            .ExecuteDeleteAsync(cancellationToken);
        var admin = await db.AdminAuditEvents
            .Where(e => e.CreatedAt < now.AddDays(-securityDays))
            .ExecuteDeleteAsync(cancellationToken);
        var receipts = await db.AccountDeletionRequests
            .Where(e => e.Status == AccountDeletionStatuses.Completed &&
                e.CompletedAt < now.AddDays(-receiptDays))
            .ExecuteDeleteAsync(cancellationToken);
        return (security, admin, receipts);
    }
}

public sealed class PrivacyMaintenanceWorker(IServiceScopeFactory scopeFactory,
    ILogger<PrivacyMaintenanceWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                await scope.ServiceProvider.GetRequiredService<PrivacyDeletionService>()
                    .ProcessDueAsync(stoppingToken);
                await scope.ServiceProvider.GetRequiredService<DataRetentionService>()
                    .ProcessAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception error)
            {
                logger.LogError(error, "Privacy maintenance cycle failed");
            }

            try
            {
                if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }
}
