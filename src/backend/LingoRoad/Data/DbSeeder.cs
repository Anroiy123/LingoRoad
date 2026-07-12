using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Domain;

namespace LingoRoad.Data;

public static class DbSeeder
{
    private record SkillSeed(string Code, string Name, string Name_vi, string Category, string Cefr, string? Parent);
    private record SeedFile(List<SkillSeed> Skills, List<string[]> Prerequisites);

    public static async Task SeedAsync(AppDbContext db)
    {
        if (await db.Skills.AnyAsync()) return; // idempotent

        var path = Path.Combine(AppContext.BaseDirectory, "Data", "Seed", "skills.json");
        var seed = JsonSerializer.Deserialize<SeedFile>(await File.ReadAllTextAsync(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

        var byCode = new Dictionary<string, Skill>();
        foreach (var s in seed.Skills)
        {
            var skill = new Skill { Code = s.Code, Name = s.Name, NameVi = s.Name_vi,
                Category = s.Category, CefrLevel = s.Cefr };
            byCode[s.Code] = skill;
            db.Skills.Add(skill);
        }
        await db.SaveChangesAsync();

        foreach (var s in seed.Skills.Where(s => s.Parent != null))
            byCode[s.Code].ParentId = byCode[s.Parent!].Id;
        foreach (var pair in seed.Prerequisites)
            db.SkillEdges.Add(new SkillEdge
                { PrerequisiteId = byCode[pair[0]].Id, SkillId = byCode[pair[1]].Id });
        await db.SaveChangesAsync();

        // fail fast on cycles
        SkillGraph.TopologicalOrder(await db.Skills.ToListAsync(), await db.SkillEdges.ToListAsync());
    }
}
