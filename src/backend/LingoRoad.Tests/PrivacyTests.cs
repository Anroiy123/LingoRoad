using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class PrivacyTests : IClassFixture<TestAppFactory>
{
    private readonly TestAppFactory _factory;

    public PrivacyTests(TestAppFactory factory) => _factory = factory;

    [Fact]
    public async Task Export_contains_owned_data_without_secrets_or_answer_keys()
    {
        var (client, userId) = await AuthenticateAsync();
        var consent = await client.PostAsJsonAsync("/privacy/consents", new
        {
            consentType = "analytics",
            granted = true,
            policyVersion = "2026-08-02"
        });
        Assert.Equal(HttpStatusCode.Created, consent.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Exercises.Add(new Exercise
            {
                UserId = userId,
                SkillId = 1,
                CefrLevel = "A1",
                Type = "mcq",
                Stem = "Private prompt",
                OptionsJson = "[]",
                CorrectAnswer = "never-export-this",
                SubmittedAnswer = "learner-answer",
                IsCorrect = false,
                AnsweredAt = DateTime.UtcNow
            });
            db.LearningEvents.Add(new LearningEvent
            {
                UserId = userId,
                OperationId = Guid.NewGuid(),
                EventType = LearningEventTypes.AnswerSubmitted,
                Correct = false,
                ModelVersion = "test-model-v1"
            });
            await db.SaveChangesAsync();
        }

        var response = await client.GetAsync("/privacy/export");
        response.EnsureSuccessStatusCode();
        Assert.Equal("application/zip", response.Content.Headers.ContentType?.MediaType);
        await using var zipStream = await response.Content.ReadAsStreamAsync();
        using var archive = new ZipArchive(zipStream, ZipArchiveMode.Read);
        var entry = Assert.Single(archive.Entries);
        await using var entryStream = entry.Open();
        using var reader = new StreamReader(entryStream);
        var json = await reader.ReadToEndAsync();
        using var document = JsonDocument.Parse(json);

        Assert.Equal(1, document.RootElement.GetProperty("schemaVersion").GetInt32());
        Assert.Contains("learner-answer", json);
        Assert.Contains("test-model-v1", json);
        Assert.DoesNotContain("never-export-this", json);
        Assert.DoesNotContain("passwordHash", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("tokenHash", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("audioPath", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("correctAnswer", json, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Consent_and_learning_events_are_append_only()
    {
        var (_, userId) = await AuthenticateAsync();
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var consent = new ConsentRecord
        {
            UserId = userId,
            ConsentType = "privacy_policy",
            Granted = true,
            PolicyVersion = "2026-08-02",
            Source = "test"
        };
        db.ConsentRecords.Add(consent);
        await db.SaveChangesAsync();

        consent.Granted = false;
        var error = await Assert.ThrowsAsync<InvalidOperationException>(
            () => db.SaveChangesAsync());
        Assert.Contains("append-only", error.Message);
    }

    [Fact]
    public async Task Deletion_request_is_idempotent_and_worker_removes_learner_data()
    {
        var (client, userId) = await AuthenticateAsync();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.LearningEvents.Add(new LearningEvent
            {
                UserId = userId,
                OperationId = Guid.NewGuid(),
                EventType = LearningEventTypes.AnswerSubmitted
            });
            db.SecurityAuditEvents.Add(new SecurityAuditEvent
            { UserId = userId, EventType = "test_security_event" });
            await db.SaveChangesAsync();
        }

        var first = await client.DeleteAsync("/auth/me");
        var second = await client.DeleteAsync("/auth/me");
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, second.StatusCode);
        var firstBody = JsonDocument.Parse(await first.Content.ReadAsStringAsync());
        var secondBody = JsonDocument.Parse(await second.Content.ReadAsStringAsync());
        Assert.Equal(firstBody.RootElement.GetProperty("id").GetGuid(),
            secondBody.RootElement.GetProperty("id").GetGuid());

        using (var scope = _factory.Services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<PrivacyDeletionService>();
            Assert.Equal(1, await service.ProcessDueAsync());
        }

        using var verifyScope = _factory.Services.CreateScope();
        var verifyDb = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await verifyDb.Users.AnyAsync(user => user.Id == userId));
        Assert.False(await verifyDb.LearningEvents.AnyAsync(e => e.UserId == userId));
        var receipt = await verifyDb.AccountDeletionRequests.SingleAsync(r => r.UserId == userId);
        Assert.Equal(AccountDeletionStatuses.Completed, receipt.Status);
        Assert.NotNull(receipt.CompletedAt);
        Assert.DoesNotContain("@", receipt.UserEmailHash);
        Assert.All(await verifyDb.SecurityAuditEvents
            .Where(e => e.EventType == "test_security_event" ||
                        e.EventType == "account_deletion_requested")
            .ToListAsync(), audit => Assert.Null(audit.UserId));
    }

    [Fact]
    public async Task Retention_removes_expired_logs_and_receipts_but_keeps_learning_history()
    {
        var (_, userId) = await AuthenticateAsync();
        long oldSecurityId;
        long freshSecurityId;
        var oldReceiptId = Guid.NewGuid();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var oldSecurity = new SecurityAuditEvent
            {
                UserId = userId,
                EventType = "old_security",
                CreatedAt = DateTime.UtcNow.AddDays(-100)
            };
            var freshSecurity = new SecurityAuditEvent
            {
                UserId = userId,
                EventType = "fresh_security"
            };
            db.SecurityAuditEvents.AddRange(oldSecurity, freshSecurity);
            db.AccountDeletionRequests.Add(new AccountDeletionRequest
            {
                Id = oldReceiptId,
                UserId = Guid.NewGuid(),
                UserEmailHash = new string('a', 64),
                Status = AccountDeletionStatuses.Completed,
                RequestedAt = DateTime.UtcNow.AddDays(-110),
                ScheduledFor = DateTime.UtcNow.AddDays(-109),
                CompletedAt = DateTime.UtcNow.AddDays(-100)
            });
            db.LearningEvents.Add(new LearningEvent
            {
                UserId = userId,
                OperationId = Guid.NewGuid(),
                EventType = LearningEventTypes.AnswerSubmitted,
                OccurredAt = DateTime.UtcNow.AddYears(-1)
            });
            await db.SaveChangesAsync();
            oldSecurityId = oldSecurity.Id;
            freshSecurityId = freshSecurity.Id;
        }

        using (var scope = _factory.Services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<DataRetentionService>();
            var result = await service.ProcessAsync();
            Assert.True(result.SecurityEvents >= 1);
            Assert.Equal(1, result.DeletionReceipts);
        }

        using var verifyScope = _factory.Services.CreateScope();
        var verifyDb = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null(await verifyDb.SecurityAuditEvents.FindAsync(oldSecurityId));
        Assert.NotNull(await verifyDb.SecurityAuditEvents.FindAsync(freshSecurityId));
        Assert.Null(await verifyDb.AccountDeletionRequests.FindAsync(oldReceiptId));
        Assert.True(await verifyDb.LearningEvents.AnyAsync(e => e.UserId == userId));
    }

    private async Task<(HttpClient Client, Guid UserId)> AuthenticateAsync()
    {
        var client = _factory.CreateClient();
        var email = $"{Guid.NewGuid():N}@privacy.test";
        var response = await client.PostAsJsonAsync("/auth/register", new
        {
            email,
            password = "secret123",
            name = "Privacy learner"
        });
        response.EnsureSuccessStatusCode();
        var tokens = (await response.Content.ReadFromJsonAsync<Dictionary<string, string>>())!;
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", tokens["token"]);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var userId = await db.Users.Where(user => user.Email == email)
            .Select(user => user.Id).SingleAsync();
        return (client, userId);
    }
}
