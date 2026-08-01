using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Data;

public static class ContentBundleSeeder
{
    private sealed record Bundle(string Version, string Source, string License,
        string Reviewer, List<LessonSeed> Lessons);
    private sealed record LessonSeed(string Id, string Slug, string Title,
        string TitleVi, string? DescriptionVi, string SkillCode, string Cefr,
        int Order, List<ItemSeed> Items);
    private sealed record ItemSeed(string Id, string Type, string Stem,
        string[] Options, string CorrectAnswer, string? ExplanationVi,
        string? AudioUrl);

    private static readonly HashSet<string> SupportedTypes =
        ["mcq", "cloze", "reorder"];
    private static readonly HashSet<string> SupportedCefr =
        ["A1", "A2", "B1", "B2"];

    public static async Task SeedAsync(AppDbContext db)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "Seed", "content.v1.json");
        var bytes = await File.ReadAllBytesAsync(path);
        var checksum = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        var bundle = JsonSerializer.Deserialize<Bundle>(bytes,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("Content bundle is empty.");

        Validate(bundle);
        var prior = await db.ContentBundleImports.SingleOrDefaultAsync(i => i.Version == bundle.Version);
        if (prior is not null)
        {
            if (!string.Equals(prior.Checksum, checksum, StringComparison.Ordinal))
                throw new InvalidOperationException(
                    $"Content bundle {bundle.Version} is immutable but its checksum changed.");
            return;
        }

        var skills = await db.Skills.ToDictionaryAsync(s => s.Code, StringComparer.OrdinalIgnoreCase);
        var missingSkills = bundle.Lessons.Select(l => l.SkillCode).Distinct()
            .Where(code => !skills.ContainsKey(code)).ToArray();
        if (missingSkills.Length > 0)
            throw new InvalidOperationException($"Unknown content skill(s): {string.Join(", ", missingSkills)}");

        await using var transaction = await db.Database.BeginTransactionAsync();
        foreach (var lessonSeed in bundle.Lessons)
        {
            var lessonId = StableGuid(lessonSeed.Id);
            var lesson = await db.Lessons.SingleOrDefaultAsync(l => l.StableId == lessonSeed.Id);
            if (lesson is null)
            {
                lesson = new Lesson
                {
                    Id = lessonId,
                    StableId = lessonSeed.Id,
                    Slug = lessonSeed.Slug,
                    Title = lessonSeed.Title,
                    TitleVi = lessonSeed.TitleVi,
                    SkillId = skills[lessonSeed.SkillCode].Id,
                    CefrLevel = lessonSeed.Cefr,
                    Order = lessonSeed.Order,
                    ContentVersion = bundle.Version,
                    ContentChecksum = checksum,
                    Source = bundle.Source,
                    License = bundle.License,
                    Reviewer = bundle.Reviewer,
                };
                db.Lessons.Add(lesson);
            }
            lesson.Slug = lessonSeed.Slug;
            lesson.Title = lessonSeed.Title;
            lesson.TitleVi = lessonSeed.TitleVi;
            lesson.DescriptionVi = lessonSeed.DescriptionVi;
            lesson.SkillId = skills[lessonSeed.SkillCode].Id;
            lesson.CefrLevel = lessonSeed.Cefr;
            lesson.Order = lessonSeed.Order;
            lesson.ContentVersion = bundle.Version;
            lesson.ContentChecksum = checksum;
            lesson.Source = bundle.Source;
            lesson.License = bundle.License;
            lesson.Reviewer = bundle.Reviewer;
            lesson.UpdatedAt = DateTime.UtcNow;

            for (var index = 0; index < lessonSeed.Items.Count; index++)
            {
                var itemSeed = lessonSeed.Items[index];
                var item = await db.Items.SingleOrDefaultAsync(i => i.StableId == itemSeed.Id);
                if (item is null)
                {
                    item = new Item
                    {
                        Id = StableGuid(itemSeed.Id),
                        StableId = itemSeed.Id,
                        SkillId = lesson.SkillId,
                        CefrLevel = lesson.CefrLevel,
                        Type = itemSeed.Type,
                        Stem = itemSeed.Stem,
                        OptionsJson = "[]",
                        CorrectAnswer = itemSeed.CorrectAnswer,
                        Source = bundle.Source,
                    };
                    db.Items.Add(item);
                }
                item.SkillId = lesson.SkillId;
                item.CefrLevel = lesson.CefrLevel;
                item.Type = itemSeed.Type;
                item.Stem = itemSeed.Stem;
                item.OptionsJson = JsonSerializer.Serialize(itemSeed.Options);
                item.CorrectAnswer = itemSeed.CorrectAnswer;
                item.ExplanationVi = itemSeed.ExplanationVi;
                item.AudioUrl = itemSeed.AudioUrl;
                item.A = 1.0;
                item.B = lesson.CefrLevel switch
                {
                    "A1" => -1.5,
                    "A2" => -0.5,
                    "B1" => 0.5,
                    "B2" => 1.5,
                    _ => 0,
                };
                item.C = itemSeed.Type == "mcq" ? 0.25 : 0;
                item.Source = bundle.Source;
                item.License = bundle.License;
                item.Reviewer = bundle.Reviewer;
                item.ContentVersion = bundle.Version;

                var link = await db.LessonItems.FindAsync(lessonId, item.Id);
                if (link is null)
                    db.LessonItems.Add(new LessonItem
                    { LessonId = lessonId, ItemId = item.Id, Order = index + 1 });
                else
                    link.Order = index + 1;
            }
        }
        db.ContentBundleImports.Add(new ContentBundleImport
        { Version = bundle.Version, Checksum = checksum });
        await db.SaveChangesAsync();
        await transaction.CommitAsync();
    }

    private static void Validate(Bundle bundle)
    {
        if (string.IsNullOrWhiteSpace(bundle.Version) ||
            string.IsNullOrWhiteSpace(bundle.Source) ||
            string.IsNullOrWhiteSpace(bundle.License) ||
            string.IsNullOrWhiteSpace(bundle.Reviewer))
            throw new InvalidOperationException("Content metadata is required.");
        if (bundle.Lessons.Count < 20)
            throw new InvalidOperationException("Content bundle must contain at least 20 lessons.");
        if (bundle.Lessons.Sum(l => l.Items.Count) < 100)
            throw new InvalidOperationException("Content bundle must contain at least 100 items.");
        if (bundle.Lessons.Select(l => l.Id).Distinct(StringComparer.Ordinal).Count() != bundle.Lessons.Count ||
            bundle.Lessons.Select(l => l.Slug).Distinct(StringComparer.Ordinal).Count() != bundle.Lessons.Count)
            throw new InvalidOperationException("Lesson IDs and slugs must be unique.");
        if (bundle.Lessons.Select(l => l.Order).Distinct().Count() != bundle.Lessons.Count ||
            bundle.Lessons.Any(l => !SupportedCefr.Contains(l.Cefr)))
            throw new InvalidOperationException("Lesson order must be unique and CEFR must be A1-B2.");
        var items = bundle.Lessons.SelectMany(l => l.Items).ToArray();
        if (items.Select(i => i.Id).Distinct(StringComparer.Ordinal).Count() != items.Length)
            throw new InvalidOperationException("Item IDs must be unique.");
        if (items.Any(i => !SupportedTypes.Contains(i.Type)))
            throw new InvalidOperationException("Unsupported exercise type in content bundle.");
        if (!SupportedTypes.IsSubsetOf(items.Select(i => i.Type)))
            throw new InvalidOperationException("Content bundle must cover mcq, cloze and reorder.");
        if (bundle.Lessons.Any(l => l.Items.Count == 0 || l.Order <= 0 ||
            l.Items.Any(i => string.IsNullOrWhiteSpace(i.Stem) ||
                             string.IsNullOrWhiteSpace(i.CorrectAnswer))))
            throw new InvalidOperationException("Lesson order and item content are required.");
        if (items.Any(i => i.Type == "mcq" &&
                           (i.Options.Length < 2 || !i.Options.Contains(i.CorrectAnswer))) ||
            items.Any(i => i.Type == "reorder" && i.Options.Length < 2))
            throw new InvalidOperationException("MCQ and reorder options are invalid.");
    }

    private static Guid StableGuid(string value)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes($"lingoroad:{value}"));
        return new Guid(hash.AsSpan(0, 16));
    }
}
