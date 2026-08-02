using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;

namespace LingoRoad.Services;

public record SampleMetric(string Key, int Samples, string Status, double? Correctness);
public record CalibrationMetric(int Samples, string Status, double? MeanPredicted,
    double? ObservedCorrectness, double? BrierScore);
public record DriftMetric(int RecentSamples, int BaselineSamples, string Status,
    double? RecentCorrectness, double? BaselineCorrectness, double? Delta);
public record FairnessMetric(int Samples, string Status, string Reason);
public record LearningQualityReport(DateTime GeneratedAt, int MinimumSampleSize,
    CalibrationMetric Calibration, IReadOnlyList<SampleMetric> ByCefr,
    IReadOnlyList<SampleMetric> BySkill, IReadOnlyList<SampleMetric> ByItem,
    IReadOnlyList<SampleMetric> ByLesson, DriftMetric Drift, FairnessMetric Fairness);

public sealed class LearningQualityService(AppDbContext db, IConfiguration configuration)
{
    public async Task<LearningQualityReport> BuildAsync(
        CancellationToken cancellationToken = default)
    {
        var minimum = Math.Clamp(
            configuration.GetValue<int?>("Analytics:MinimumSampleSize") ?? 30, 10, 1000);
        var now = DateTime.UtcNow;
        var since = now.AddDays(-60);
        var events = await db.LearningEvents.AsNoTracking()
            .Where(e => e.OccurredAt >= since &&
                (e.EventType == LearningEventTypes.AnswerSubmitted ||
                 e.EventType == LearningEventTypes.LessonCompleted))
            .ToListAsync(cancellationToken);
        var answers = events.Where(e => e.EventType == LearningEventTypes.AnswerSubmitted &&
            e.Correct is not null).ToList();
        var calibrationRows = answers.Where(e => e.PredictedCorrectness is not null).ToList();
        var calibration = new CalibrationMetric(
            calibrationRows.Count,
            Status(calibrationRows.Count, minimum),
            Enough(calibrationRows.Count, minimum)
                ? calibrationRows.Average(e => e.PredictedCorrectness!.Value) : null,
            Enough(calibrationRows.Count, minimum)
                ? calibrationRows.Average(e => e.Correct == true ? 1.0 : 0.0) : null,
            Enough(calibrationRows.Count, minimum)
                ? calibrationRows.Average(e => Math.Pow(
                    e.PredictedCorrectness!.Value - (e.Correct == true ? 1.0 : 0.0), 2))
                : null);

        var recent = answers.Where(e => e.OccurredAt >= now.AddDays(-30)).ToList();
        var baseline = answers.Where(e => e.OccurredAt < now.AddDays(-30)).ToList();
        var driftReady = Enough(recent.Count, minimum) && Enough(baseline.Count, minimum);
        var recentCorrectness = driftReady
            ? recent.Average(e => e.Correct == true ? 1.0 : 0.0) : (double?)null;
        var baselineCorrectness = driftReady
            ? baseline.Average(e => e.Correct == true ? 1.0 : 0.0) : (double?)null;

        return new LearningQualityReport(
            now,
            minimum,
            calibration,
            Metrics(answers.Where(e => !string.IsNullOrWhiteSpace(e.CefrLevel)),
                e => e.CefrLevel!, minimum),
            Metrics(answers.Where(e => e.SkillId is not null),
                e => e.SkillId!.Value.ToString(), minimum),
            Metrics(answers.Where(e => e.ItemId is not null),
                e => e.ItemId!.Value.ToString(), minimum),
            Metrics(events.Where(e => e.EventType == LearningEventTypes.LessonCompleted &&
                    e.LessonId is not null && e.Score is not null),
                e => e.LessonId!.Value.ToString(), minimum, e => e.Score!.Value),
            new DriftMetric(recent.Count, baseline.Count,
                driftReady ? "sufficient" : "insufficient_sample",
                recentCorrectness, baselineCorrectness,
                driftReady ? recentCorrectness - baselineCorrectness : null),
            new FairnessMetric(0, "insufficient_sample",
                "No consented demographic attributes are collected for fairness analysis."));
    }

    private static List<SampleMetric> Metrics(IEnumerable<LearningEvent> events,
        Func<LearningEvent, string> key, int minimum,
        Func<LearningEvent, double>? value = null) => events
        .GroupBy(key)
        .OrderBy(group => group.Key)
        .Select(group =>
        {
            var rows = group.ToList();
            return new SampleMetric(group.Key, rows.Count, Status(rows.Count, minimum),
                Enough(rows.Count, minimum)
                    ? rows.Average(value ?? (e => e.Correct == true ? 1.0 : 0.0))
                    : null);
        }).ToList();

    private static bool Enough(int count, int minimum) => count >= minimum;
    private static string Status(int count, int minimum) =>
        Enough(count, minimum) ? "sufficient" : "insufficient_sample";
}
