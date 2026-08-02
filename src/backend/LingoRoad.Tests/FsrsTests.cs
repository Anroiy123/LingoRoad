using System.Net.Http.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class FsrsTests
{
    private static ReviewCard NewCard() => new()
    { UserId = Guid.NewGuid(), SkillId = 1, Front = "hi", Back = "chào" };

    private static ReviewCard Reviewed(Grade g, DateTime now)
    {
        var c = NewCard();
        Fsrs.Review(c, g, now);
        return c;
    }

    [Fact]
    public void First_review_orders_intervals_by_grade()
    {
        var now = DateTime.UtcNow;
        var hard = Reviewed(Grade.Hard, now);
        var good = Reviewed(Grade.Good, now);
        var easy = Reviewed(Grade.Easy, now);
        Assert.True(easy.Due > good.Due);
        Assert.True(good.Due > hard.Due);
    }

    [Fact]
    public void Again_goes_to_relearning_within_minutes()
    {
        var now = DateTime.UtcNow;
        var c = Reviewed(Grade.Again, now);
        Assert.Equal("relearning", c.State);
        Assert.True(c.Due <= now.AddMinutes(15));
    }

    [Fact]
    public void Repeated_good_reviews_grow_stability()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Good, now);
        var s1 = c.Stability;
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability));
        var s2 = c.Stability;
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability + s1));
        Assert.True(s2 > s1);
        Assert.True(c.Stability > s2);
    }

    [Fact]
    public void Difficulty_stays_in_1_to_10()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Again, now);
        for (var i = 0; i < 20; i++) Fsrs.Review(c, Grade.Again, now = now.AddDays(1));
        Assert.InRange(c.Difficulty, 1.0, 10.0);
        for (var i = 0; i < 20; i++) Fsrs.Review(c, Grade.Easy, now = now.AddDays(1));
        Assert.InRange(c.Difficulty, 1.0, 10.0);
    }

    [Fact]
    public void Forgetting_reduces_stability()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Good, now);
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability));
        var before = c.Stability;
        Fsrs.Review(c, Grade.Again, now.AddDays(before * 2));
        Assert.True(c.Stability < before);
    }
}

public class ReviewEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    private readonly TestAppFactory _factory;
    public ReviewEndpointTests(TestAppFactory f)
    {
        _factory = f;
        _client = f.CreateClient();
    }

    private record CardDto(Guid Id, string Front, string Back, DateTime Due, string State, int Reps);
    private record RewardsDto(int Xp, int Coins);

    [Fact]
    public async Task Create_grade_and_requeue_flow()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "R" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var created = await _client.PostAsJsonAsync("/reviews/cards",
            new { skillCode = "vocabulary.everyday", front = "hello", back = "xin chào" });
        Assert.Equal(System.Net.HttpStatusCode.Created, created.StatusCode);

        var due = await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due");
        var card = Assert.Single(due!);

        var operationId = Guid.NewGuid();
        var gradeRequest = new { rating = 3, operationId, expectedReps = card.Reps };
        var graded = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade", gradeRequest);
        graded.EnsureSuccessStatusCode();

        var replay = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade", gradeRequest);
        replay.EnsureSuccessStatusCode(); // same operation is a stored response, not a second FSRS transition
        var conflict = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade",
            new { rating = 2, operationId, expectedReps = card.Reps });
        Assert.Equal(System.Net.HttpStatusCode.Conflict, conflict.StatusCode);
        var stale = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade",
            new { rating = 3, operationId = Guid.NewGuid(), expectedReps = card.Reps });
        Assert.Equal(System.Net.HttpStatusCode.Conflict, stale.StatusCode);

        var dueAfter = await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due");
        Assert.Empty(dueAfter!);   // Good pushes it days into the future
    }

    [Fact]
    public async Task Grade_rejects_a_card_that_is_not_due()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "R" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var created = await _client.PostAsJsonAsync("/reviews/cards",
            new { skillCode = "vocabulary.everyday", front = "hello", back = "xin chào" });
        created.EnsureSuccessStatusCode();
        var card = Assert.Single((await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due"))!);
        var first = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade",
            new { rating = 3, operationId = Guid.NewGuid(), expectedReps = card.Reps });
        first.EnsureSuccessStatusCode();

        var early = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade",
            new { rating = 3, operationId = Guid.NewGuid(), expectedReps = card.Reps + 1 });
        Assert.Equal(System.Net.HttpStatusCode.Conflict, early.StatusCode);
        Assert.Equal("review_not_due", (await early.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["error"]);
    }

    [Fact]
    public async Task Same_grade_operation_is_safe_when_sent_concurrently()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "R" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        var created = await _client.PostAsJsonAsync("/reviews/cards",
            new { skillCode = "vocabulary.everyday", front = "hello", back = "xin chào" });
        created.EnsureSuccessStatusCode();
        var card = Assert.Single((await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due"))!);
        var request = new { rating = 3, operationId = Guid.NewGuid(), expectedReps = card.Reps };

        using var firstClient = _factory.CreateClient();
        using var secondClient = _factory.CreateClient();
        firstClient.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        secondClient.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        var responses = await Task.WhenAll(
            firstClient.PostAsJsonAsync($"/reviews/{card.Id}/grade", request),
            secondClient.PostAsJsonAsync($"/reviews/{card.Id}/grade", request));

        Assert.All(responses, response => response.EnsureSuccessStatusCode());
        Assert.Empty((await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due"))!);
        var rewards = await _client.GetFromJsonAsync<RewardsDto>("/gamification/me");
        Assert.Equal(5, rewards!.Xp);
        Assert.Equal(1, rewards.Coins);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.LearningEvents.CountAsync(e =>
            e.OperationId == request.operationId && e.EventType == "review_graded"));
    }

}
