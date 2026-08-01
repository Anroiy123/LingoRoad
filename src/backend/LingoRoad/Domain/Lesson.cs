namespace LingoRoad.Domain;

public static class LessonStatuses
{
    public const string InProgress = "in_progress";
    public const string Completed = "completed";
}

public class Lesson
{
    public Guid Id { get; set; }
    public required string StableId { get; set; }
    public required string Slug { get; set; }
    public required string Title { get; set; }
    public required string TitleVi { get; set; }
    public string? DescriptionVi { get; set; }
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public int Order { get; set; }
    public required string ContentVersion { get; set; }
    public required string ContentChecksum { get; set; }
    public required string Source { get; set; }
    public required string License { get; set; }
    public required string Reviewer { get; set; }
    public bool IsPublished { get; set; } = true;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class LessonItem
{
    public Guid LessonId { get; set; }
    public Guid ItemId { get; set; }
    public int Order { get; set; }
}

public class LessonAttempt
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid LessonId { get; set; }
    public Guid StartOperationId { get; set; }
    public string Status { get; set; } = LessonStatuses.InProgress;
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
}

public class UserLessonProgress
{
    public Guid UserId { get; set; }
    public Guid LessonId { get; set; }
    public int CompletionCount { get; set; }
    public int CorrectAnswers { get; set; }
    public int TotalAnswers { get; set; }
    public DateTime? LastCompletedAt { get; set; }
}

public class ExerciseAnswerOperation
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public Guid OperationId { get; set; }
    public Guid ExerciseId { get; set; }
    public required string Answer { get; set; }
    public bool Correct { get; set; }
    public required string CorrectAnswer { get; set; }
    public string? ExplanationVi { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class LessonCompletionOperation
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public Guid OperationId { get; set; }
    public Guid AttemptId { get; set; }
    public int CorrectAnswers { get; set; }
    public int TotalAnswers { get; set; }
    public int ReviewCardsCreated { get; set; }
    public DateTime CompletedAt { get; set; }
}

public class ContentBundleImport
{
    public long Id { get; set; }
    public required string Version { get; set; }
    public required string Checksum { get; set; }
    public DateTime AppliedAt { get; set; } = DateTime.UtcNow;
}
