namespace LingoRoad.Domain;

public class SpeakingAttempt
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string PromptText { get; set; }
    public string? Transcript { get; set; }
    public double Total { get; set; }
    public double DurationSeconds { get; set; }
    public required string ModelVersion { get; set; }
    public string? FeedbackVi { get; set; }
    public string? ScoresJson { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
