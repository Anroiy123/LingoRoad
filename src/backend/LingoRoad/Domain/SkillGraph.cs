namespace LingoRoad.Domain;

public static class SkillGraph
{
    public static List<Skill> TopologicalOrder(
        IReadOnlyList<Skill> skills, IReadOnlyList<SkillEdge> edges)
    {
        var indeg = skills.ToDictionary(s => s.Id, _ => 0);
        var adj = skills.ToDictionary(s => s.Id, _ => new List<int>());
        foreach (var e in edges) { indeg[e.SkillId]++; adj[e.PrerequisiteId].Add(e.SkillId); }

        var byId = skills.ToDictionary(s => s.Id);
        var queue = new Queue<int>(skills.Where(s => indeg[s.Id] == 0)
                                         .OrderBy(s => s.CefrLevel).ThenBy(s => s.Code)
                                         .Select(s => s.Id));
        var result = new List<Skill>();
        while (queue.Count > 0)
        {
            var id = queue.Dequeue();
            result.Add(byId[id]);
            foreach (var next in adj[id])
                if (--indeg[next] == 0) queue.Enqueue(next);
        }
        if (result.Count != skills.Count)
            throw new InvalidOperationException("Skill graph contains a cycle");
        return result;
    }
}
