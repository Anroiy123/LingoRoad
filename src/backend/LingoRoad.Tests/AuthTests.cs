using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using LingoRoad.Data;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Tests;

public class AuthTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    private readonly TestAppFactory _factory;
    public AuthTests(TestAppFactory f)
    {
        _factory = f;
        _client = f.CreateClient();
    }

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

    [Fact]
    public async Task Email_is_trimmed_and_case_normalized_for_register_and_login()
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"  {email.ToUpperInvariant()}  ", password = "secret123", name = "A" });
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);

        var dup = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "B" });
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);

        var login = await _client.PostAsJsonAsync("/auth/login",
            new { email = $" {email.ToUpperInvariant()} ", password = "secret123" });
        login.EnsureSuccessStatusCode();
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-an-email")]
    [InlineData("@example.com")]
    public async Task Register_rejects_invalid_email(string email)
    {
        var res = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "A" });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        Assert.Contains("invalid_email", await res.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Refresh_rotates_token_and_reuse_revokes_family()
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        var first = auth.GetProperty("refreshToken").GetString()!;
        var refresh = await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = first });
        refresh.EnsureSuccessStatusCode();
        var rotated = await Json(refresh);
        var second = rotated.GetProperty("refreshToken").GetString()!;
        Assert.NotEqual(first, second);

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = first })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = second })).StatusCode);
    }

    [Fact]
    public async Task Profile_update_persists_goals_focus_and_preferences()
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        Authorize(auth.GetProperty("accessToken").GetString()!);
        var skills = await _client.GetFromJsonAsync<List<JsonElement>>("/skills");
        var skillId = skills![0].GetProperty("id").GetInt32();

        var updated = await _client.PatchAsJsonAsync("/auth/me", new
        {
            targetCefr = "B1", dailyGoalMinutes = 45, learningPurpose = "Work",
            focusSkillIds = new[] { skillId }, studyReminderEnabled = false,
            reminderTime = "19:30", timeZone = "Asia/Ho_Chi_Minh",
            emailNotifications = true, appUpdates = false
        });
        updated.EnsureSuccessStatusCode();
        var profile = await Json(updated);
        Assert.Equal("B1", profile.GetProperty("targetCefr").GetString());
        Assert.True(profile.GetProperty("targetCefrConfirmed").GetBoolean());
        Assert.Equal(45, profile.GetProperty("dailyGoalMinutes").GetInt32());
        Assert.Equal(skillId, profile.GetProperty("focusSkillIds")[0].GetInt32());
        Assert.False(profile.GetProperty("studyReminderEnabled").GetBoolean());
        Assert.True(profile.GetProperty("emailNotifications").GetBoolean());
    }

    [Fact]
    public async Task Complete_profile_setup_validates_and_is_idempotent()
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        Authorize(auth.GetProperty("accessToken").GetString()!);
        var invalid = await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = " ", targetCefr = "b1", dailyGoalMinutes = 9 });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        var first = await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = "  Learner  ", targetCefr = "B1", dailyGoalMinutes = 45 });
        first.EnsureSuccessStatusCode();
        var profile = await Json(first);
        Assert.True(profile.GetProperty("profileSetupCompleted").GetBoolean());
        Assert.Equal("Learner", profile.GetProperty("name").GetString());

        var second = await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = "Updated", targetCefr = "B2", dailyGoalMinutes = 60 });
        second.EnsureSuccessStatusCode();
        var updated = await Json(second);
        Assert.Equal("Updated", updated.GetProperty("name").GetString());
        Assert.Equal(60, updated.GetProperty("dailyGoalMinutes").GetInt32());
        Assert.True(updated.GetProperty("profileSetupCompleted").GetBoolean());
    }

    [Theory]
    [InlineData("", "B1", 30)]
    [InlineData("Learner", "b1", 30)]
    [InlineData("Learner", "B1", 9)]
    [InlineData("Learner", "B1", 121)]
    public async Task Complete_profile_setup_rejects_each_boundary(string name, string cefr, int goal)
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        Authorize(auth.GetProperty("accessToken").GetString()!);
        var response = await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name, targetCefr = cefr, dailyGoalMinutes = goal });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Complete_profile_setup_requires_authentication()
    {
        _client.DefaultRequestHeaders.Authorization = null;
        var response = await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = "Learner", targetCefr = "B1", dailyGoalMinutes = 30 });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Complete_profile_setup_keeps_first_database_timestamp_on_repeat()
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        var auth = await Register(email);
        Authorize(auth.GetProperty("accessToken").GetString()!);
        (await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = "First", targetCefr = "B1", dailyGoalMinutes = 30 }))
            .EnsureSuccessStatusCode();
        DateTime first;
        using (var scope = _factory.Services.CreateScope())
        {
            first = (await scope.ServiceProvider.GetRequiredService<AppDbContext>().Users
                .AsNoTracking().SingleAsync(u => u.Email == email)).ProfileSetupCompletedAt!.Value;
        }
        (await _client.PostAsJsonAsync("/auth/me/complete-profile-setup",
            new { name = "Second", targetCefr = "B2", dailyGoalMinutes = 60 }))
            .EnsureSuccessStatusCode();
        using var verifyScope = _factory.Services.CreateScope();
        var user = await verifyScope.ServiceProvider.GetRequiredService<AppDbContext>().Users
            .AsNoTracking().SingleAsync(u => u.Email == email);
        Assert.Equal(first, user.ProfileSetupCompletedAt);
        Assert.Equal("Second", user.Name);
    }

    [Fact]
    public async Task Change_password_revokes_refresh_sessions()
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        var auth = await Register(email);
        Authorize(auth.GetProperty("accessToken").GetString()!);
        var refreshToken = auth.GetProperty("refreshToken").GetString()!;
        var changed = await _client.PostAsJsonAsync("/auth/change-password",
            new { currentPassword = "secret123", newPassword = "new-secret-456" });
        Assert.Equal(HttpStatusCode.NoContent, changed.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/auth/login", new { email, password = "secret123" })).StatusCode);
        (await _client.PostAsJsonAsync("/auth/login",
            new { email, password = "new-secret-456" })).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Logout_revokes_supplied_refresh_token()
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        Authorize(auth.GetProperty("accessToken").GetString()!);
        var refreshToken = auth.GetProperty("refreshToken").GetString()!;
        _client.DefaultRequestHeaders.Authorization = null;
        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/auth/logout", new { refreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken })).StatusCode);
    }

    [Fact]
    public async Task Concurrent_refresh_is_fail_closed_and_revokes_replacement()
    {
        var auth = await Register($"{Guid.NewGuid():N}@example.com");
        var refreshToken = auth.GetProperty("refreshToken").GetString()!;
        using var second = _factory.CreateClient();
        var responses = await Task.WhenAll(
            _client.PostAsJsonAsync("/auth/refresh", new { refreshToken }),
            second.PostAsJsonAsync("/auth/refresh", new { refreshToken }));
        Assert.Contains(responses, x => x.StatusCode == HttpStatusCode.OK);
        Assert.Contains(responses, x => x.StatusCode == HttpStatusCode.Unauthorized);
        var success = responses.Single(x => x.StatusCode == HttpStatusCode.OK);
        var rotated = (await Json(success)).GetProperty("refreshToken").GetString()!;
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await second.PostAsJsonAsync("/auth/refresh", new { refreshToken = rotated })).StatusCode);
    }

    private async Task<JsonElement> Register(string email)
    {
        var response = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "Test" });
        response.EnsureSuccessStatusCode();
        return await Json(response);
    }

    private void Authorize(string token) => _client.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

    private static async Task<JsonElement> Json(HttpResponseMessage response) =>
        (await response.Content.ReadFromJsonAsync<JsonElement>());
}
