using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using LingoRoad.Data;
using LingoRoad.Endpoints;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Tests;

// Fake: theta creeps up, SE = 1/sqrt(n+1) so the stop rule (SE < 0.35, min 8) fires after item 8.
public class FakeMlClient : IMlClient
{
    public bool Throw { get; set; }
    public Func<CatSelectRequest, Guid?>? SelectNextItem { get; set; }
    public double SpeakingDurationSeconds { get; set; } = 3;
    public Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)
    {
        if (Throw) throw new MlServiceUnavailableException(new HttpRequestException("down"));
        var n = req.History.Count;
        var se = 1.0 / Math.Sqrt(n + 1);
        var next = SelectNextItem?.Invoke(req) ??
            (req.Candidates.Count > 0 ? req.Candidates[0].ItemId : (Guid?)null);
        return Task.FromResult(new CatSelectResponse(0.1 * n, se, next));
    }

    public Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)
        => Task.FromResult(new AdvisorResponse("Bạn nên học kỹ năng này vì nó là nền tảng."));

    public Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
    {
        if (Throw) throw new MlServiceUnavailableException(new HttpRequestException("down"));
        return Task.FromResult(new ExerciseGenResponse([
            new GeneratedExercise("She ___ here since 2019.",
                ["has lived", "lived", "lives", "living"], "has lived",
                "Dùng thì hiện tại hoàn thành với 'since'.")], "fake-llm-v1"));
    }

    public Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
        => Task.FromResult(new AweResponse(new AweScores(6, 6, 5, 5),
            [new AweFeedback("My hometown is Da Nang.", "Câu quá ngắn", "Thêm chi tiết mô tả.")],
            "Bài viết ổn, cần phát triển ý."));

    public Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName,
        string promptText, CancellationToken ct = default)
    {
        if (Throw) throw new MlServiceUnavailableException(new HttpRequestException("down"));
        return Task.FromResult(new SpeakingScoreResponse(promptText, 0.9, 1.0, 0.8, 0.88,
            SpeakingDurationSeconds, "whisper-small-test",
            "Phát âm tốt, chú ý âm cuối."));
    }
}

public class PlacementFactory : TestAppFactory
{
    public FakeMlClient Fake { get; } = new();
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);
        builder.ConfigureServices(s =>
        {
            s.RemoveAll<IMlClient>();
            s.AddSingleton<IMlClient>(Fake);
        });
    }
}

public class PlacementTests : IClassFixture<PlacementFactory>
{
    private readonly PlacementFactory _factory;
    private readonly HttpClient _client;
    public PlacementTests(PlacementFactory f) { _factory = f; _client = f.CreateClient(); }

