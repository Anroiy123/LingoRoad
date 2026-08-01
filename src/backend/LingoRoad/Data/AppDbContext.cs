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
    public DbSet<Lesson> Lessons => Set<Lesson>();
    public DbSet<LessonItem> LessonItems => Set<LessonItem>();
    public DbSet<LessonAttempt> LessonAttempts => Set<LessonAttempt>();
    public DbSet<UserLessonProgress> UserLessonProgresses => Set<UserLessonProgress>();
    public DbSet<ExerciseAnswerOperation> ExerciseAnswerOperations => Set<ExerciseAnswerOperation>();
    public DbSet<LessonCompletionOperation> LessonCompletionOperations => Set<LessonCompletionOperation>();
    public DbSet<ContentBundleImport> ContentBundleImports => Set<ContentBundleImport>();
    public DbSet<RewardLedgerEntry> RewardLedgerEntries => Set<RewardLedgerEntry>();

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
        mb.Entity<Item>().HasIndex(i => i.StableId).IsUnique();
        mb.Entity<Response>().HasIndex(r => r.SessionId);
        mb.Entity<Response>().HasIndex(r => new { r.SessionId, r.ItemId }).IsUnique();
        mb.Entity<TestSession>()
            .HasOne<Item>()
            .WithMany()
            .HasForeignKey(s => s.CurrentItemId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<Mastery>().HasKey(m => new { m.UserId, m.SkillId });
        mb.Entity<ReviewCard>().HasIndex(c => new { c.UserId, c.Due });
        mb.Entity<ReviewCard>().HasIndex(c => c.SourceExerciseId).IsUnique();
        mb.Entity<ReviewCard>().Property(c => c.Reps).IsConcurrencyToken();
        mb.Entity<ReviewGradeOperation>().HasIndex(o => new { o.UserId, o.OperationId }).IsUnique();
        mb.Entity<Lesson>().HasIndex(l => l.StableId).IsUnique();
        mb.Entity<Lesson>().HasIndex(l => l.Slug).IsUnique();
        mb.Entity<Lesson>().HasIndex(l => new { l.SkillId, l.Order });
        mb.Entity<Lesson>().HasOne<Skill>().WithMany().HasForeignKey(l => l.SkillId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<LessonItem>().HasKey(li => new { li.LessonId, li.ItemId });
        mb.Entity<LessonItem>().HasIndex(li => new { li.LessonId, li.Order }).IsUnique();
        mb.Entity<LessonItem>().HasOne<Lesson>().WithMany().HasForeignKey(li => li.LessonId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<LessonItem>().HasOne<Item>().WithMany().HasForeignKey(li => li.ItemId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<LessonAttempt>().HasIndex(a => new { a.UserId, a.StartOperationId }).IsUnique();
        mb.Entity<LessonAttempt>().HasIndex(a => new { a.UserId, a.LessonId, a.Status })
            .IsUnique().HasFilter("\"Status\" = 'in_progress'");
        mb.Entity<LessonAttempt>().HasOne<User>().WithMany().HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<LessonAttempt>().HasOne<Lesson>().WithMany().HasForeignKey(a => a.LessonId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<UserLessonProgress>().HasKey(p => new { p.UserId, p.LessonId });
        mb.Entity<UserLessonProgress>().HasOne<User>().WithMany().HasForeignKey(p => p.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<UserLessonProgress>().HasOne<Lesson>().WithMany().HasForeignKey(p => p.LessonId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<Exercise>().HasIndex(e => new { e.LessonAttemptId, e.SourceItemId }).IsUnique();
        mb.Entity<Exercise>().HasIndex(e => new { e.LessonAttemptId, e.Sequence }).IsUnique();
        mb.Entity<Exercise>().Property(e => e.AnsweredAt).IsConcurrencyToken();
        mb.Entity<LessonAttempt>().Property(a => a.Status).IsConcurrencyToken();
        mb.Entity<Exercise>().HasOne<LessonAttempt>().WithMany().HasForeignKey(e => e.LessonAttemptId)
            .OnDelete(DeleteBehavior.Cascade);
        mb.Entity<Exercise>().HasOne<Item>().WithMany().HasForeignKey(e => e.SourceItemId)
            .OnDelete(DeleteBehavior.Restrict);
        mb.Entity<ExerciseAnswerOperation>().HasIndex(o => new { o.UserId, o.OperationId }).IsUnique();
        mb.Entity<LessonCompletionOperation>().HasIndex(o => new { o.UserId, o.OperationId }).IsUnique();
        mb.Entity<ContentBundleImport>().HasIndex(i => i.Version).IsUnique();
        mb.Entity<RewardLedgerEntry>().HasIndex(e => new { e.UserId, e.SourceOperationId }).IsUnique();
        mb.Entity<RewardLedgerEntry>().HasIndex(e => new { e.UserId, e.CreatedAt });
        mb.Entity<RewardLedgerEntry>().HasOne<User>().WithMany().HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
