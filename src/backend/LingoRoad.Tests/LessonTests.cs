using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LingoRoad.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class ContentFactory : TestAppFactory
{
    protected override bool SeedContent => true;
}

public class ContentBundleTests : IClassFixture<ContentFactory>
{
    private readonly ContentFactory _factory;
    public ContentBundleTests(ContentFactory factory) => _factory = factory;

    [Fact]
    public async Task Bundle_has_required_coverage_and_is_idempotent()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(20, await db.Lessons.CountAsync());
        Assert.Equal(100, await db.Items.CountAsync(i => i.StableId != null));
        Assert.Equal(new[] { "cloze", "mcq", "reorder" },
            await db.Items.Where(i => i.StableId != null).Select(i => i.Type)
                .Distinct().OrderBy(x => x).ToArrayAsync());
        Assert.All(await db.Lessons.ToListAsync(), lesson =>
        {
            Assert.False(string.IsNullOrWhiteSpace(lesson.ContentVersion));
            Assert.False(string.IsNullOrWhiteSpace(lesson.ContentChecksum));
            Assert.False(string.IsNullOrWhiteSpace(lesson.License));
            Assert.False(string.IsNullOrWhiteSpace(lesson.Reviewer));
        });

        await DbSeeder.SeedAsync(db);

        Assert.Equal(20, await db.Lessons.CountAsync());
        Assert.Equal(100, await db.Items.CountAsync(i => i.StableId != null));
        Assert.Single(await db.ContentBundleImports.ToListAsync());
    }
}

