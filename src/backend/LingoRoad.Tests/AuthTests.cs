using System.Net;
using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class AuthTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public AuthTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Register_then_login_returns_token()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = "a@b.com", password = "secret123", name = "An" });
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);

        var login = await _client.PostAsJsonAsync("/auth/login",
            new { email = "a@b.com", password = "secret123" });
        login.EnsureSuccessStatusCode();
        var body = await login.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.False(string.IsNullOrEmpty(body!["token"]));
    }

    [Fact]
    public async Task Login_with_wrong_password_returns_401()
    {
        await _client.PostAsJsonAsync("/auth/register",
            new { email = "c@d.com", password = "secret123", name = "Chi" });
        var login = await _client.PostAsJsonAsync("/auth/login",
            new { email = "c@d.com", password = "WRONG" });
        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
    }

    [Fact]
    public async Task Duplicate_email_returns_409()
    {
        await _client.PostAsJsonAsync("/auth/register",
            new { email = "e@f.com", password = "secret123", name = "E" });
        var dup = await _client.PostAsJsonAsync("/auth/register",
            new { email = "e@f.com", password = "secret123", name = "E2" });
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
    }
}
