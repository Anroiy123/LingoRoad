using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class AdminGenerateItemsTests : IClassFixture<PlacementFactory>
{
    private readonly PlacementFactory _factory;
    public AdminGenerateItemsTests(PlacementFactory factory) => _factory = factory;

    private async Task<(HttpClient client, string skillCode)> AdminWithSkillAsync()
    {
        var client = await TestAuth.ClientAsync(_factory);
        var suffix = Guid.NewGuid().ToString("N");
        var skillCode = $"grammar.ai_gen_{suffix}";
        var skillResponse = await client.PostAsJsonAsync("/admin/skills", new
        {
            code = skillCode,
            name = "AI generation",
            nameVi = "Tạo bằng AI",
            category = "grammar",
            cefrLevel = "A2"
        });
        skillResponse.EnsureSuccessStatusCode();
        return (client, skillCode);
    }

    [Fact]
    public async Task Generate_persists_items_into_bank_with_irt_and_source_fields()
    {
        var (client, skillCode) = await AdminWithSkillAsync();

        var response = await client.PostAsJsonAsync("/admin/items/generate", new
        {
            skillCode,
            cefrLevel = "A2",
            type = "mcq",
            count = 2
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        Assert.Equal(2, body.GetProperty("generated").GetInt32());
        var items = body.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(2, items.Count);
        Assert.All(items, item =>
        {
            Assert.Equal(skillCode, item.GetProperty("skillCode").GetString());
            Assert.Equal("A2", item.GetProperty("cefrLevel").GetString());
            Assert.Equal(1, item.GetProperty("a").GetDouble());
            Assert.Equal(-1.2, item.GetProperty("b").GetDouble());
            Assert.Contains("AI generated", item.GetProperty("source").GetString());
        });

        var itemsList = await client.GetStringAsync("/admin/items");
        Assert.Contains("She ___ here since 2019.", itemsList);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Contains("generate", await db.AdminAuditEvents
            .Where(x => x.EntityId == skillCode).Select(x => x.Action).ToListAsync());
    }

    [Fact]
    public async Task Generate_rejects_unknown_skill_without_calling_ml()
    {
        var client = await TestAuth.ClientAsync(_factory);
        var response = await client.PostAsJsonAsync("/admin/items/generate", new
        {
            skillCode = "does.not.exist",
            cefrLevel = "A2",
            type = "mcq",
            count = 1
        });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("unknown_skill", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Generate_rejects_unsupported_item_type()
    {
        var (client, skillCode) = await AdminWithSkillAsync();
        var response = await client.PostAsJsonAsync("/admin/items/generate", new
        {
            skillCode,
            cefrLevel = "A2",
            type = "listening_mcq",
            count = 1
        });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("unsupported_item_type", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Generate_returns_503_and_persists_nothing_when_ml_is_unavailable()
    {
        var (client, skillCode) = await AdminWithSkillAsync();
        try
        {
            _factory.Fake.Throw = true;
            var response = await client.PostAsJsonAsync("/admin/items/generate", new
            {
                skillCode,
                cefrLevel = "A2",
                type = "mcq",
                count = 1
            });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        }
        finally
        {
            _factory.Fake.Throw = false;
        }

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var skill = await db.Skills.SingleAsync(s => s.Code == skillCode);
        Assert.False(await db.Items.AnyAsync(i => i.SkillId == skill.Id));
    }

    [Fact]
    public async Task Generate_requires_admin_role()
    {
        var (adminClient, skillCode) = await AdminWithSkillAsync();
        var payload = new { skillCode, cefrLevel = "A2", type = "mcq", count = 1 };

        using var anonymous = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonymous.PostAsJsonAsync("/admin/items/generate", payload)).StatusCode);

        using var learner = await TestAuth.ClientAsync(_factory, UserRoles.Learner);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await learner.PostAsJsonAsync("/admin/items/generate", payload)).StatusCode);
    }
}
