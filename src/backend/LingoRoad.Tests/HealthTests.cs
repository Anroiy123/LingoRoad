namespace LingoRoad.Tests;

public class HealthTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public HealthTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Health_returns_ok()
    {
        var res = await _client.GetAsync("/health");
        res.EnsureSuccessStatusCode();
        Assert.Equal("ok", await res.Content.ReadAsStringAsync());
    }
}
