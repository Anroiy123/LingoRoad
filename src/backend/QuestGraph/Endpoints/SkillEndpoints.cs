using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;

namespace QuestGraph.Endpoints;

public record SkillDto(int Id, string Code, string Name, string NameVi, string Category, int? ParentId, string CefrLevel);
public record EdgeDto(int From, int To);
public record SkillGraphDto(List<SkillDto> Nodes, List<EdgeDto> Edges);

public static class SkillEndpoints
{
    public static void MapSkills(this WebApplication app)
    {
        app.MapGet("/skills", async (AppDbContext db) =>
            await db.Skills.Select(s => new SkillDto(s.Id, s.Code, s.Name, s.NameVi, s.Category, s.ParentId, s.CefrLevel))
                .ToListAsync());

        app.MapGet("/skills/graph", async (AppDbContext db) => new SkillGraphDto(
            await db.Skills.Select(s => new SkillDto(s.Id, s.Code, s.Name, s.NameVi, s.Category, s.ParentId, s.CefrLevel)).ToListAsync(),
            await db.SkillEdges.Select(e => new EdgeDto(e.PrerequisiteId, e.SkillId)).ToListAsync()));
    }
}
