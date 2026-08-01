using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record AdminSkillRequest(string Code, string Name, string NameVi, string Category,
    int? ParentId, string CefrLevel);
public record AdminItemRequest(string? StableId, int SkillId, string CefrLevel, string Type,
    string Stem, string[] Options, string CorrectAnswer, string? ExplanationVi, string Source,
    string? License, string? Reviewer, string? ContentVersion, double A = 1,
    double B = 0, double C = 0, string? AudioUrl = null);
public record AdminLessonRequest(string StableId, string Slug, string Title, string TitleVi,
    string? DescriptionVi, int SkillId, string CefrLevel, int Order, bool IsPublished,
    List<Guid> ItemIds, string? Source = null, string? License = null, string? Reviewer = null,
    string? ContentVersion = null);
public record AdminImportSkill(string Code, string Name, string NameVi, string Category,
    string? ParentCode, string CefrLevel);
public record AdminImportItem(string StableId, string SkillCode, string CefrLevel, string Type,
    string Stem, string[] Options, string CorrectAnswer, string? ExplanationVi = null);
public record AdminImportLesson(string StableId, string Slug, string Title, string TitleVi,
    string? DescriptionVi, string SkillCode, string CefrLevel, int Order, bool IsPublished,
    List<string> ItemStableIds);
public record AdminImportRequest(string Version, string Source, string License, string Reviewer,
    List<AdminImportSkill> Skills, List<AdminImportItem> Items,
    List<AdminImportLesson> Lessons);

public static partial class AdminEndpoints
{
    private static readonly HashSet<string> CefrLevels = ["A1", "A2", "B1", "B2", "C1", "C2"];
    private static readonly HashSet<string> ItemTypes = ["mcq", "cloze", "reorder", "listening_mcq"];

    public static void MapAdmin(this WebApplication app)
    {
        var admin = app.MapGroup("/admin").RequireAuthorization("Admin");

        admin.MapGet("/skills", async (AppDbContext db) =>
            await db.Skills.OrderBy(s => s.Code).Select(s => new
            {
                s.Id,
                s.Code,
                s.Name,
                s.NameVi,
                s.Category,
                s.ParentId,
                s.CefrLevel
            }).ToListAsync());

        admin.MapPost("/skills", CreateSkillAsync);
        admin.MapPut("/skills/{id:int}", UpdateSkillAsync);
        admin.MapDelete("/skills/{id:int}", DeleteSkillAsync);

        admin.MapGet("/items", async (AppDbContext db) =>
            await (from item in db.Items
                   join skill in db.Skills on item.SkillId equals skill.Id
                   orderby item.CreatedAt descending
                   select new
                   {
                       item.Id,
                       item.StableId,
                       item.SkillId,
                       skillCode = skill.Code,
                       item.CefrLevel,
                       item.Type,
                       item.Stem,
                       options = JsonSerializer.Deserialize<string[]>(item.OptionsJson),
                       item.CorrectAnswer,
                       item.ExplanationVi,
                       item.Source,
                       item.License,
                       item.Reviewer,
                       item.ContentVersion,
                       item.A,
                       item.B,
                       item.C,
                       item.AudioUrl
                   }).ToListAsync());
        admin.MapPost("/items", CreateItemAsync);
        admin.MapPut("/items/{id:guid}", UpdateItemAsync);
        admin.MapDelete("/items/{id:guid}", DeleteItemAsync);

        admin.MapGet("/lessons", async (AppDbContext db) =>
        {
            var lessons = await (from lesson in db.Lessons
                                 join skill in db.Skills on lesson.SkillId equals skill.Id
                                 orderby lesson.Order
                                 select new
                                 {
                                     lesson.Id,
                                     lesson.StableId,
                                     lesson.Slug,
                                     lesson.Title,
                                     lesson.TitleVi,
                                     lesson.DescriptionVi,
                                     lesson.SkillId,
                                     skillCode = skill.Code,
                                     lesson.CefrLevel,
                                     lesson.Order,
                                     lesson.IsPublished,
                                     lesson.ContentVersion,
                                     lesson.Source,
                                     lesson.License,
                                     lesson.Reviewer,
                                     lesson.UpdatedAt
                                 }).ToListAsync();
            var lessonIds = lessons.Select(x => x.Id).ToList();
            var links = await db.LessonItems.Where(x => lessonIds.Contains(x.LessonId))
                .OrderBy(x => x.Order).ToListAsync();
            return lessons.Select(x => new
            {
                x.Id,
                x.StableId,
                x.Slug,
                x.Title,
                x.TitleVi,
                x.DescriptionVi,
                x.SkillId,
                x.skillCode,
                x.CefrLevel,
                x.Order,
                x.IsPublished,
                x.ContentVersion,
                x.Source,
                x.License,
                x.Reviewer,
                x.UpdatedAt,
                itemIds = links.Where(link => link.LessonId == x.Id).Select(link => link.ItemId)
            });
        });
        admin.MapPost("/lessons", CreateLessonAsync);
        admin.MapPut("/lessons/{id:guid}", UpdateLessonAsync);
        admin.MapDelete("/lessons/{id:guid}", DeleteLessonAsync);

        admin.MapPost("/imports/validate", ValidateImportAsync);
        admin.MapPost("/imports", ApplyImportAsync);
        admin.MapGet("/analytics/overview", AnalyticsAsync);
        admin.MapGet("/audit", async (int? limit, AppDbContext db) =>
            await db.AdminAuditEvents.OrderByDescending(x => x.CreatedAt)
                .Take(Math.Clamp(limit ?? 50, 1, 200)).ToListAsync());
    }

