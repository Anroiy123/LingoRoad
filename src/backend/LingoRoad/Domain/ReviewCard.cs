namespace LingoRoad.Domain;

public enum Grade { Again = 1, Hard = 2, Good = 3, Easy = 4 }

public class ReviewCard
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public required string Front { get; set; }
    public required string Back { get; set; }
    public double Stability { get; set; }
    public double Difficulty { get; set; }
    public DateTime Due { get; set; } = DateTime.UtcNow;
    public DateTime? LastReview { get; set; }
    public int Reps { get; set; }
    public string State { get; set; } = "new";
}
