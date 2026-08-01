using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;

namespace LingoRoad.Endpoints;

public record ItemDto(Guid Id, string SkillCode, string CefrLevel, string Type, string Stem,
    string[] Options, double A, double B, double C, string? AudioUrl);

public static class ItemEndpoints
{
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
                x.i.A, x.i.B, x.i.C, x.i.AudioUrl));
        });

    }
}
