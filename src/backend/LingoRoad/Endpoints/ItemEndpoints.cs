using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;

namespace LingoRoad.Endpoints;

public record ItemImportDto(string SkillCode, string CefrLevel, string Type, string Stem,
    string[] Options, string CorrectAnswer, string Source,
    double? A = null, double? B = null, double? C = null, string? AudioUrl = null);
public record ItemDto(Guid Id, string SkillCode, string CefrLevel, string Type, string Stem,
    string[] Options, string CorrectAnswer, double A, double B, double C, string? AudioUrl);

public static class ItemEndpoints
{
    private static readonly Dictionary<string, double> CefrB = new()
        { ["A1"] = -2.0, ["A2"] = -1.2, ["B1"] = -0.4, ["B2"] = 0.5, ["C1"] = 1.4, ["C2"] = 2.2 };

    public static void MapItems(this WebApplication app)
    {
        app.MapGet("/items", async (string? skill, string? cefr, AppDbContext db) =>
        {
            var q = db.Items.Join(db.Skills, i => i.SkillId, s => s.Id, (i, s) => new { i, s.Code });
            if (skill != null) q = q.Where(x => x.Code == skill);
            if (cefr != null) q = q.Where(x => x.i.CefrLevel == cefr);
            return (await q.ToListAsync()).Select(x => new ItemDto(
                x.i.Id, x.Code, x.i.CefrLevel, x.i.Type, x.i.Stem,
                JsonSerializer.Deserialize<string[]>(x.i.OptionsJson)!,
                x.i.CorrectAnswer, x.i.A, x.i.B, x.i.C, x.i.AudioUrl));
        });

        if (!app.Environment.IsDevelopment()) return;

        app.MapPost("/admin/items/import", async (List<ItemImportDto> dtos, AppDbContext db) =>
        {
            var skills = await db.Skills.ToDictionaryAsync(s => s.Code, s => s.Id);
            var items = new List<Item>();
            foreach (var d in dtos)
            {
                if (!skills.TryGetValue(d.SkillCode, out var skillId))
                    return Results.BadRequest(new { error = "unknown_skill", skill = d.SkillCode });
                items.Add(new Item
                {
                    SkillId = skillId, CefrLevel = d.CefrLevel, Type = d.Type, Stem = d.Stem,
                    OptionsJson = JsonSerializer.Serialize(d.Options),
                    CorrectAnswer = d.CorrectAnswer, Source = d.Source, AudioUrl = d.AudioUrl,
                    A = d.A ?? 1.0,
                    B = d.B ?? CefrB[d.CefrLevel],
                    C = d.C ?? (d.Options.Length > 0 ? Math.Round(1.0 / d.Options.Length, 4) : 0.0)
                });
            }
            db.Items.AddRange(items);
            await db.SaveChangesAsync();
            return Results.Ok(new { imported = items.Count });
        });
    }
}