    private static async Task AuthenticateAsync(HttpClient client)
    {
        var email = $"{Guid.NewGuid():N}@t.com";
        var reg = await client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "T" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private Task AuthenticateAsync() => AuthenticateAsync(_client);

    [Fact]
    public async Task Status_is_false_when_user_has_not_completed_placement()
    {
        await AuthenticateAsync();

        var status = await _client.GetFromJsonAsync<StatusDto>("/placement/status");

        Assert.NotNull(status);
        Assert.False(status.Completed);
    }

    private async Task SeedItemsAsync(int count = 12)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var skillId = await db.Skills.Where(x => x.Code == "grammar.tenses.present_simple")
            .Select(x => x.Id).SingleAsync();
        db.Items.AddRange(Enumerable.Range(0, count).Select(i => new Item
        {
            SkillId = skillId,
            CefrLevel = "B1",
            Type = "mcq",
            Stem = $"Question {Guid.NewGuid():N}-{i}: she ___ tea.",
            OptionsJson = JsonSerializer.Serialize(new[] { "drinks", "drink", "drinking", "drank" }),
            CorrectAnswer = "drinks",
            Source = "test",
            A = 1,
            B = -.4,
            C = .25
        }));
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task Full_adaptive_session_stops_after_min_items_and_returns_cefr()
    {
        await AuthenticateAsync();
        await SeedItemsAsync();
        _factory.Fake.Throw = false;

        var start = await _client.PostAsync("/placement/start", null);
        start.EnsureSuccessStatusCode();
        var state = await start.Content.ReadFromJsonAsync<StartDto>();
        var sessionId = state!.SessionId;

        int answered = 0;
        Guid itemId = state.Item.Id;
        while (true)
        {
            var res = await _client.PostAsJsonAsync($"/placement/{sessionId}/answer",
                new { itemId, answer = "drinks" });
            res.EnsureSuccessStatusCode();
            var step = await res.Content.ReadFromJsonAsync<StepDto>();
            answered++;
            if (step!.Done) break;
            itemId = step.Item!.Id;
            Assert.True(answered < 40, "session never terminated");
        }

        Assert.True(answered >= 8);
        var result = await _client.GetFromJsonAsync<ResultDto>($"/placement/{sessionId}/result");
        Assert.Equal("completed", result!.Status);
        Assert.Contains(result.Cefr, new[] { "A1", "A2", "B1", "B2", "C1", "C2" });

        var status = await _client.GetFromJsonAsync<StatusDto>("/placement/status");
        Assert.NotNull(status);
        Assert.True(status.Completed);
    }

    [Fact]
    public async Task Placement_issues_only_choice_items_supported_by_placement_client()
    {
        await AuthenticateAsync();
        var clozeId = Guid.NewGuid();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var skillId = await db.Skills.Where(x => x.Code == "grammar.tenses.present_simple")
                .Select(x => x.Id).SingleAsync();
            db.Items.AddRange(
                new Item
                {
                    SkillId = skillId, CefrLevel = "A1", Type = "mcq",
                    Stem = "First supported question", OptionsJson = "[\"yes\",\"no\"]",
                    CorrectAnswer = "yes", Source = "test", A = 1, B = -0.4, C = 0.25
                },
                new Item
                {
                    Id = clozeId, SkillId = skillId, CefrLevel = "A1", Type = "cloze",
                    Stem = "An incompatible ___ question", OptionsJson = "[]",
                    CorrectAnswer = "answer", Source = "test", A = 1, B = -0.4, C = 0
                },
                new Item
                {
                    SkillId = skillId, CefrLevel = "A1", Type = "mcq",
                    Stem = "Second supported question", OptionsJson = "[\"true\",\"false\"]",
                    CorrectAnswer = "true", Source = "test", A = 1, B = -0.4, C = 0.25
                });
            await db.SaveChangesAsync();
        }

        _factory.Fake.SelectNextItem = request => request.Candidates
            .Any(candidate => candidate.ItemId == clozeId)
                ? clozeId
                : request.Candidates.FirstOrDefault()?.ItemId;
        try
        {
            var start = await (await _client.PostAsync("/placement/start", null))
                .Content.ReadFromJsonAsync<StartDto>();

            Assert.Equal("mcq", start!.Item.Type);
            Assert.NotEmpty(start.Item.Options);
        }
        finally
        {
            _factory.Fake.SelectNextItem = null;
        }
    }

