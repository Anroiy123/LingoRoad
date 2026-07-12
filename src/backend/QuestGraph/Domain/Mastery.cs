namespace QuestGraph.Domain;

public class Mastery
{
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public double PCorrect { get; set; } = 0.5;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
