using System.Net.Http.Json;
using LingoRoad.Domain;

namespace LingoRoad.Tests;

public class MasteryCalcTests
{
    [Fact]
    public void Correct_answer_raises_estimate()
        => Assert.True(MasteryCalc.Update(0.5, true, 0) > 0.5);

    [Fact]
    public void Wrong_answer_lowers_estimate()
        => Assert.True(MasteryCalc.Update(0.5, false, 0) < 0.5);

    [Fact]
    public void Long_gap_decays_high_mastery_toward_baseline()
    {
        var fresh = MasteryCalc.Update(0.9, true, 0);
        var stale = MasteryCalc.Update(0.9, true, 60);
        Assert.True(stale < fresh);
    }

    [Fact]
    public void Estimate_stays_in_unit_interval()
    {
        var m = 0.5;
        for (var i = 0; i < 50; i++) m = MasteryCalc.Update(m, true, 0);
        Assert.InRange(m, 0.0, 1.0);
        for (var i = 0; i < 50; i++) m = MasteryCalc.Update(m, false, 0);
        Assert.InRange(m, 0.0, 1.0);
    }
}

public class MasteryEndpointTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public MasteryEndpointTests(PlacementFactory f) => _client = f.CreateClient();

    private record MasteryRow(string SkillCode, string SkillName, double PCorrect, DateTime UpdatedAt);
    private record PlacementItem(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
    private record StartDto(Guid SessionId, PlacementItem Item);
    private record StepDto(bool Done, PlacementItem? Item);

    [Fact]
    public async Task Answering_placement_items_updates_mastery_for_their_skill()
    {
        var email = $"{Guid.NewGuid():N}@t.com";
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "M" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var items = Enumerable.Range(0, 10).Select(i => new
        {
            skillCode = "grammar.tenses.present_simple", cefrLevel = "B1", type = "mcq",
            stem = $"M{i}: she ___ tea.", options = new[] { "drinks", "drink", "drank", "drunk" },
            correctAnswer = "drinks", source = "test"
        });
        (await _client.PostAsJsonAsync("/admin/items/import", items)).EnsureSuccessStatusCode();

        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();
        var step = await (await _client.PostAsJsonAsync($"/placement/{start!.SessionId}/answer",
            new { itemId = start.Item.Id, answer = "drinks" })).Content.ReadFromJsonAsync<StepDto>();
        await _client.PostAsJsonAsync($"/placement/{start.SessionId}/answer",
            new { itemId = step!.Item!.Id, answer = "drinks" });

        var mastery = await _client.GetFromJsonAsync<List<MasteryRow>>("/mastery");
        var row = Assert.Single(mastery!, m => m.SkillCode == "grammar.tenses.present_simple");
        Assert.True(row.PCorrect > 0.5);
    }
}
