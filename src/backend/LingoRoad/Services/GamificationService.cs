using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Services;

public record GamificationSummary(int Xp, int Coins, int Level, int CurrentStreak,
    int LongestStreak, int TodayXp, IReadOnlyList<DateOnly> ActiveDates);
public record QuestSummary(string Code, int Current, int Target, bool Completed);

public class GamificationService(AppDbContext db)
{
    public async Task<GamificationSummary> GetSummaryAsync(Guid userId)
    {
        var user = await db.Users.FindAsync(userId) ?? throw new InvalidOperationException("User missing.");
        var entries = await db.RewardLedgerEntries.Where(e => e.UserId == userId)
            .OrderBy(e => e.CreatedAt).ToListAsync();
        var dates = entries.Where(e => e.StreakQualified)
            .Select(e => LocalDate(e.CreatedAt, user.TimeZone)).Distinct().OrderBy(d => d).ToArray();
        var today = LocalDate(DateTime.UtcNow, user.TimeZone);
        var current = 0;
        var cursor = dates.Contains(today) ? today : today.AddDays(-1);
        while (dates.Contains(cursor))
        {
            current++;
            cursor = cursor.AddDays(-1);
        }
        var longest = 0;
        var run = 0;
        DateOnly? previous = null;
        foreach (var date in dates)
        {
            run = previous is not null && date.DayNumber == previous.Value.DayNumber + 1 ? run + 1 : 1;
            longest = Math.Max(longest, run);
            previous = date;
        }
        var xp = entries.Sum(e => e.Xp);
        return new GamificationSummary(
            xp,
            entries.Sum(e => e.Coins),
            xp / 100 + 1,
            current,
            longest,
            entries.Where(e => LocalDate(e.CreatedAt, user.TimeZone) == today).Sum(e => e.Xp),
            dates.Where(date => date >= today.AddYears(-1)).ToArray());
    }

    public async Task<List<QuestSummary>> GetQuestsAsync(Guid userId)
    {
        var user = await db.Users.FindAsync(userId) ?? throw new InvalidOperationException("User missing.");
        var today = LocalDate(DateTime.UtcNow, user.TimeZone);
        var entries = await db.RewardLedgerEntries.Where(e => e.UserId == userId).ToListAsync();
        var todayEntries = entries.Where(e => LocalDate(e.CreatedAt, user.TimeZone) == today).ToArray();
        var lessonCount = todayEntries.Count(e => e.QuestCode == "daily_lesson");
        var reviewCount = todayEntries.Count(e => e.QuestCode == "daily_review");
        var xp = todayEntries.Sum(e => e.Xp);
        return
        [
            new("daily_lesson", lessonCount, 1, lessonCount >= 1),
            new("daily_review", reviewCount, 5, reviewCount >= 5),
            new("daily_xp", xp, 50, xp >= 50),
        ];
    }

    private static DateOnly LocalDate(DateTime utc, string timeZoneId)
    {
        try
        {
            var zone = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
            return DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(
                DateTime.SpecifyKind(utc, DateTimeKind.Utc), zone));
        }
        catch (TimeZoneNotFoundException)
        {
            return DateOnly.FromDateTime(utc);
        }
        catch (InvalidTimeZoneException)
        {
            return DateOnly.FromDateTime(utc);
        }
    }
}
