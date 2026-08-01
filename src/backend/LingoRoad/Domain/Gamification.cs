namespace LingoRoad.Domain;

public static class RewardSources
{
    public const string LessonCompletion = "lesson_completion";
    public const string ReviewGrade = "review_grade";
}

public class RewardLedgerEntry
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public Guid SourceOperationId { get; set; }
    public required string SourceType { get; set; }
    public Guid SourceEntityId { get; set; }
    public int Xp { get; set; }
    public int Coins { get; set; }
    public bool StreakQualified { get; set; }
    public required string QuestCode { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
