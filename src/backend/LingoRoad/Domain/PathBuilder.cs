namespace LingoRoad.Domain;

public record PathStep(Skill Skill, double Mastery, string Reason);

public static class PathBuilder
{
    public const double MasteryThreshold = 0.8;

    public static List<PathStep> Build(IReadOnlyList<Skill> skills,
        IReadOnlyList<SkillEdge> edges, Dictionary<int, double> mastery,
        string goalCefr, int limit = 10)
    {
        var parents = skills.Where(s => s.ParentId != null)
                            .Select(s => s.ParentId!.Value).ToHashSet();
        var goal = CefrMap.Rank(goalCefr);

        return SkillGraph.TopologicalOrder(skills, edges)
            .Where(s => !parents.Contains(s.Id))                 // leaves only
            .Where(s => CefrMap.Rank(s.CefrLevel) <= goal)
            .Select(s => new PathStep(s, mastery.GetValueOrDefault(s.Id, 0.0),
                mastery.ContainsKey(s.Id) ? "below_threshold" : "not_started"))
            .Where(p => p.Mastery < MasteryThreshold)
            .Take(limit)
            .ToList();
    }
}
