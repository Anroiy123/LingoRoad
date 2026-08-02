using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Endpoints;

public record StartLessonRequest(Guid OperationId);
public record CompleteLessonRequest(Guid OperationId);

public static class LessonEndpoints
{
    public static void MapLessons(this WebApplication app)
    {
        app.MapGet("/path/today", TodayPlanAsync).RequireAuthorization();

        app.MapGet("/lessons/{id:guid}", async (Guid id,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var userId = principal.UserId();
            var lesson = await (from l in db.Lessons
                                join s in db.Skills on l.SkillId equals s.Id
                                where l.Id == id && l.IsPublished
                                select new
                                {
                                    l.Id,
                                    l.Slug,
                                    l.Title,
                                    l.TitleVi,
                                    l.DescriptionVi,
                                    skillCode = s.Code,
                                    cefr = l.CefrLevel,
                                    l.ContentVersion,
                                    l.Source,
                                    l.License,
                                    l.Reviewer,
                                    itemCount = db.LessonItems.Count(li => li.LessonId == l.Id),
                                    progress = db.UserLessonProgresses
                                        .Where(p => p.UserId == userId && p.LessonId == l.Id)
                                        .Select(p => new
                                        {
                                            p.CompletionCount,
                                            p.CorrectAnswers,
                                            p.TotalAnswers,
                                            p.LastCompletedAt
                                        })
                                        .SingleOrDefault()
                                }).SingleOrDefaultAsync();
            return lesson is null ? Results.NotFound() : Results.Ok(lesson);
        }).RequireAuthorization();

        app.MapPost("/lessons/{id:guid}/attempts", async (Guid id, StartLessonRequest req,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            if (req.OperationId == Guid.Empty)
                return ApiResults.Error("operation_id_required");
            var userId = principal.UserId();
            var replay = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                a.UserId == userId && a.StartOperationId == req.OperationId);
            if (replay is not null)
            {
                if (replay.LessonId != id)
                    return Results.Conflict(new { error = "idempotency_conflict" });
                return Results.Ok(await AttemptSnapshotAsync(db, replay));
            }

            var lesson = await db.Lessons.SingleOrDefaultAsync(l => l.Id == id && l.IsPublished);
            if (lesson is null) return Results.NotFound();
            var active = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                a.UserId == userId && a.LessonId == id && a.Status == LessonStatuses.InProgress);
            if (active is not null)
                return Results.Ok(await AttemptSnapshotAsync(db, active));

            var content = await (from li in db.LessonItems
                                 join item in db.Items on li.ItemId equals item.Id
                                 where li.LessonId == id
                                 orderby li.Order
                                 select new { item, li.Order }).ToListAsync();
            if (content.Count == 0)
                return Results.Conflict(new { error = "lesson_has_no_items" });

            var attempt = new LessonAttempt
            {
                UserId = userId,
                LessonId = id,
                StartOperationId = req.OperationId,
            };
            db.LessonAttempts.Add(attempt);
            db.Exercises.AddRange(content.Select(row => new Exercise
            {
                UserId = userId,
                LessonAttemptId = attempt.Id,
                SourceItemId = row.item.Id,
                Sequence = row.Order,
                SkillId = row.item.SkillId,
                CefrLevel = row.item.CefrLevel,
                Type = row.item.Type,
                Stem = row.item.Stem,
                OptionsJson = row.item.OptionsJson,
                CorrectAnswer = row.item.CorrectAnswer,
                ExplanationVi = row.item.ExplanationVi,
            }));
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                replay = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                    a.UserId == userId && a.StartOperationId == req.OperationId);
                if (replay is not null && replay.LessonId == id)
                    return Results.Ok(await AttemptSnapshotAsync(db, replay));
                active = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                    a.UserId == userId && a.LessonId == id &&
                    a.Status == LessonStatuses.InProgress);
                if (active is not null)
                    return Results.Ok(await AttemptSnapshotAsync(db, active));
                return Results.Conflict(new { error = "lesson_attempt_conflict" });
            }
            return Results.Created($"/lesson-attempts/{attempt.Id}",
                await AttemptSnapshotAsync(db, attempt));
        }).RequireAuthorization();

        app.MapGet("/lesson-attempts/{id:guid}", async (Guid id,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var attempt = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                a.Id == id && a.UserId == principal.UserId());
            return attempt is null
                ? Results.NotFound()
                : Results.Ok(await AttemptSnapshotAsync(db, attempt));
        }).RequireAuthorization();

        app.MapPost("/lesson-attempts/{id:guid}/complete", async (Guid id,
            CompleteLessonRequest req, System.Security.Claims.ClaimsPrincipal principal,
            AppDbContext db) =>
        {
            if (req.OperationId == Guid.Empty)
                return ApiResults.Error("operation_id_required");
            var userId = principal.UserId();
            var replay = await db.LessonCompletionOperations.SingleOrDefaultAsync(o =>
                o.UserId == userId && o.OperationId == req.OperationId);
            if (replay is not null)
            {
                if (replay.AttemptId != id)
                    return Results.Conflict(new { error = "idempotency_conflict" });
                return Results.Ok(CompletionSnapshot(replay));
            }

            var attempt = await db.LessonAttempts.SingleOrDefaultAsync(a =>
                a.Id == id && a.UserId == userId);
            if (attempt is null) return Results.NotFound();
            if (attempt.Status == LessonStatuses.Completed)
            {
                replay = await db.LessonCompletionOperations.SingleOrDefaultAsync(o =>
                    o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.AttemptId == id)
                    return Results.Ok(CompletionSnapshot(replay));
                return Results.Conflict(new { error = "lesson_already_completed" });
            }
            var exercises = await db.Exercises.Where(e => e.LessonAttemptId == id)
                .OrderBy(e => e.Sequence).ToListAsync();
            if (exercises.Count == 0 || exercises.Any(e => e.AnsweredAt is null))
                return Results.Conflict(new { error = "lesson_incomplete" });

            var completedAt = DateTime.UtcNow;
            var progress = await db.UserLessonProgresses.FindAsync(userId, attempt.LessonId);
            if (progress is null)
            {
                progress = new UserLessonProgress { UserId = userId, LessonId = attempt.LessonId };
                db.UserLessonProgresses.Add(progress);
            }
            var correctAnswers = exercises.Count(e => e.IsCorrect == true);
            progress.CompletionCount++;
            progress.CorrectAnswers = correctAnswers;
            progress.TotalAnswers = exercises.Count;
            progress.LastCompletedAt = completedAt;
            attempt.Status = LessonStatuses.Completed;
            attempt.CompletedAt = completedAt;

            var reviewCardsCreated = 0;
            foreach (var exercise in exercises.Where(e => e.IsCorrect == false))
            {
                if (await db.ReviewCards.AnyAsync(c => c.SourceExerciseId == exercise.Id)) continue;
                db.ReviewCards.Add(new ReviewCard
                {
                    UserId = userId,
                    SkillId = exercise.SkillId,
                    SourceExerciseId = exercise.Id,
                    Front = exercise.Stem,
                    Back = exercise.CorrectAnswer,
                });
                reviewCardsCreated++;
            }
            var operation = new LessonCompletionOperation
            {
                UserId = userId,
                OperationId = req.OperationId,
                AttemptId = id,
                CorrectAnswers = correctAnswers,
                TotalAnswers = exercises.Count,
                ReviewCardsCreated = reviewCardsCreated,
                CompletedAt = completedAt,
            };
            db.LessonCompletionOperations.Add(operation);
            var lesson = await db.Lessons.FindAsync(attempt.LessonId);
            db.LearningEvents.Add(new LearningEvent
            {
                UserId = userId,
                OperationId = req.OperationId,
                EventType = LearningEventTypes.LessonCompleted,
                LessonId = attempt.LessonId,
                LessonAttemptId = attempt.Id,
                SkillId = lesson?.SkillId,
                Score = exercises.Count == 0 ? 0 : (double)correctAnswers / exercises.Count,
                CefrLevel = lesson?.CefrLevel,
                ContentVersion = lesson?.ContentVersion,
                OccurredAt = completedAt,
            });
            db.RewardLedgerEntries.Add(new RewardLedgerEntry
            {
                UserId = userId,
                SourceOperationId = req.OperationId,
                SourceType = RewardSources.LessonCompletion,
                SourceEntityId = id,
                Xp = 20 + correctAnswers * 5,
                Coins = 2,
                StreakQualified = true,
                QuestCode = "daily_lesson",
                CreatedAt = completedAt,
            });
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                db.ChangeTracker.Clear();
                replay = await db.LessonCompletionOperations.SingleOrDefaultAsync(o =>
                    o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.AttemptId == id)
                    return Results.Ok(CompletionSnapshot(replay));
                return Results.Conflict(new { error = "lesson_already_completed" });
            }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                replay = await db.LessonCompletionOperations.SingleOrDefaultAsync(o =>
                    o.UserId == userId && o.OperationId == req.OperationId);
                if (replay is not null && replay.AttemptId == id)
                    return Results.Ok(CompletionSnapshot(replay));
                return Results.Conflict(new { error = "idempotency_conflict" });
            }
            return Results.Ok(CompletionSnapshot(operation));
        }).RequireAuthorization();
    }

    private static async Task<IResult> TodayPlanAsync(
        System.Security.Claims.ClaimsPrincipal principal, AppDbContext db)
    {
        var userId = principal.UserId();
        var target = (await db.Users.FindAsync(userId))!.TargetCefr;
        var lessons = await (from lesson in db.Lessons
                             join skill in db.Skills on lesson.SkillId equals skill.Id
                             where lesson.IsPublished
                             orderby lesson.Order
                             select new { lesson, skill }).ToListAsync();
        var progress = await db.UserLessonProgresses.Where(p => p.UserId == userId)
            .ToDictionaryAsync(p => p.LessonId);
        var mastery = await db.Masteries.Where(m => m.UserId == userId)
            .ToDictionaryAsync(m => m.SkillId, m => m.PCorrect);
        var lessonIds = lessons.Select(x => x.lesson.Id).ToArray();
        var itemCounts = await db.LessonItems.Where(li => lessonIds.Contains(li.LessonId))
            .GroupBy(li => li.LessonId)
            .ToDictionaryAsync(g => g.Key, g => g.Count());
        var rows = lessons
            .Where(x => CefrMap.Rank(x.lesson.CefrLevel) <= CefrMap.Rank(target))
            .Where(x => !progress.ContainsKey(x.lesson.Id) ||
                        mastery.GetValueOrDefault(x.lesson.SkillId) < 0.8)
            .Take(3)
            .Select(x => new
            {
                x.lesson.Id,
                x.lesson.Slug,
                x.lesson.Title,
                x.lesson.TitleVi,
                skillCode = x.skill.Code,
                cefr = x.lesson.CefrLevel,
                itemCount = itemCounts.GetValueOrDefault(x.lesson.Id),
                completed = progress.ContainsKey(x.lesson.Id),
                mastery = mastery.GetValueOrDefault(x.lesson.SkillId),
            }).ToList();
        return Results.Ok(rows);
    }

    private static async Task<object> AttemptSnapshotAsync(AppDbContext db, LessonAttempt attempt)
    {
        var lesson = await db.Lessons.FindAsync(attempt.LessonId);
        var rows = await db.Exercises.Where(e => e.LessonAttemptId == attempt.Id)
            .OrderBy(e => e.Sequence).ToListAsync();
        var exercises = rows.Select(e => new
        {
            e.Id,
            e.Sequence,
            e.Type,
            e.Stem,
            options = JsonSerializer.Deserialize<string[]>(e.OptionsJson),
            answered = e.AnsweredAt != null,
        }).ToList();
        return new
        {
            attempt.Id,
            attempt.LessonId,
            lesson!.Slug,
            lesson.Title,
            lesson.TitleVi,
            attempt.Status,
            attempt.StartedAt,
            attempt.CompletedAt,
            exercises,
        };
    }

    private static object CompletionSnapshot(LessonCompletionOperation operation) => new
    {
        operation.AttemptId,
        operation.OperationId,
        status = LessonStatuses.Completed,
        operation.CorrectAnswers,
        operation.TotalAnswers,
        operation.ReviewCardsCreated,
        CompletedAt = DateTime.SpecifyKind(operation.CompletedAt, DateTimeKind.Utc),
    };
}