public class LessonEndpointTests : IClassFixture<ContentFactory>
{
    private readonly ContentFactory _factory;
    private readonly HttpClient _client;
    public LessonEndpointTests(ContentFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private async Task AuthenticateAsync()
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new
        {
            email = $"{Guid.NewGuid():N}@t.com",
            password = "secret123",
            name = "Learner",
        });
        var tokens = (await response.Content.ReadFromJsonAsync<Dictionary<string, string>>())!;
        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", tokens["token"]);
    }

    [Fact]
    public async Task Complete_loop_is_safe_idempotent_and_creates_review_for_wrong_answer()
    {
        await AuthenticateAsync();
        var plan = await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today");
        Assert.NotEmpty(plan!);
        var lesson = plan![0];

        var startOperationId = Guid.NewGuid();
        var start = await _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
            new { operationId = startOperationId });
        Assert.Equal(HttpStatusCode.Created, start.StatusCode);
        var startBody = await start.Content.ReadAsStringAsync();
        Assert.DoesNotContain("correctAnswer", startBody, StringComparison.OrdinalIgnoreCase);
        var attempt = await start.Content.ReadFromJsonAsync<AttemptDto>();
        Assert.Equal(5, attempt!.Exercises.Count);

        var resume = await _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
            new { operationId = Guid.NewGuid() });
        Assert.Equal(attempt.Id, (await resume.Content.ReadFromJsonAsync<AttemptDto>())!.Id);

        var early = await _client.PostAsJsonAsync($"/lesson-attempts/{attempt.Id}/complete",
            new { operationId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.Conflict, early.StatusCode);

        Dictionary<Guid, string> answers;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            answers = await db.Exercises.Where(e => e.LessonAttemptId == attempt.Id)
                .ToDictionaryAsync(e => e.Id, e => e.CorrectAnswer);
        }

        for (var index = 0; index < attempt.Exercises.Count; index++)
        {
            var exercise = attempt.Exercises[index];
            var operationId = Guid.NewGuid();
            var answer = index == 0 ? "definitely wrong" : answers[exercise.Id];
            var submit = await _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
                new { answer, operationId });
            submit.EnsureSuccessStatusCode();
            var body = await submit.Content.ReadAsStringAsync();
            Assert.Contains("correctAnswer", body, StringComparison.OrdinalIgnoreCase);

            var replay = await _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
                new { answer, operationId });
            replay.EnsureSuccessStatusCode();
            Assert.Equal(body, await replay.Content.ReadAsStringAsync());
        }

        var completeOperationId = Guid.NewGuid();
        var complete = await _client.PostAsJsonAsync($"/lesson-attempts/{attempt.Id}/complete",
            new { operationId = completeOperationId });
        complete.EnsureSuccessStatusCode();
        var completionBody = await complete.Content.ReadAsStringAsync();
        Assert.Contains("\"reviewCardsCreated\":1", completionBody);

        var completionReplay = await _client.PostAsJsonAsync(
            $"/lesson-attempts/{attempt.Id}/complete", new { operationId = completeOperationId });
        completionReplay.EnsureSuccessStatusCode();
        Assert.Equal(completionBody, await completionReplay.Content.ReadAsStringAsync());

        var due = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/reviews/due");
        Assert.Single(due!);
        var refreshedPlan = await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today");
        var refreshedLesson = refreshedPlan!.SingleOrDefault(x => x.Id == lesson.Id);
        Assert.True(refreshedLesson is null || refreshedLesson.Completed);
    }

    [Fact]
    public async Task Reusing_operation_for_different_answer_returns_conflict()
    {
        await AuthenticateAsync();
        var lesson = (await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today"))![0];
        var attempt = await (await _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
            new { operationId = Guid.NewGuid() })).Content.ReadFromJsonAsync<AttemptDto>();
        var exercise = attempt!.Exercises[0];
        var operationId = Guid.NewGuid();
        (await _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
            new { answer = "first", operationId })).EnsureSuccessStatusCode();

        var conflict = await _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
            new { answer = "second", operationId });

        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Contains("idempotency_conflict", await conflict.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Concurrent_replay_records_one_answer_operation_and_one_mastery_update()
    {
        await AuthenticateAsync();
        var lesson = (await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today"))![0];
        var attempt = await (await _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
            new { operationId = Guid.NewGuid() })).Content.ReadFromJsonAsync<AttemptDto>();
        var exercise = attempt!.Exercises[0];
        string answer;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            answer = (await db.Exercises.FindAsync(exercise.Id))!.CorrectAnswer;
        }
        var operationId = Guid.NewGuid();

        var requests = Enumerable.Range(0, 2).Select(_ =>
            _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
                new { answer, operationId })).ToArray();
        var responses = await Task.WhenAll(requests);

        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
        using var verifyScope = _factory.Services.CreateScope();
        var verifyDb = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await verifyDb.ExerciseAnswerOperations
            .CountAsync(o => o.ExerciseId == exercise.Id));
        var row = await verifyDb.Exercises.FindAsync(exercise.Id);
        Assert.Equal(answer, row!.SubmittedAnswer);
        Assert.Single(await verifyDb.Masteries
            .Where(m => m.UserId == row.UserId && m.SkillId == row.SkillId).ToListAsync());
    }

    [Fact]
    public async Task Concurrent_start_requests_resume_one_active_attempt()
    {
        await AuthenticateAsync();
        var lesson = (await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today"))![0];

        var responses = await Task.WhenAll(
            _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
                new { operationId = Guid.NewGuid() }),
            _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
                new { operationId = Guid.NewGuid() }));

        Assert.All(responses, response => response.EnsureSuccessStatusCode());
        var attempts = await Task.WhenAll(responses.Select(response =>
            response.Content.ReadFromJsonAsync<AttemptDto>()));
        Assert.Equal(attempts[0]!.Id, attempts[1]!.Id);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var userId = (await db.LessonAttempts.FindAsync(attempts[0]!.Id))!.UserId;
        Assert.Equal(1, await db.LessonAttempts.CountAsync(a =>
            a.UserId == userId && a.LessonId == lesson.Id && a.Status == "in_progress"));
    }

    [Fact]
    public async Task Concurrent_completion_records_progress_once()
    {
        await AuthenticateAsync();
        var lesson = (await _client.GetFromJsonAsync<List<TodayLesson>>("/path/today"))![0];
        var attempt = await (await _client.PostAsJsonAsync($"/lessons/{lesson.Id}/attempts",
            new { operationId = Guid.NewGuid() })).Content.ReadFromJsonAsync<AttemptDto>();
        Dictionary<Guid, string> answers;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            answers = await db.Exercises.Where(e => e.LessonAttemptId == attempt!.Id)
                .ToDictionaryAsync(e => e.Id, e => e.CorrectAnswer);
        }
        foreach (var exercise in attempt!.Exercises)
            (await _client.PostAsJsonAsync($"/exercises/{exercise.Id}/submit",
                new { answer = answers[exercise.Id], operationId = Guid.NewGuid() }))
                .EnsureSuccessStatusCode();
        var operationId = Guid.NewGuid();

        var responses = await Task.WhenAll(
            _client.PostAsJsonAsync($"/lesson-attempts/{attempt.Id}/complete",
                new { operationId }),
            _client.PostAsJsonAsync($"/lesson-attempts/{attempt.Id}/complete",
                new { operationId }));

        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
        using var verifyScope = _factory.Services.CreateScope();
        var verifyDb = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await verifyDb.LessonCompletionOperations
            .CountAsync(o => o.AttemptId == attempt.Id));
        var userId = (await verifyDb.LessonAttempts.FindAsync(attempt.Id))!.UserId;
        var progress = await verifyDb.UserLessonProgresses
            .SingleAsync(p => p.UserId == userId && p.LessonId == lesson.Id);
        Assert.Equal(1, progress.CompletionCount);
    }

    private record TodayLesson(Guid Id, string Slug, string Title, string TitleVi,
        string SkillCode, string Cefr, int ItemCount, bool Completed, double Mastery);
    private record ExerciseDto(Guid Id, int Sequence, string Type, string Stem,
        string[] Options, bool Answered);
    private record AttemptDto(Guid Id, Guid LessonId, string Status,
        List<ExerciseDto> Exercises);
}
