using System.Net;
using System.Net.Http.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class SavedWordScheduleTests
{
    private static SavedWord NewWord(DateTime createdAt) => new()
    {
        UserId = Guid.NewGuid(),
        SkillId = 1,
        Word = "w",
        Definition = "d",
        CreatedAt = createdAt,
    };

    [Fact]
    public void Initial_due_is_one_day_after_creation()
    {
        var createdAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        Assert.Equal(createdAt.AddDays(1), SavedWordSchedule.InitialDue(createdAt));
    }

    [Fact]
    public void Advance_moves_through_stages_with_rolling_gaps_from_review_time()
    {
        var createdAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var word = NewWord(createdAt);
        word.ReviewStage = 1;
        word.NextReviewAt = SavedWordSchedule.InitialDue(createdAt);

        var reviewedAt1 = createdAt.AddDays(1);
        Assert.False(SavedWordSchedule.Advance(word, reviewedAt1));
        Assert.Equal(2, word.ReviewStage);
        Assert.Equal(reviewedAt1.AddDays(2), word.NextReviewAt);

        var reviewedAt2 = reviewedAt1.AddDays(2);
        Assert.False(SavedWordSchedule.Advance(word, reviewedAt2));
        Assert.Equal(3, word.ReviewStage);
        Assert.Equal(reviewedAt2.AddDays(4), word.NextReviewAt);

        var reviewedAt3 = reviewedAt2.AddDays(4);
        Assert.False(SavedWordSchedule.Advance(word, reviewedAt3));
        Assert.Equal(4, word.ReviewStage);
        Assert.Equal(reviewedAt3.AddDays(7), word.NextReviewAt);
    }

    [Fact]
    public void Advance_on_final_stage_returns_true_and_leaves_word_untouched()
    {
        var createdAt = DateTime.UtcNow;
        var word = NewWord(createdAt);
        word.ReviewStage = 4;
        var dueBefore = word.NextReviewAt;

        var mastered = SavedWordSchedule.Advance(word, createdAt.AddDays(30));

        Assert.True(mastered);
        Assert.Equal(4, word.ReviewStage);
        Assert.Equal(dueBefore, word.NextReviewAt);
    }
}

public class SavedWordEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly TestAppFactory _factory;
    private readonly HttpClient _client;

    public SavedWordEndpointTests(TestAppFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private record SavedWordDto(Guid Id, string Word, string Definition, string? Note,
        DateTime CreatedAt, DateTime? UpdatedAt);

    private async Task AuthenticateAsync(HttpClient client)
    {
        var response = await client.PostAsJsonAsync("/auth/register", new
        {
            email = $"{Guid.NewGuid():N}@t.com",
            password = "secret123",
            name = "Learner",
        });
        var tokens = (await response.Content.ReadFromJsonAsync<Dictionary<string, string>>())!;
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens["token"]);
    }

    [Fact]
    public async Task Create_returns_created_word_with_definition_and_no_note()
    {
        await AuthenticateAsync(_client);

        var response = await _client.PostAsJsonAsync("/words", new
        {
            skillCode = "vocabulary.everyday",
            word = "ephemeral",
            definition = "tồn tại trong thời gian ngắn",
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<SavedWordDto>();
        Assert.Equal("ephemeral", body!.Word);
        Assert.Equal("tồn tại trong thời gian ngắn", body.Definition);
        Assert.Null(body.Note);
    }

    [Fact]
    public async Task Create_rejects_unknown_skill_code()
    {
        await AuthenticateAsync(_client);

        var response = await _client.PostAsJsonAsync("/words",
            new { skillCode = "not.a.real.skill", word = "x", definition = "y" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("unknown_skill", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task List_returns_only_caller_words_newest_first()
    {
        await AuthenticateAsync(_client);
        (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "first", definition = "d1" }))
            .EnsureSuccessStatusCode();
        await Task.Delay(5);
        (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "second", definition = "d2" }))
            .EnsureSuccessStatusCode();

        var list = await _client.GetFromJsonAsync<List<SavedWordDto>>("/words");

        Assert.Equal(2, list!.Count);
        Assert.Equal("second", list[0].Word);
        Assert.Equal("first", list[1].Word);
    }

    [Fact]
    public async Task List_excludes_other_users_words()
    {
        await AuthenticateAsync(_client);
        (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "mine", definition = "d" }))
            .EnsureSuccessStatusCode();

        using var otherClient = _factory.CreateClient();
        await AuthenticateAsync(otherClient);

        var list = await otherClient.GetFromJsonAsync<List<SavedWordDto>>("/words");
        Assert.Empty(list!);
    }

    [Fact]
    public async Task Patch_updates_note_and_leaves_word_and_definition_unchanged()
    {
        await AuthenticateAsync(_client);
        var created = await (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "mnemonic", definition = "def" }))
            .Content.ReadFromJsonAsync<SavedWordDto>();

        var patched = await _client.PatchAsJsonAsync($"/words/{created!.Id}",
            new { note = "sounds like 'ephemeral butterfly'" });

        Assert.Equal(HttpStatusCode.OK, patched.StatusCode);
        var body = await patched.Content.ReadFromJsonAsync<SavedWordDto>();
        Assert.Equal("sounds like 'ephemeral butterfly'", body!.Note);
        Assert.Equal("mnemonic", body.Word);
        Assert.Equal("def", body.Definition);
        Assert.NotNull(body.UpdatedAt);
    }

    [Fact]
    public async Task Patch_on_missing_word_returns_not_found()
    {
        await AuthenticateAsync(_client);

        var missing = await _client.PatchAsJsonAsync($"/words/{Guid.NewGuid()}", new { note = "x" });

        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
    }

    [Fact]
    public async Task Patch_cannot_touch_another_users_word()
    {
        await AuthenticateAsync(_client);
        var created = await (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "mine", definition = "def" }))
            .Content.ReadFromJsonAsync<SavedWordDto>();

        using var otherClient = _factory.CreateClient();
        await AuthenticateAsync(otherClient);

        var response = await otherClient.PatchAsJsonAsync($"/words/{created!.Id}", new { note = "x" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Delete_removes_word_and_second_delete_returns_not_found()
    {
        await AuthenticateAsync(_client);
        var created = await (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "gone", definition = "def" }))
            .Content.ReadFromJsonAsync<SavedWordDto>();

        var deleted = await _client.DeleteAsync($"/words/{created!.Id}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var list = await _client.GetFromJsonAsync<List<SavedWordDto>>("/words");
        Assert.Empty(list!);

        var again = await _client.DeleteAsync($"/words/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, again.StatusCode);
    }

    [Fact]
    public async Task Delete_cannot_remove_another_users_word()
    {
        await AuthenticateAsync(_client);
        var created = await (await _client.PostAsJsonAsync("/words",
            new { skillCode = "vocabulary.everyday", word = "mine", definition = "def" }))
            .Content.ReadFromJsonAsync<SavedWordDto>();

        using var otherClient = _factory.CreateClient();
        await AuthenticateAsync(otherClient);

        var response = await otherClient.DeleteAsync($"/words/{created!.Id}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
