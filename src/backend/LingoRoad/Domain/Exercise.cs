namespace LingoRoad.Domain;

public class Exercise
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public required string Type { get; set; }
    public required string Stem { get; set; }
    public required string OptionsJson { get; set; }
    public required string CorrectAnswer { get; set; }
    public string? ExplanationVi { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
