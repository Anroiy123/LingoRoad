namespace LingoRoad.Domain;

/// <summary>Immutable response snapshot for an idempotent review grade request.</summary>
public class ReviewGradeOperation
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid CardId { get; set; }
    public Guid OperationId { get; set; }
    public int Rating { get; set; }
    public int ExpectedReps { get; set; }
    public DateTime Due { get; set; }
    public required string State { get; set; }
    public double Stability { get; set; }
    public double Difficulty { get; set; }
    public int Reps { get; set; }
    public string? SubmittedAnswer { get; set; }
    public bool? Correct { get; set; }
}
