using System.Net.Http.Json;
using LingoRoad.Domain;
using LingoRoad.Endpoints;

namespace LingoRoad.Tests;

public class SkillTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public SkillTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Skills_are_seeded_and_listed()
    {
        var skills = await _client.GetFromJsonAsync<List<SkillDto>>("/skills");
        Assert.True(skills!.Count >= 30);
        Assert.Contains(skills, s => s.Code == "grammar.tenses.present_perfect");
    }

    [Fact]
    public async Task Graph_returns_nodes_and_prerequisite_edges()
    {
        var graph = await _client.GetFromJsonAsync<SkillGraphDto>("/skills/graph");
        Assert.NotEmpty(graph!.Edges);
        // past_simple is a prerequisite of present_perfect
        var ps = graph.Nodes.Single(n => n.Code == "grammar.tenses.past_simple");
        var pp = graph.Nodes.Single(n => n.Code == "grammar.tenses.present_perfect");
        Assert.Contains(graph.Edges, e => e.From == ps.Id && e.To == pp.Id);
    }

    [Fact]
    public void Topological_order_puts_prerequisites_first()
    {
        var a = new Skill { Id = 1, Code = "a", Name = "a", NameVi = "a", Category = "grammar", CefrLevel = "A1" };
        var b = new Skill { Id = 2, Code = "b", Name = "b", NameVi = "b", Category = "grammar", CefrLevel = "A2" };
        var order = SkillGraph.TopologicalOrder([b, a], [new SkillEdge { PrerequisiteId = 1, SkillId = 2 }]);
        Assert.Equal(["a", "b"], order.Select(s => s.Code).ToArray());
    }
}
