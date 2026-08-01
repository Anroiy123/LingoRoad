using Microsoft.EntityFrameworkCore;
using LingoRoad.Domain;

namespace LingoRoad.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Skill> Skills => Set<Skill>();
    public DbSet<SkillEdge> SkillEdges => Set<SkillEdge>();
    public DbSet<Item> Items => Set<Item>();
    public DbSet<TestSession> TestSessions => Set<TestSession>();
    public DbSet<Response> Responses => Set<Response>();
    public DbSet<Mastery> Masteries => Set<Mastery>();
    public DbSet<ReviewCard> ReviewCards => Set<ReviewCard>();
    public DbSet<ReviewGradeOperation> ReviewGradeOperations => Set<ReviewGradeOperation>();
    public DbSet<Exercise> Exercises => Set<Exercise>();
    public DbSet<SpeakingAttempt> SpeakingAttempts => Set<SpeakingAttempt>();
    public DbSet<UserFocusSkill> UserFocusSkills => Set<UserFocusSkill>();
    public DbSet<RefreshSession> RefreshSessions => Set<RefreshSession>();
    public DbSet<SecurityAuditEvent> SecurityAuditEvents => Set<SecurityAuditEvent>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<User>().HasIndex(u => u.Email).IsUnique();
        mb.Entity<User>().ToTable(t => t.HasCheckConstraint(
            "CK_Users_Email_Canonical",
            "\"Email\" = lower(trim(\"Email\"))"));
        mb.Entity<User>().ToTable(t => t.HasCheckConstraint(
            "CK_Users_DailyGoalMinutes", "\"DailyGoalMinutes\" BETWEEN 10 AND 120"));
        mb.Entity<UserFocusSkill>().HasKey(x => new { x.UserId, x.SkillId });
        mb.Entity<UserFocusSkill>().HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<UserFocusSkill>().HasOne<Skill>().WithMany().HasForeignKey(x => x.SkillId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<RefreshSession>().HasIndex(x => x.TokenHash).IsUnique();
        mb.Entity<RefreshSession>().HasIndex(x => new { x.UserId, x.FamilyId });
        mb.Entity<RefreshSession>().Property(x => x.RevokedAt).IsConcurrencyToken();
        mb.Entity<RefreshSession>().HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<SecurityAuditEvent>().HasIndex(x => x.CreatedAt);
        mb.Entity<Skill>().HasIndex(s => s.Code).IsUnique();
        mb.Entity<SkillEdge>().HasKey(e => new { e.PrerequisiteId, e.SkillId });
        mb.Entity<Item>().HasIndex(i => new { i.SkillId, i.CefrLevel });
        mb.Entity<Response>().HasIndex(r => r.SessionId);
        mb.Entity<Response>().HasIndex(r => new { r.SessionId, r.ItemId }).IsUnique();
        mb.Entity<TestSession>()
            .HasOne<Item>()
            .WithMany()
            .HasForeignKey(s => s.CurrentItemId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<Mastery>().HasKey(m => new { m.UserId, m.SkillId });
        mb.Entity<ReviewCard>().HasIndex(c => new { c.UserId, c.Due });
        mb.Entity<ReviewCard>().Property(c => c.Reps).IsConcurrencyToken();
        mb.Entity<ReviewGradeOperation>().HasIndex(o => new { o.UserId, o.OperationId }).IsUnique();
    }
}
