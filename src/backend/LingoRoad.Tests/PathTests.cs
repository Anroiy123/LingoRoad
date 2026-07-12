using System.Net.Http.Json;
using LingoRoad.Domain;

namespace LingoRoad.Tests;

public class PathBuilderTests
{
    private static Skill S(int id, string code, string cefr, int? parent = null) => new()
        { Id = id, Code = code, Name = code, NameVi = code, Category = "grammar",
          CefrLevel = cefr, ParentId = parent };

    private static readonly List<Skill> Skills =
    [
        S(1, "tenses", "A1"),                       // parent container
        S(2, "present_simple", "A1", 1),
        S(3, "past_simple", "A2", 1),
        S(4, "present_perfect", "B1", 1),
        S(5, "past_perfect", "B2", 1),
        S(6, "idioms", "C1", 1),
    ];
    private static readonly List<SkillEdge> Edges =
    [
        new() { PrerequisiteId = 2, SkillId = 3 },
        new() { PrerequisiteId = 3, SkillId = 4 },
        new() { PrerequisiteId = 4, SkillId = 5 },
    ];

    [Fact]
    public void Prerequisites_come_before_dependents()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "B2");
        var codes = path.Select(p => p.Skill.Code).ToList();
        Assert.True(codes.IndexOf("past_simple") < codes.IndexOf("present_perfect"));
        Assert.True(codes.IndexOf("present_perfect") < codes.IndexOf("past_perfect"));
    }

    [Fact]
    public void Mastered_skills_are_skipped()
    {
        var mastery = new Dictionary<int, double> { [2] = 0.9, [3] = 0.85 };
        var path = PathBuilder.Build(Skills, Edges, mastery, "B2");
        Assert.DoesNotContain(path, p => p.Skill.Code == "present_simple");
        Assert.Equal("present_perfect", path[0].Skill.Code);
    }

    [Fact]
    public void Skills_above_goal_cefr_are_excluded()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "B1");
        Assert.DoesNotContain(path, p => p.Skill.Code == "past_perfect");
        Assert.DoesNotContain(path, p => p.Skill.Code == "idioms");
    }

    [Fact]
    public void Parent_container_skills_are_excluded()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "C2");
        Assert.DoesNotContain(path, p => p.Skill.Code == "tenses");
    }

    [Fact]
    public void Reason_distinguishes_new_from_partial()
    {
        var mastery = new Dictionary<int, double> { [2] = 0.4 };
        var path = PathBuilder.Build(Skills, Edges, mastery, "A2");
        Assert.Equal("below_threshold", path.Single(p => p.Skill.Code == "present_simple").Reason);
        Assert.Equal("not_started", path.Single(p => p.Skill.Code == "past_simple").Reason);
    }
}

public class PathEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public PathEndpointTests(TestAppFactory f) => _client = f.CreateClient();

    private record PathRow(string Code, string Name, string NameVi, string Cefr,
        double Mastery, string Reason);

    [Fact]
    public async Task Path_returns_seeded_skills_as_not_started()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "P" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var path = await _client.GetFromJsonAsync<List<PathRow>>("/path?limit=5");
        Assert.Equal(5, path!.Count);
        Assert.All(path, p => Assert.Equal("not_started", p.Reason));
    }
}
