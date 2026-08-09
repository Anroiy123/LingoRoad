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
}
