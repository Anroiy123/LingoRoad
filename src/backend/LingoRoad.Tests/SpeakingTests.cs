using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class SpeakingTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public SpeakingTests(PlacementFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Upload_returns_scores_and_stores_attempt()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "S" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        using var form = new MultipartFormDataContent
        {
            { new ByteArrayContent([1, 2, 3, 4]), "audio", "test.webm" },
            { new StringContent("I have lived here for two years"), "promptText" }
        };
        var res = await _client.PostAsync("/speaking/attempts", form);
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("transcript", body);
        Assert.Contains("total", body);

        var history = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>(
            "/speaking/attempts");
        Assert.Single(history!);
    }
}