    [Fact]
    public async Task Start_without_auth_returns_401()
    {
        var anon = _factory.CreateClient();
        var res = await anon.PostAsync("/placement/start", null);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task Ml_service_down_returns_503_with_error_body()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(2);
        _factory.Fake.Throw = true;
        var res = await _client.PostAsync("/placement/start", null);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);
        Assert.Contains("ml_service_unavailable", await res.Content.ReadAsStringAsync());
        _factory.Fake.Throw = false;
    }

    [Fact]
    public async Task Answer_rejects_item_that_was_not_issued_for_the_session()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(3);
        _factory.Fake.Throw = false;

        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();
        var items = await _client.GetFromJsonAsync<List<ItemDto>>("/items");
        var otherItem = Assert.Single(items!.Where(i => i.Id != start!.Item.Id).Take(1));

        var res = await _client.PostAsJsonAsync($"/placement/{start!.SessionId}/answer",
            new { itemId = otherItem.Id, answer = "drinks" });

        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Contains("item_not_issued", await res.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Retrying_same_answer_returns_same_result_without_duplicate_side_effects()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(3);
        _factory.Fake.Throw = false;

        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();
        var payload = new { itemId = start!.Item.Id, answer = "drinks" };

        var first = await _client.PostAsJsonAsync(
            $"/placement/{start.SessionId}/answer", payload);
        first.EnsureSuccessStatusCode();
        var firstBody = await first.Content.ReadAsStringAsync();
        var masteryAfterFirst = await _client.GetFromJsonAsync<List<MasteryDto>>("/mastery");

        var retry = await _client.PostAsJsonAsync(
            $"/placement/{start.SessionId}/answer", payload);
        retry.EnsureSuccessStatusCode();
        Assert.Equal(firstBody, await retry.Content.ReadAsStringAsync());

        var masteryAfterRetry = await _client.GetFromJsonAsync<List<MasteryDto>>("/mastery");
        Assert.Equal(
            JsonSerializer.Serialize(masteryAfterFirst),
            JsonSerializer.Serialize(masteryAfterRetry));
        var result = await _client.GetFromJsonAsync<ResultDto>(
            $"/placement/{start.SessionId}/result");
        Assert.Equal(1, result!.ItemsAnswered);

        var changedPayload = await _client.PostAsJsonAsync(
            $"/placement/{start.SessionId}/answer",
            new { itemId = start.Item.Id, answer = "drink" });
        Assert.Equal(HttpStatusCode.Conflict, changedPayload.StatusCode);
        Assert.Contains("answer_already_recorded",
            await changedPayload.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Ml_failure_during_answer_does_not_persist_response_or_mastery()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(3);
        _factory.Fake.Throw = false;
        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();

        try
        {
            _factory.Fake.Throw = true;
            var failed = await _client.PostAsJsonAsync(
                $"/placement/{start!.SessionId}/answer",
                new { itemId = start.Item.Id, answer = "drinks" });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, failed.StatusCode);

            var result = await _client.GetFromJsonAsync<ResultDto>(
                $"/placement/{start.SessionId}/result");
            Assert.Equal(0, result!.ItemsAnswered);
            var mastery = await _client.GetFromJsonAsync<List<MasteryDto>>("/mastery");
            Assert.Empty(mastery!);
        }
        finally
        {
            _factory.Fake.Throw = false;
        }

        var retry = await _client.PostAsJsonAsync(
            $"/placement/{start!.SessionId}/answer",
            new { itemId = start.Item.Id, answer = "drinks" });
        retry.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task User_cannot_answer_another_users_session()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(2);
        _factory.Fake.Throw = false;
        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();

        using var otherClient = _factory.CreateClient();
        await AuthenticateAsync(otherClient);
        var res = await otherClient.PostAsJsonAsync(
            $"/placement/{start!.SessionId}/answer",
            new { itemId = start.Item.Id, answer = "drinks" });

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    private record PlacementItem(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
    private record StatusDto(bool Completed);
    private record StartDto(Guid SessionId, PlacementItem Item);
    private record StepDto(bool Done, PlacementItem? Item, double? Theta, string? Cefr);
    private record ResultDto(double Theta, double Se, string Cefr, int ItemsAnswered, string Status);
    private record MasteryDto(string SkillCode, string SkillName, double PCorrect, DateTime UpdatedAt);
}

public class CefrMapTests
{
    [Theory]
    [InlineData(-2.5, "A1")]
    [InlineData(-1.0, "A2")]
    [InlineData(0.0, "B1")]
    [InlineData(1.0, "B2")]
    [InlineData(2.0, "C1")]
    [InlineData(3.0, "C2")]
    public void Maps_theta_to_cefr(double theta, string expected) =>
        Assert.Equal(expected, CefrMap.FromTheta(theta));
}
