namespace QuestGraph.Domain;

public class Skill
{
    public int Id { get; set; }
    public required string Code { get; set; }      // e.g. "grammar.tenses.present_perfect"
    public required string Name { get; set; }
    public required string NameVi { get; set; }
    public required string Category { get; set; }  // grammar|vocabulary|reading|listening|writing
    public int? ParentId { get; set; }
    public required string CefrLevel { get; set; } // A1..C2 — level where skill is introduced
}

public class SkillEdge
{
    public int PrerequisiteId { get; set; }
    public int SkillId { get; set; }
}