    private static async Task<IResult> CreateSkillAsync(AdminSkillRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = ValidateSkill(req);
        if (errors.Count > 0) return Validation(errors);
        if (await db.Skills.IgnoreQueryFilters().AnyAsync(s => s.Code == req.Code.Trim()))
            return Results.Conflict(new { error = "skill_code_taken" });
        if (req.ParentId is not null && !await db.Skills.AnyAsync(s => s.Id == req.ParentId))
            return Results.BadRequest(new { error = "unknown_parent" });
        var skill = new Skill
        {
            Code = req.Code.Trim(),
            Name = req.Name.Trim(),
            NameVi = req.NameVi.Trim(),
            Category = req.Category.Trim().ToLowerInvariant(),
            ParentId = req.ParentId,
            CefrLevel = req.CefrLevel.Trim().ToUpperInvariant()
        };
        db.Skills.Add(skill);
        Audit(db, principal, "create", "skill", skill.Code);
        await db.SaveChangesAsync();
        return Results.Created($"/admin/skills/{skill.Id}", new { skill.Id });
    }

    private static async Task<IResult> UpdateSkillAsync(int id, AdminSkillRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = ValidateSkill(req);
        if (errors.Count > 0) return Validation(errors);
        var skill = await db.Skills.SingleOrDefaultAsync(s => s.Id == id);
        if (skill is null) return Results.NotFound();
        if (req.ParentId == id) return Results.BadRequest(new { error = "parent_cycle" });
        if (req.ParentId is not null && !await db.Skills.AnyAsync(s => s.Id == req.ParentId))
            return Results.BadRequest(new { error = "unknown_parent" });
        if (req.ParentId is not null && await CreatesSkillCycleAsync(id, req.ParentId.Value, db))
            return Results.BadRequest(new { error = "parent_cycle" });
        if (await db.Skills.IgnoreQueryFilters().AnyAsync(s => s.Id != id && s.Code == req.Code.Trim()))
            return Results.Conflict(new { error = "skill_code_taken" });
        skill.Code = req.Code.Trim();
        skill.Name = req.Name.Trim();
        skill.NameVi = req.NameVi.Trim();
        skill.Category = req.Category.Trim().ToLowerInvariant();
        skill.ParentId = req.ParentId;
        skill.CefrLevel = req.CefrLevel.Trim().ToUpperInvariant();
        Audit(db, principal, "update", "skill", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> DeleteSkillAsync(int id, ClaimsPrincipal principal,
        AppDbContext db)
    {
        var skill = await db.Skills.SingleOrDefaultAsync(s => s.Id == id);
        if (skill is null) return Results.NotFound();
        if (await db.Skills.AnyAsync(s => s.ParentId == id) ||
            await db.Items.AnyAsync(i => i.SkillId == id) ||
            await db.Lessons.AnyAsync(l => l.SkillId == id))
            return Results.Conflict(new { error = "skill_in_use" });
        skill.IsDeleted = true;
        Audit(db, principal, "delete", "skill", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> CreateItemAsync(AdminItemRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = await ValidateItemAsync(req, db);
        if (errors.Count > 0) return Validation(errors);
        if (!string.IsNullOrWhiteSpace(req.StableId) && await db.Items.IgnoreQueryFilters()
            .AnyAsync(i => i.StableId == req.StableId.Trim()))
            return Results.Conflict(new { error = "item_stable_id_taken" });
        var item = new Item
        {
            StableId = NullIfEmpty(req.StableId),
            SkillId = req.SkillId,
            CefrLevel = req.CefrLevel.Trim().ToUpperInvariant(),
            Type = req.Type.Trim(),
            Stem = req.Stem.Trim(),
            OptionsJson = JsonSerializer.Serialize(req.Options),
            CorrectAnswer = req.CorrectAnswer.Trim(),
            ExplanationVi = NullIfEmpty(req.ExplanationVi),
            Source = req.Source.Trim(),
            License = NullIfEmpty(req.License),
            Reviewer = NullIfEmpty(req.Reviewer),
            ContentVersion = NullIfEmpty(req.ContentVersion),
            A = req.A,
            B = req.B,
            C = req.C,
            AudioUrl = NullIfEmpty(req.AudioUrl)
        };
        db.Items.Add(item);
        Audit(db, principal, "create", "item", item.StableId ?? item.Id.ToString());
        await db.SaveChangesAsync();
        return Results.Created($"/admin/items/{item.Id}", new { item.Id });
    }

    private static async Task<IResult> UpdateItemAsync(Guid id, AdminItemRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = await ValidateItemAsync(req, db);
        if (errors.Count > 0) return Validation(errors);
        var item = await db.Items.SingleOrDefaultAsync(i => i.Id == id);
        if (item is null) return Results.NotFound();
        if (!string.IsNullOrWhiteSpace(req.StableId) && await db.Items.IgnoreQueryFilters()
            .AnyAsync(i => i.Id != id && i.StableId == req.StableId.Trim()))
            return Results.Conflict(new { error = "item_stable_id_taken" });
        item.StableId = NullIfEmpty(req.StableId);
        item.SkillId = req.SkillId;
        item.CefrLevel = req.CefrLevel.Trim().ToUpperInvariant();
        item.Type = req.Type.Trim();
        item.Stem = req.Stem.Trim();
        item.OptionsJson = JsonSerializer.Serialize(req.Options);
        item.CorrectAnswer = req.CorrectAnswer.Trim();
        item.ExplanationVi = NullIfEmpty(req.ExplanationVi);
        item.Source = req.Source.Trim();
        item.License = NullIfEmpty(req.License);
        item.Reviewer = NullIfEmpty(req.Reviewer);
        item.ContentVersion = NullIfEmpty(req.ContentVersion);
        item.A = req.A; item.B = req.B; item.C = req.C;
        item.AudioUrl = NullIfEmpty(req.AudioUrl);
        Audit(db, principal, "update", "item", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> DeleteItemAsync(Guid id, ClaimsPrincipal principal,
        AppDbContext db)
    {
        var item = await db.Items.SingleOrDefaultAsync(i => i.Id == id);
        if (item is null) return Results.NotFound();
        if (await db.LessonItems.AnyAsync(li => li.ItemId == id))
            return Results.Conflict(new { error = "item_in_use" });
        item.IsDeleted = true;
        Audit(db, principal, "delete", "item", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> CreateLessonAsync(AdminLessonRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = await ValidateLessonAsync(req, db);
        if (errors.Count > 0) return Validation(errors);
        if (await db.Lessons.IgnoreQueryFilters().AnyAsync(l =>
            l.StableId == req.StableId.Trim() || l.Slug == req.Slug.Trim()))
            return Results.Conflict(new { error = "lesson_identifier_taken" });
        var lesson = NewLesson(req);
        db.Lessons.Add(lesson);
        AddLessonItems(db, lesson.Id, req.ItemIds);
        Audit(db, principal, "create", "lesson", lesson.StableId);
        await db.SaveChangesAsync();
        return Results.Created($"/admin/lessons/{lesson.Id}", new { lesson.Id });
    }

    private static async Task<IResult> UpdateLessonAsync(Guid id, AdminLessonRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = await ValidateLessonAsync(req, db);
        if (errors.Count > 0) return Validation(errors);
        var lesson = await db.Lessons.SingleOrDefaultAsync(l => l.Id == id);
        if (lesson is null) return Results.NotFound();
        if (await db.Lessons.IgnoreQueryFilters().AnyAsync(l => l.Id != id &&
            (l.StableId == req.StableId.Trim() || l.Slug == req.Slug.Trim())))
            return Results.Conflict(new { error = "lesson_identifier_taken" });
        ApplyLesson(lesson, req);
        await db.LessonItems.Where(x => x.LessonId == id).ExecuteDeleteAsync();
        AddLessonItems(db, id, req.ItemIds);
        Audit(db, principal, "update", "lesson", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> DeleteLessonAsync(Guid id, ClaimsPrincipal principal,
        AppDbContext db)
    {
        var lesson = await db.Lessons.SingleOrDefaultAsync(l => l.Id == id);
        if (lesson is null) return Results.NotFound();
        lesson.IsDeleted = true;
        lesson.IsPublished = false;
        lesson.UpdatedAt = DateTime.UtcNow;
        Audit(db, principal, "delete", "lesson", id.ToString());
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> ValidateImportAsync(AdminImportRequest req,
        AppDbContext db)
    {
        var errors = await ImportErrorsAsync(req, db);
        return Results.Ok(new
        {
            valid = errors.Count == 0,
            checksum = Checksum(req),
            counts = new { skills = req.Skills.Count, items = req.Items.Count, lessons = req.Lessons.Count },
            errors
        });
    }

    private static async Task<IResult> ApplyImportAsync(AdminImportRequest req,
        ClaimsPrincipal principal, AppDbContext db)
    {
        var errors = await ImportErrorsAsync(req, db);
        if (errors.Count > 0) return Validation(errors);
        var checksum = Checksum(req);
        var previous = await db.ContentBundleImports.SingleOrDefaultAsync(x => x.Version == req.Version);
        if (previous is not null)
            return previous.Checksum == checksum
                ? Results.Ok(new { replay = true, version = req.Version, checksum })
                : Results.Conflict(new { error = "import_version_changed" });

        await using var transaction = await db.Database.BeginTransactionAsync();
        var skills = await db.Skills.IgnoreQueryFilters().ToDictionaryAsync(x => x.Code);
        foreach (var row in req.Skills)
        {
            if (!skills.TryGetValue(row.Code, out var skill))
            {
                skill = new Skill
                {
                    Code = row.Code,
                    Name = row.Name,
                    NameVi = row.NameVi,
                    Category = row.Category,
                    CefrLevel = row.CefrLevel
                };
                db.Skills.Add(skill);
                skills[row.Code] = skill;
            }
            else
            {
                skill.Name = row.Name; skill.NameVi = row.NameVi;
                skill.Category = row.Category; skill.CefrLevel = row.CefrLevel;
                skill.IsDeleted = false;
            }
        }
        await db.SaveChangesAsync();
        foreach (var row in req.Skills)
            skills[row.Code].ParentId = row.ParentCode is null ? null : skills[row.ParentCode].Id;

        var items = await db.Items.IgnoreQueryFilters().Where(x => x.StableId != null)
            .ToDictionaryAsync(x => x.StableId!);
        foreach (var row in req.Items)
        {
            if (!items.TryGetValue(row.StableId, out var item))
            {
                item = new Item
                {
                    StableId = row.StableId,
                    SkillId = skills[row.SkillCode].Id,
                    CefrLevel = row.CefrLevel,
                    Type = row.Type,
                    Stem = row.Stem,
                    OptionsJson = JsonSerializer.Serialize(row.Options),
                    CorrectAnswer = row.CorrectAnswer,
                    ExplanationVi = row.ExplanationVi,
                    Source = req.Source,
                    License = req.License,
                    Reviewer = req.Reviewer,
                    ContentVersion = req.Version,
                    A = 1,
                    B = CefrDifficulty(row.CefrLevel),
                    C = row.Options.Length == 0 ? 0 : Math.Round(1.0 / row.Options.Length, 4)
                };
                db.Items.Add(item);
                items[row.StableId] = item;
            }
            else
            {
                item.SkillId = skills[row.SkillCode].Id; item.CefrLevel = row.CefrLevel;
                item.Type = row.Type; item.Stem = row.Stem;
                item.OptionsJson = JsonSerializer.Serialize(row.Options);
                item.CorrectAnswer = row.CorrectAnswer; item.ExplanationVi = row.ExplanationVi;
                item.Source = req.Source; item.License = req.License; item.Reviewer = req.Reviewer;
                item.ContentVersion = req.Version; item.A = 1;
                item.B = CefrDifficulty(row.CefrLevel);
                item.C = row.Options.Length == 0 ? 0 : Math.Round(1.0 / row.Options.Length, 4);
                item.IsDeleted = false;
            }
        }
        await db.SaveChangesAsync();

        var lessons = await db.Lessons.IgnoreQueryFilters().ToDictionaryAsync(x => x.StableId);
        foreach (var row in req.Lessons)
        {
            if (!lessons.TryGetValue(row.StableId, out var lesson))
            {
                lesson = new Lesson
                {
                    Id = Guid.NewGuid(),
                    StableId = row.StableId,
                    Slug = row.Slug,
                    Title = row.Title,
                    TitleVi = row.TitleVi,
                    SkillId = skills[row.SkillCode].Id,
                    CefrLevel = row.CefrLevel,
                    Order = row.Order,
                    ContentVersion = req.Version,
                    ContentChecksum = checksum,
                    Source = req.Source,
                    License = req.License,
                    Reviewer = req.Reviewer
                };
                db.Lessons.Add(lesson);
                lessons[row.StableId] = lesson;
            }
            lesson.Slug = row.Slug; lesson.Title = row.Title; lesson.TitleVi = row.TitleVi;
            lesson.DescriptionVi = row.DescriptionVi; lesson.SkillId = skills[row.SkillCode].Id;
            lesson.CefrLevel = row.CefrLevel; lesson.Order = row.Order;
            lesson.IsPublished = row.IsPublished; lesson.ContentVersion = req.Version;
            lesson.IsDeleted = false;
            lesson.ContentChecksum = checksum; lesson.Source = req.Source;
            lesson.License = req.License; lesson.Reviewer = req.Reviewer;
            lesson.UpdatedAt = DateTime.UtcNow;
            await db.LessonItems.Where(x => x.LessonId == lesson.Id).ExecuteDeleteAsync();
            AddLessonItems(db, lesson.Id, row.ItemStableIds.Select(id => items[id].Id).ToList());
        }
        db.ContentBundleImports.Add(new ContentBundleImport
        { Version = req.Version, Checksum = checksum });
        Audit(db, principal, "apply", "content_import", req.Version,
            JsonSerializer.Serialize(new
            {
                skills = req.Skills.Count,
                items = req.Items.Count,
                lessons = req.Lessons.Count
            }));
        await db.SaveChangesAsync();
        await transaction.CommitAsync();
        return Results.Ok(new { replay = false, version = req.Version, checksum });
    }

    private static async Task<IResult> AnalyticsAsync(AppDbContext db)
    {
        var learners = await db.Users.CountAsync(x => x.Role == UserRoles.Learner);
        var activeSince = DateTime.UtcNow.AddDays(-30);
        var activeLearners = await db.LessonAttempts.Where(x => x.StartedAt >= activeSince)
            .Select(x => x.UserId).Distinct().CountAsync();
        var completedLessons = await db.LessonAttempts.CountAsync(x => x.Status == LessonStatuses.Completed);
        var answers = await db.Exercises.CountAsync(x => x.AnsweredAt != null);
        var correctAnswers = await db.Exercises.CountAsync(x => x.IsCorrect == true);
        var dueReviews = await db.ReviewCards.CountAsync(x => x.Due <= DateTime.UtcNow);
        var mastery = await (from row in db.Masteries
                             join skill in db.Skills on row.SkillId equals skill.Id
                             group row by skill.Category into rows
                             select new { category = rows.Key, average = rows.Average(x => x.PCorrect) })
            .ToListAsync();
        var itemUsage = await (from exercise in db.Exercises
                               where exercise.SourceItemId != null && exercise.AnsweredAt != null
                               group exercise by exercise.SourceItemId into rows
                               orderby rows.Count() descending
                               select new
                               {
                                   itemId = rows.Key,
                                   attempts = rows.Count(),
                                   correctness = rows.Average(x => x.IsCorrect == true ? 1.0 : 0.0)
                               })
            .Take(20).ToListAsync();
        return Results.Ok(new
        {
            learners,
            activeLearners,
            completedLessons,
            answers,
            correctAnswers,
            correctness = answers == 0 ? 0 : (double)correctAnswers / answers,
            dueReviews,
            mastery,
            itemUsage,
            content = new
            {
                skills = await db.Skills.CountAsync(),
                lessons = await db.Lessons.CountAsync(),
                publishedLessons = await db.Lessons.CountAsync(x => x.IsPublished),
                items = await db.Items.CountAsync()
            }
        });
    }

    private static List<string> ValidateSkill(AdminSkillRequest req)
    {
        var errors = new List<string>();
        if (!SkillCodeRegex().IsMatch(req.Code?.Trim() ?? "")) errors.Add("invalid_skill_code");
        if (string.IsNullOrWhiteSpace(req.Name) || string.IsNullOrWhiteSpace(req.NameVi))
            errors.Add("skill_name_required");
        if (string.IsNullOrWhiteSpace(req.Category)) errors.Add("skill_category_required");
        if (!CefrLevels.Contains(req.CefrLevel?.Trim().ToUpperInvariant() ?? ""))
            errors.Add("invalid_cefr");
        return errors;
    }

    private static async Task<List<string>> ValidateItemAsync(AdminItemRequest req, AppDbContext db)
    {
        var errors = new List<string>();
        if (!await db.Skills.AnyAsync(x => x.Id == req.SkillId)) errors.Add("unknown_skill");
        if (!CefrLevels.Contains(req.CefrLevel?.Trim().ToUpperInvariant() ?? "")) errors.Add("invalid_cefr");
        if (!ItemTypes.Contains(req.Type?.Trim() ?? "")) errors.Add("invalid_item_type");
        if (string.IsNullOrWhiteSpace(req.Stem)) errors.Add("item_stem_required");
        if (string.IsNullOrWhiteSpace(req.CorrectAnswer)) errors.Add("correct_answer_required");
        if (string.IsNullOrWhiteSpace(req.Source)) errors.Add("source_required");
        if (req.Type is "mcq" or "reorder" or "listening_mcq" && req.Options.Length < 2)
            errors.Add("options_required");
        return errors;
    }

    private static async Task<List<string>> ValidateLessonAsync(AdminLessonRequest req, AppDbContext db)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(req.StableId) || string.IsNullOrWhiteSpace(req.Slug))
            errors.Add("lesson_identifier_required");
        if (string.IsNullOrWhiteSpace(req.Title) || string.IsNullOrWhiteSpace(req.TitleVi))
            errors.Add("lesson_title_required");
        if (!CefrLevels.Contains(req.CefrLevel?.Trim().ToUpperInvariant() ?? "")) errors.Add("invalid_cefr");
        if (!await db.Skills.AnyAsync(x => x.Id == req.SkillId)) errors.Add("unknown_skill");
        if (req.ItemIds.Count == 0 || req.ItemIds.Distinct().Count() != req.ItemIds.Count)
            errors.Add("invalid_lesson_items");
        else if (await db.Items.CountAsync(x => req.ItemIds.Contains(x.Id)) != req.ItemIds.Count)
            errors.Add("unknown_item");
        return errors;
    }

    private static async Task<List<string>> ImportErrorsAsync(AdminImportRequest req, AppDbContext db)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(req.Version) || string.IsNullOrWhiteSpace(req.Source) ||
            string.IsNullOrWhiteSpace(req.License) || string.IsNullOrWhiteSpace(req.Reviewer))
            errors.Add("metadata_required");
        if (req.Skills.Count == 0 && req.Items.Count == 0 && req.Lessons.Count == 0)
            errors.Add("content_required");
        AddDuplicates(errors, req.Skills.Select(x => x.Code), "duplicate_skill");
        AddDuplicates(errors, req.Items.Select(x => x.StableId), "duplicate_item");
        AddDuplicates(errors, req.Lessons.Select(x => x.StableId), "duplicate_lesson");
        AddDuplicates(errors, req.Lessons.Select(x => x.Slug), "duplicate_lesson_slug");
        var skillCodes = (await db.Skills.Select(x => x.Code).ToListAsync())
            .Concat(req.Skills.Select(x => x.Code)).ToHashSet();
        var itemIds = (await db.Items.Where(x => x.StableId != null).Select(x => x.StableId!).ToListAsync())
            .Concat(req.Items.Select(x => x.StableId)).ToHashSet();
        foreach (var skill in req.Skills)
        {
            if (!SkillCodeRegex().IsMatch(skill.Code) || !CefrLevels.Contains(skill.CefrLevel) ||
                string.IsNullOrWhiteSpace(skill.Name) || string.IsNullOrWhiteSpace(skill.NameVi) ||
                string.IsNullOrWhiteSpace(skill.Category))
                errors.Add($"invalid_skill:{skill.Code}");
            if (skill.ParentCode == skill.Code) errors.Add($"parent_cycle:{skill.Code}");
            if (skill.ParentCode is not null && !skillCodes.Contains(skill.ParentCode))
                errors.Add($"unknown_parent:{skill.ParentCode}");
        }
        var existingSkills = await db.Skills
            .Select(x => new { x.Id, x.Code, x.ParentId }).ToListAsync();
        var codesById = existingSkills.ToDictionary(x => x.Id, x => x.Code);
        var parentsByCode = existingSkills.ToDictionary(
            x => x.Code,
            x => x.ParentId is null ? null : codesById.GetValueOrDefault(x.ParentId.Value));
        foreach (var skill in req.Skills) parentsByCode[skill.Code] = skill.ParentCode;
        if (HasSkillCycle(parentsByCode)) errors.Add("parent_cycle");

        var importedLessonIds = req.Lessons.Select(x => x.StableId).ToHashSet();
        var existingLessonSlugs = await db.Lessons.IgnoreQueryFilters()
            .Where(x => !importedLessonIds.Contains(x.StableId))
            .Select(x => x.Slug).ToListAsync();
        if (req.Lessons.Any(x => existingLessonSlugs.Contains(x.Slug)))
            errors.Add("lesson_slug_taken");
        foreach (var item in req.Items)
            if (string.IsNullOrWhiteSpace(item.StableId) || string.IsNullOrWhiteSpace(item.Stem) ||
                !skillCodes.Contains(item.SkillCode) || !CefrLevels.Contains(item.CefrLevel) ||
                !ItemTypes.Contains(item.Type) || string.IsNullOrWhiteSpace(item.CorrectAnswer) ||
                (item.Type is "mcq" or "reorder" or "listening_mcq" && item.Options.Length < 2))
                errors.Add($"invalid_item:{item.StableId}");
        foreach (var lesson in req.Lessons)
            if (string.IsNullOrWhiteSpace(lesson.StableId) || string.IsNullOrWhiteSpace(lesson.Slug) ||
                string.IsNullOrWhiteSpace(lesson.Title) || string.IsNullOrWhiteSpace(lesson.TitleVi) ||
                !skillCodes.Contains(lesson.SkillCode) || !CefrLevels.Contains(lesson.CefrLevel) ||
                lesson.ItemStableIds.Count == 0 ||
                lesson.ItemStableIds.Distinct().Count() != lesson.ItemStableIds.Count ||
                lesson.ItemStableIds.Any(id => !itemIds.Contains(id)))
                errors.Add($"invalid_lesson:{lesson.StableId}");
        return errors.Distinct().ToList();
    }

    private static void AddDuplicates(List<string> errors, IEnumerable<string> values, string error)
    {
        if (values.GroupBy(x => x).Any(x => x.Count() > 1)) errors.Add(error);
    }

    private static Lesson NewLesson(AdminLessonRequest req)
    {
        var lesson = new Lesson
        {
            Id = Guid.NewGuid(),
            StableId = req.StableId.Trim(),
            Slug = req.Slug.Trim(),
            Title = req.Title.Trim(),
            TitleVi = req.TitleVi.Trim(),
            SkillId = req.SkillId,
            CefrLevel = req.CefrLevel.Trim().ToUpperInvariant(),
            ContentVersion = NullIfEmpty(req.ContentVersion) ?? "admin-v1",
            ContentChecksum = Checksum(req),
            Source = NullIfEmpty(req.Source) ?? "Admin CMS",
            License = NullIfEmpty(req.License) ?? "Proprietary",
            Reviewer = NullIfEmpty(req.Reviewer) ?? "Admin"
        };
        ApplyLesson(lesson, req);
        return lesson;
    }

    private static void ApplyLesson(Lesson lesson, AdminLessonRequest req)
    {
        lesson.StableId = req.StableId.Trim(); lesson.Slug = req.Slug.Trim();
        lesson.Title = req.Title.Trim(); lesson.TitleVi = req.TitleVi.Trim();
        lesson.DescriptionVi = NullIfEmpty(req.DescriptionVi); lesson.SkillId = req.SkillId;
        lesson.CefrLevel = req.CefrLevel.Trim().ToUpperInvariant(); lesson.Order = req.Order;
        lesson.IsPublished = req.IsPublished; lesson.UpdatedAt = DateTime.UtcNow;
        lesson.ContentChecksum = Checksum(req);
        lesson.Source = NullIfEmpty(req.Source) ?? lesson.Source;
        lesson.License = NullIfEmpty(req.License) ?? lesson.License;
        lesson.Reviewer = NullIfEmpty(req.Reviewer) ?? lesson.Reviewer;
        lesson.ContentVersion = NullIfEmpty(req.ContentVersion) ?? lesson.ContentVersion;
    }

    private static async Task<bool> CreatesSkillCycleAsync(int skillId, int parentId, AppDbContext db)
    {
        var parents = await db.Skills.Select(x => new { x.Id, x.ParentId })
            .ToDictionaryAsync(x => x.Id, x => x.ParentId);
        int? current = parentId;
        var visited = new HashSet<int>();
        while (current is not null && visited.Add(current.Value))
        {
            if (current == skillId) return true;
            current = parents.GetValueOrDefault(current.Value);
        }
        return false;
    }

    private static bool HasSkillCycle(IReadOnlyDictionary<string, string?> parents)
    {
        foreach (var start in parents.Keys)
        {
            var visited = new HashSet<string>();
            string? current = start;
            while (current is not null && parents.ContainsKey(current))
            {
                if (!visited.Add(current)) return true;
                current = parents[current];
            }
        }
        return false;
    }

    private static void AddLessonItems(AppDbContext db, Guid lessonId, IReadOnlyList<Guid> itemIds) =>
        db.LessonItems.AddRange(itemIds.Select((itemId, index) => new LessonItem
        { LessonId = lessonId, ItemId = itemId, Order = index + 1 }));

    private static IResult Validation(List<string> errors) =>
        Results.BadRequest(new { error = "validation_failed", errors });
    private static string? NullIfEmpty(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static string Checksum<T>(T value) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value)))).ToLowerInvariant();
    private static double CefrDifficulty(string cefr) => cefr switch
    { "A1" => -2, "A2" => -1.2, "B1" => -.4, _ => .5 };
    private static void Audit(AppDbContext db, ClaimsPrincipal principal, string action,
        string entityType, string entityId, string? detail = null) => db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                AdminUserId = principal.UserId(),
                Action = action,
                EntityType = entityType,
                EntityId = entityId,
                Detail = detail
            });

    [GeneratedRegex("^[a-z][a-z0-9_.-]{2,99}$", RegexOptions.CultureInvariant)]
    private static partial Regex SkillCodeRegex();
}
