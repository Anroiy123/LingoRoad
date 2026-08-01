using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Endpoints;

public static class DashboardEndpoints
{
    public static void MapDashboard(this WebApplication app)
    {
        app.MapGet("/gamification/me", async (
            System.Security.Claims.ClaimsPrincipal principal, GamificationService gamification) =>
            Results.Ok(await gamification.GetSummaryAsync(principal.UserId())))
            .RequireAuthorization();

        app.MapGet("/quests", async (
            System.Security.Claims.ClaimsPrincipal principal, GamificationService gamification) =>
            Results.Ok(await gamification.GetQuestsAsync(principal.UserId())))
            .RequireAuthorization();

        app.MapGet("/dashboard", async (System.Security.Claims.ClaimsPrincipal principal,
            AppDbContext db, GamificationService gamification) =>
        {
            var userId = principal.UserId();
            var user = await db.Users.FindAsync(userId);
            if (user is null) return Results.NotFound();
            var rewards = await gamification.GetSummaryAsync(userId);
            var dueReviews = await db.ReviewCards.CountAsync(c =>
                c.UserId == userId && c.Due <= DateTime.UtcNow);
            var completedLessons = await db.UserLessonProgresses.CountAsync(p =>
                p.UserId == userId && p.CompletionCount > 0);
            var currentCefr = await db.TestSessions
                .Where(session => session.UserId == userId && session.Status == "completed")
                .OrderByDescending(session => session.CompletedAt)
                .Select(session => session.ResultCefr)
                .FirstOrDefaultAsync() ?? "A1";
            var masteryRows = await (from row in db.Masteries
                                     join skill in db.Skills on row.SkillId equals skill.Id
                                     where row.UserId == userId
                                     select new
                                     {
                                         code = skill.Code,
                                         name = skill.Name,
                                         nameVi = skill.NameVi,
                                         mastery = row.PCorrect,
                                     }).ToListAsync();
            var weekStart = DateTime.UtcNow.Date.AddDays(-6);
            var weeklyCompletions = await db.LessonAttempts.CountAsync(a =>
                a.UserId == userId && a.CompletedAt >= weekStart);

            var lessonRows = await (from lesson in db.Lessons
                                    join skill in db.Skills on lesson.SkillId equals skill.Id
                                    where lesson.IsPublished
                                    orderby lesson.Order
                                    select new { lesson, skill }).ToListAsync();
            var mastery = await db.Masteries.Where(m => m.UserId == userId)
                .ToDictionaryAsync(m => m.SkillId, m => m.PCorrect);
            var progress = await db.UserLessonProgresses.Where(p => p.UserId == userId)
                .ToDictionaryAsync(p => p.LessonId);
            var next = lessonRows.FirstOrDefault(x =>
                CefrMap.Rank(x.lesson.CefrLevel) <= CefrMap.Rank(user.TargetCefr) &&
                (!progress.ContainsKey(x.lesson.Id) ||
                 mastery.GetValueOrDefault(x.lesson.SkillId) < 0.8));
            var recent = await (from attempt in db.LessonAttempts
                                join lesson in db.Lessons on attempt.LessonId equals lesson.Id
                                where attempt.UserId == userId && attempt.CompletedAt != null
                                orderby attempt.CompletedAt descending
                                select new
                                {
                                    attempt.Id,
                                    lessonId = lesson.Id,
                                    lesson.Title,
                                    lesson.TitleVi,
                                    completedAt = attempt.CompletedAt,
                                }).Take(5).ToListAsync();
            var todayCompleted = await db.LessonAttempts.AnyAsync(a =>
                a.UserId == userId && a.CompletedAt >= DateTime.UtcNow.Date);

            return Results.Ok(new
            {
                name = string.IsNullOrWhiteSpace(user.Name) ? user.Email.Split('@')[0] : user.Name,
                currentCefr,
                targetCefr = user.TargetCefrConfirmed ? user.TargetCefr : null,
                user.DailyGoalMinutes,
                mastery = masteryRows.Count == 0 ? 0 : masteryRows.Average(row => row.mastery),
                weakSkills = masteryRows.OrderBy(row => row.mastery).Take(3),
                strongSkills = masteryRows.OrderByDescending(row => row.mastery).Take(3),
                dailyProgress = todayCompleted ? 1.0 : 0.0,
                weeklyProgress = Math.Clamp(weeklyCompletions / 7.0, 0, 1),
                dueReviews,
                completedLessons,
                rewards.Xp,
                rewards.Coins,
                rewards.CurrentStreak,
                rewards.LongestStreak,
                rewards.ActiveDates,
                todayLesson = next is null ? null : new
                {
                    next.lesson.Id,
                    next.lesson.Slug,
                    next.lesson.Title,
                    next.lesson.TitleVi,
                    skillCode = next.skill.Code,
                    cefr = next.lesson.CefrLevel,
                    itemCount = db.LessonItems.Count(li => li.LessonId == next.lesson.Id),
                },
                recentActivity = recent,
            });
        }).RequireAuthorization();
    }
}
