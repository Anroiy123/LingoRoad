using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class DashboardTests : IClassFixture<ContentFactory>
{
    private readonly HttpClient _client;
    public DashboardTests(ContentFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task Dashboard_and_quests_start_from_real_user_and_content_data()
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new
        {
            email = $"{Guid.NewGuid():N}@t.com",
            password = "secret123",
            name = "Mai",
        });
        var token = (await response.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var dashboard = await _client.GetFromJsonAsync<DashboardDto>("/dashboard");
        var gamification = await _client.GetFromJsonAsync<GamificationDto>("/gamification/me");
        var quests = await _client.GetFromJsonAsync<List<QuestDto>>("/quests");

        Assert.Equal("Mai", dashboard!.Name);
        Assert.Equal("A1", dashboard.CurrentCefr);
        Assert.Equal(30, dashboard.DailyGoalMinutes);
        Assert.Equal(0, dashboard.Mastery);
        Assert.Empty(dashboard.WeakSkills);
        Assert.Empty(dashboard.StrongSkills);
        Assert.NotNull(dashboard.TodayLesson);
        Assert.Equal(0, dashboard.Xp);
        Assert.Equal(0, dashboard.DueReviews);
        Assert.Equal(0, gamification!.Xp);
        Assert.Equal(1, gamification.Level);
        Assert.Equal(new[] { "daily_lesson", "daily_review", "daily_xp" },
            quests!.Select(q => q.Code));
        Assert.All(quests!, quest => Assert.False(quest.Completed));
    }

    private record DashboardDto(string Name, string CurrentCefr, int DailyGoalMinutes,
        double Mastery, List<SkillSummaryDto> WeakSkills, List<SkillSummaryDto> StrongSkills,
        int DueReviews, int Xp, TodayLessonDto? TodayLesson);
    private record SkillSummaryDto(string Code, double Mastery);
    private record TodayLessonDto(Guid Id, string Title, string SkillCode, int ItemCount);
    private record GamificationDto(int Xp, int Coins, int Level, int CurrentStreak);
    private record QuestDto(string Code, int Current, int Target, bool Completed);
}
