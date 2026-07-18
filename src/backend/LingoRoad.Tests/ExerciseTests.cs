using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class ExerciseTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public ExerciseTests(PlacementFactory f) => _client = f.CreateClient();

    private record ExDto(Guid Id, string Stem, string[] Options);
    private record SubmitDto(bool Correct, string CorrectAnswer, string? ExplanationVi);

    private async Task AuthAsync()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "E" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
    }

    [Fact]
    public async Task Generate_returns_exercises_without_answers_then_submit_scores()
    {
        await AuthAsync();
        var gen = await _client.PostAsJsonAsync("/exercises/generate",
            new { skillCode = "grammar.tenses.present_perfect" });
        gen.EnsureSuccessStatusCode();
        var body = await gen.Content.ReadAsStringAsync();
        // The correct answer text ("has lived") legitimately appears among the MCQ
        // options — a valid multiple-choice question must list it as a choice. What
        // must never leak is the answer-revealing metadata itself.
        Assert.DoesNotContain("correctAnswer", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("explanationVi", body, StringComparison.OrdinalIgnoreCase);
        var list = System.Text.Json.JsonSerializer.Deserialize<List<ExDto>>(body,
            new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotEmpty(list!);

        var submit = await _client.PostAsJsonAsync($"/exercises/{list![0].Id}/submit",
            new { answer = "has lived" });   // FakeMlClient's fixed correct answer
        var result = await submit.Content.ReadFromJsonAsync<SubmitDto>();
        Assert.True(result!.Correct);

        var mastery = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
        Assert.NotEmpty(mastery!);
    }

    [Fact]
    public async Task Resubmit_does_not_inflate_mastery()
    {
        await AuthAsync();
        var gen = await _client.PostAsJsonAsync("/exercises/generate",
            new { skillCode = "grammar.tenses.present_perfect" });
        var list = await gen.Content.ReadFromJsonAsync<List<ExDto>>();
        await _client.PostAsJsonAsync($"/exercises/{list![0].Id}/submit", new { answer = "has lived" });
        var after1 = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
        var submit2 = await _client.PostAsJsonAsync($"/exercises/{list[0].Id}/submit", new { answer = "has lived" });
        var result2 = await submit2.Content.ReadFromJsonAsync<SubmitDto>();
        Assert.True(result2!.Correct);                       // still graded
        var after2 = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
        Assert.Equal(System.Text.Json.JsonSerializer.Serialize(after1),
                     System.Text.Json.JsonSerializer.Serialize(after2));   // mastery unchanged
    }

    [Fact]
    public async Task Writing_evaluate_proxies_awe()
    {
        await AuthAsync();
        var res = await _client.PostAsJsonAsync("/writing/evaluate",
            new { taskPrompt = "Describe your hometown", essay = "My hometown is Da Nang." });
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("taskAchievement", body);
        Assert.Contains("overallVi", body);
    }
}
