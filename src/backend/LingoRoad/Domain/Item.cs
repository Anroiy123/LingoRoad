namespace LingoRoad.Domain;

public class Item
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public required string Type { get; set; }          // mcq | cloze | listening_mcq
    public required string Stem { get; set; }
    public required string OptionsJson { get; set; }   // JSON string[] (empty array for cloze)
    public required string CorrectAnswer { get; set; }
    public double A { get; set; }
    public double B { get; set; }
    public double C { get; set; }
    public string? AudioUrl { get; set; }
    public required string Source { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
