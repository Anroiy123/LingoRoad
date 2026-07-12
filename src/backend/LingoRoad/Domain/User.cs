namespace LingoRoad.Domain;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public string? Name { get; set; }
    public string TargetCefr { get; set; } = "B2";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
