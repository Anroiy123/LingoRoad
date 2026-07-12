namespace LingoRoad.Domain;

public class TestSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Status { get; set; } = "active";   // active | completed
    public double Theta { get; set; }
    public double ThetaSe { get; set; } = 1.0;
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public string? ResultCefr { get; set; }
}

public class Response
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SessionId { get; set; }
    public Guid ItemId { get; set; }
    public string? Answer { get; set; }
    public bool Correct { get; set; }
    public double ThetaAfter { get; set; }
    public double SeAfter { get; set; }
    public DateTime AnsweredAt { get; set; } = DateTime.UtcNow;
}
