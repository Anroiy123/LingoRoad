using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Domain;

namespace LingoRoad.Data;

public static class DbSeeder
{
    private record SkillSeed(string Code, string Name, string Name_vi, string Category, string Cefr, string? Parent);
    private record SeedFile(List<SkillSeed> Skills, List<string[]> Prerequisites);

    public static async Task SeedAsync(AppDbContext db, bool includeContent = true)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "Seed", "skills.json");
        var seed = JsonSerializer.Deserialize<SeedFile>(await File.ReadAllTextAsync(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

        var byCode = await db.Skills.ToDictionaryAsync(s => s.Code);
        foreach (var s in seed.Skills)
        {
            if (!byCode.TryGetValue(s.Code, out var skill))
            {
                skill = new Skill
                {
                    Code = s.Code,
                    Name = s.Name,
                    NameVi = s.Name_vi,
                    Category = s.Category,
                    CefrLevel = s.Cefr
                };
                byCode[s.Code] = skill;
                db.Skills.Add(skill);
            }
            skill.Name = s.Name;
            skill.NameVi = s.Name_vi;
            skill.Category = s.Category;
            skill.CefrLevel = s.Cefr;
        }
        await db.SaveChangesAsync();

        foreach (var s in seed.Skills.Where(s => s.Parent != null))
            byCode[s.Code].ParentId = byCode[s.Parent!].Id;
        foreach (var pair in seed.Prerequisites)
            if (!await db.SkillEdges.AnyAsync(e => e.PrerequisiteId == byCode[pair[0]].Id &&
                                                   e.SkillId == byCode[pair[1]].Id))
                db.SkillEdges.Add(new SkillEdge
                { PrerequisiteId = byCode[pair[0]].Id, SkillId = byCode[pair[1]].Id });
        await db.SaveChangesAsync();

        // fail fast on cycles
        SkillGraph.TopologicalOrder(await db.Skills.ToListAsync(), await db.SkillEdges.ToListAsync());
        if (includeContent)
            await ContentBundleSeeder.SeedAsync(db);
    }
}
