namespace LingoRoad.Domain;

public class Exercise
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid? LessonAttemptId { get; set; }
    public Guid? SourceItemId { get; set; }
    public int Sequence { get; set; }
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public required string Type { get; set; }
    public required string Stem { get; set; }
    public required string OptionsJson { get; set; }
    public required string CorrectAnswer { get; set; }
    public string? ModelVersion { get; set; }
    public string? ExplanationVi { get; set; }
    public string? SubmittedAnswer { get; set; }
    public bool? IsCorrect { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? AnsweredAt { get; set; }
}
