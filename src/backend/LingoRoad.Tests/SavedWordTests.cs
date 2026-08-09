using System.Net;
using System.Net.Http.Json;

namespace LingoRoad.Tests;

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
}
