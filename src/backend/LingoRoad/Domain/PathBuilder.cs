namespace LingoRoad.Domain;

public record PathStep(Skill Skill, double Mastery, string Reason,
    string Availability, int Sequence);

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

        var mastered = mastery.Where(pair => pair.Value >= MasteryThreshold)
            .Select(pair => pair.Key).ToHashSet();
        var prerequisites = edges.GroupBy(edge => edge.SkillId)
            .ToDictionary(group => group.Key,
                group => group.Select(edge => edge.PrerequisiteId).ToArray());

        var candidates = SkillGraph.TopologicalOrder(skills, edges)
            .Where(s => !parents.Contains(s.Id))                 // leaves only
            .Where(s => CefrMap.Rank(s.CefrLevel) <= goal)
            .Select((skill, index) => new
            {
                Skill = skill,
                Mastery = mastery.GetValueOrDefault(skill.Id, 0.0),
                Reason = mastery.ContainsKey(skill.Id) ? "below_threshold" : "not_started",
                TopologyIndex = index,
                Availability = prerequisites.TryGetValue(skill.Id, out var requiredSkills) &&
                               requiredSkills.Any(id => !mastered.Contains(id))
                    ? "locked"
                    : "available"
            })
            .Where(step => step.Mastery < MasteryThreshold)
            .ToList();

        var current = candidates.Where(step => step.Availability == "available")
            .OrderBy(step => step.Reason == "below_threshold" ? 0 : 1)
            .ThenBy(step => step.TopologyIndex)
            .FirstOrDefault();

        return candidates
            .OrderBy(step => ReferenceEquals(step, current) ? 0
                : step.Availability == "available" ? 1 : 2)
            .ThenBy(step => step.TopologyIndex)
            .Select((step, index) => new PathStep(step.Skill, step.Mastery, step.Reason,
                ReferenceEquals(step, current) ? "current" : step.Availability, index + 1))
            .Take(limit)
            .ToList();
    }
}
