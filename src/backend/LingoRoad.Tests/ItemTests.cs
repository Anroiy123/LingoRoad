using System.Net.Http.Json;
using LingoRoad.Endpoints;

namespace LingoRoad.Tests;

public class ItemTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public ItemTests(TestAppFactory f) => _client = f.CreateClient();

    private static object SampleItem(string skillCode = "grammar.tenses.present_perfect") => new
    {
        skillCode,
        cefrLevel = "B1",
        type = "mcq",
        stem = "She ___ in Hanoi since 2019.",
        options = new[] { "has lived", "lived", "lives", "is living" },
        correctAnswer = "has lived",
        source = "test"
    };

    [Fact]
    public async Task Import_then_list_filters_by_skill_and_cefr()
    {
        var res = await _client.PostAsJsonAsync("/admin/items/import", new[] { SampleItem() });
        res.EnsureSuccessStatusCode();

        var list = await _client.GetAsync(
            "/items?skill=grammar.tenses.present_perfect&cefr=B1");
        list.EnsureSuccessStatusCode();
        var body = await list.Content.ReadAsStringAsync();
        Assert.DoesNotContain("\"correctAnswer\"", body, StringComparison.OrdinalIgnoreCase);

        var items = await list.Content.ReadFromJsonAsync<List<ItemDto>>();
        var item = Assert.Single(items!);
        Assert.True(item.A >= 0.6 && item.A <= 2.0); // import omits a,b,c -> endpoint defaults apply
    }

    [Fact]
    public async Task Import_with_unknown_skill_returns_400()
    {
        var res = await _client.PostAsJsonAsync("/admin/items/import",
            new[] { SampleItem(skillCode: "nope.nope") });
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, res.StatusCode);
    }
}
