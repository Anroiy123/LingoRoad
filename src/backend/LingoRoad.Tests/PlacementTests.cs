using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Tests;

// Fake: theta creeps up, SE = 1/sqrt(n+1) so the stop rule (SE < 0.35, min 8) fires after item 8.
public class FakeMlClient : IMlClient
{
    public bool Throw { get; set; }
    public Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)
    {
        if (Throw) throw new MlServiceUnavailableException(new HttpRequestException("down"));
        var n = req.History.Count;
        var se = 1.0 / Math.Sqrt(n + 1);
        var next = req.Candidates.Count > 0 ? req.Candidates[0].ItemId : (Guid?)null;
        return Task.FromResult(new CatSelectResponse(0.1 * n, se, next));
    }

    public Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)
        => Task.FromResult(new AdvisorResponse("Bạn nên học kỹ năng này vì nó là nền tảng."));

    public Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
        => Task.FromResult(new ExerciseGenResponse([
            new GeneratedExercise("She ___ here since 2019.",
                ["has lived", "lived", "lives", "living"], "has lived",
                "Dùng thì hiện tại hoàn thành với 'since'.")]));

    public Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
        => Task.FromResult(new AweResponse(new AweScores(6, 6, 5, 5),
            [new AweFeedback("My hometown is Da Nang.", "Câu quá ngắn", "Thêm chi tiết mô tả.")],
            "Bài viết ổn, cần phát triển ý."));
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

    private async Task AuthenticateAsync()
    {
        var email = $"{Guid.NewGuid():N}@t.com";
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "T" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private async Task SeedItemsAsync(int count = 12)
    {
        var items = Enumerable.Range(0, count).Select(i => new
        {
            skillCode = "grammar.tenses.present_simple",
            cefrLevel = "B1",
            type = "mcq",
            stem = $"Question {i}: she ___ tea.",
            options = new[] { "drinks", "drink", "drinking", "drank" },
            correctAnswer = "drinks",
            source = "test"
        });
        (await _client.PostAsJsonAsync("/admin/items/import", items)).EnsureSuccessStatusCode();
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

    private record PlacementItem(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
    private record StartDto(Guid SessionId, PlacementItem Item);
    private record StepDto(bool Done, PlacementItem? Item, double? Theta, string? Cefr);
    private record ResultDto(double Theta, double Se, string Cefr, int ItemsAnswered, string Status);
}

public class CefrMapTests
{
    [Theory]
    [InlineData(-2.5, "A1")] [InlineData(-1.0, "A2")] [InlineData(0.0, "B1")]
    [InlineData(1.0, "B2")] [InlineData(2.0, "C1")] [InlineData(3.0, "C2")]
    public void Maps_theta_to_cefr(double theta, string expected) =>
        Assert.Equal(expected, CefrMap.FromTheta(theta));
}
