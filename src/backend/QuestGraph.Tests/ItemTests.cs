using System.Net.Http.Json;
using QuestGraph.Endpoints;

namespace QuestGraph.Tests;

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

        var items = await _client.GetFromJsonAsync<List<ItemDto>>(
            "/items?skill=grammar.tenses.present_perfect&cefr=B1");
        Assert.Single(items!);
        Assert.Equal("has lived", items![0].CorrectAnswer);
        Assert.True(items[0].A >= 0.6 && items[0].A <= 2.0); // import omits a,b,c -> endpoint defaults apply
    }

    [Fact]
    public async Task Import_with_unknown_skill_returns_400()
    {
        var res = await _client.PostAsJsonAsync("/admin/items/import",
            new[] { SampleItem(skillCode: "nope.nope") });
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, res.StatusCode);
    }
}
