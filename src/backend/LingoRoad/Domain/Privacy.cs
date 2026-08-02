namespace LingoRoad.Domain;

public static class LearningEventTypes
{
    public const string AnswerSubmitted = "answer_submitted";
    public const string LessonCompleted = "lesson_completed";
    public const string ReviewGraded = "review_graded";
    public const string SpeakingScored = "speaking_scored";
}

public class LearningEvent
{
    public long Id { get; set; }
    public Guid EventId { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid OperationId { get; set; }
    public required string EventType { get; set; }
    public Guid? LessonId { get; set; }
    public Guid? LessonAttemptId { get; set; }
    public Guid? ExerciseId { get; set; }
    public Guid? ItemId { get; set; }
    public int? SkillId { get; set; }
    public bool? Correct { get; set; }
    public double? PredictedCorrectness { get; set; }
    public int? Rating { get; set; }
    public double? Score { get; set; }
    public int? LatencyMs { get; set; }
    public string? CefrLevel { get; set; }
    public string? ModelVersion { get; set; }
    public string? ContentVersion { get; set; }
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}

public class ConsentRecord
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public required string ConsentType { get; set; }
    public required string PolicyVersion { get; set; }
    public required string Source { get; set; }
    public bool Granted { get; set; }
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
}

public static class AccountDeletionStatuses
{
    public const string Pending = "pending";
    public const string Completed = "completed";
    public const string Failed = "failed";
}

public class AccountDeletionRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string UserEmailHash { get; set; }
    public DateTime RequestedAt { get; set; } = DateTime.UtcNow;
    public DateTime ScheduledFor { get; set; }
    public string Status { get; set; } = AccountDeletionStatuses.Pending;
    public DateTime? CompletedAt { get; set; }
    public string? FailureCode { get; set; }
}
