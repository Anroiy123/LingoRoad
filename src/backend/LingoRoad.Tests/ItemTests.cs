using System.Net.Http.Json;
using LingoRoad.Endpoints;

namespace LingoRoad.Tests;

public class ItemTests : IClassFixture<TestAppFactory>
{
    private readonly TestAppFactory _factory;
    public ItemTests(TestAppFactory f) => _factory = f;

    private static object SampleItem(int skillId) => new
    {
        stableId = $"test-{Guid.NewGuid():N}",
        skillId,
        cefrLevel = "B1",
        type = "mcq",
        stem = "She ___ in Hanoi since 2019.",
        options = new[] { "has lived", "lived", "lives", "is living" },
        correctAnswer = "has lived",
        source = "test",
        a = 1.0,
        b = -0.4,
        c = 0.25
    };

    [Fact]
    public async Task Import_then_list_filters_by_skill_and_cefr()
    {
        using var client = await TestAuth.ClientAsync(_factory);
        var skills = await client.GetFromJsonAsync<List<SkillDto>>("/skills");
        var skill = skills!.Single(x => x.Code == "grammar.tenses.present_perfect");
        var res = await client.PostAsJsonAsync("/admin/items", SampleItem(skill.Id));
        res.EnsureSuccessStatusCode();

        var list = await client.GetAsync(
            "/items?skill=grammar.tenses.present_perfect&cefr=B1");
        list.EnsureSuccessStatusCode();
        var body = await list.Content.ReadAsStringAsync();
        Assert.DoesNotContain("\"correctAnswer\"", body, StringComparison.OrdinalIgnoreCase);

        var items = await list.Content.ReadFromJsonAsync<List<ItemDto>>();
        var item = Assert.Single(items!, x => x.Stem.Contains("Hanoi"));
        Assert.True(item.A >= 0.6 && item.A <= 2.0);
    }

    [Fact]
    public async Task Create_with_unknown_skill_returns_400()
    {
        using var client = await TestAuth.ClientAsync(_factory);
        var res = await client.PostAsJsonAsync("/admin/items", SampleItem(int.MaxValue));
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, res.StatusCode);
    }
}
