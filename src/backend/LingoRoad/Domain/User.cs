namespace LingoRoad.Domain;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public string? Name { get; set; }
    public string TargetCefr { get; set; } = "B2";
    public bool TargetCefrConfirmed { get; set; }
    public int DailyGoalMinutes { get; set; } = 30;
    public string? LearningPurpose { get; set; }
    public bool StudyReminderEnabled { get; set; } = true;
    public string? ReminderTime { get; set; }
    public string TimeZone { get; set; } = "Asia/Ho_Chi_Minh";
    public bool EmailNotifications { get; set; }
    public bool AppUpdates { get; set; } = true;
    public string Role { get; set; } = UserRoles.Learner;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public static class UserRoles
{
    public const string Learner = "Learner";
    public const string Admin = "Admin";
}

public class UserFocusSkill
{
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
}
