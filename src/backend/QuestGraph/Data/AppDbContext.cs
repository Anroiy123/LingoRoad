using Microsoft.EntityFrameworkCore;
using QuestGraph.Domain;

namespace QuestGraph.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Skill> Skills => Set<Skill>();
    public DbSet<SkillEdge> SkillEdges => Set<SkillEdge>();
    public DbSet<Item> Items => Set<Item>();
    public DbSet<TestSession> TestSessions => Set<TestSession>();
    public DbSet<Response> Responses => Set<Response>();
    public DbSet<Mastery> Masteries => Set<Mastery>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<User>().HasIndex(u => u.Email).IsUnique();
        mb.Entity<Skill>().HasIndex(s => s.Code).IsUnique();
        mb.Entity<SkillEdge>().HasKey(e => new { e.PrerequisiteId, e.SkillId });
        mb.Entity<Item>().HasIndex(i => new { i.SkillId, i.CefrLevel });
        mb.Entity<Response>().HasIndex(r => r.SessionId);
        mb.Entity<Mastery>().HasKey(m => new { m.UserId, m.SkillId });
    }
}
