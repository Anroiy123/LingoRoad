# Task 3: Skills Knowledge Graph — schema, seed, endpoints

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-1.

**Files:**
- Create: `QuestGraph/Domain/Skill.cs`, `QuestGraph/Domain/SkillGraph.cs`, `QuestGraph/Data/Seed/skills.json`, `QuestGraph/Data/DbSeeder.cs`, `QuestGraph/Endpoints/SkillEndpoints.cs`, `QuestGraph.Tests/SkillTests.cs`, `ml/research/expand_skills.py`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`, `QuestGraph/QuestGraph.csproj`

**Interfaces:**
- Consumes: `AppDbContext`, `TestAppFactory`.
- Produces: entities `Skill { int Id, string Code, string Name, string NameVi, string Category, int? ParentId, string CefrLevel }` and `SkillEdge { int PrerequisiteId, int SkillId }`; `DbSeeder.SeedAsync(AppDbContext)` (idempotent, called on startup in Development); `SkillGraph.TopologicalOrder(skills, edges) : List<Skill>` (used by task-12's path builder); `GET /skills`, `GET /skills/graph`.

- [x] **Step 1: Write the failing tests**

`QuestGraph.Tests/SkillTests.cs`:

```csharp
using System.Net.Http.Json;
using QuestGraph.Domain;
using QuestGraph.Endpoints;

namespace QuestGraph.Tests;

public class SkillTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public SkillTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Skills_are_seeded_and_listed()
    {
        var skills = await _client.GetFromJsonAsync<List<SkillDto>>("/skills");
        Assert.True(skills!.Count >= 30);
        Assert.Contains(skills, s => s.Code == "grammar.tenses.present_perfect");
    }

    [Fact]
    public async Task Graph_returns_nodes_and_prerequisite_edges()
    {
        var graph = await _client.GetFromJsonAsync<SkillGraphDto>("/skills/graph");
        Assert.NotEmpty(graph!.Edges);
        // past_simple is a prerequisite of present_perfect (seed has no direct
        // present_simple -> present_perfect edge; the chain goes via past_simple)
        var ps = graph.Nodes.Single(n => n.Code == "grammar.tenses.past_simple");
        var pp = graph.Nodes.Single(n => n.Code == "grammar.tenses.present_perfect");
        Assert.Contains(graph.Edges, e => e.From == ps.Id && e.To == pp.Id);
    }

    [Fact]
    public void Topological_order_puts_prerequisites_first()
    {
        var a = new Skill { Id = 1, Code = "a", Name = "a", NameVi = "a", Category = "grammar", CefrLevel = "A1" };
        var b = new Skill { Id = 2, Code = "b", Name = "b", NameVi = "b", Category = "grammar", CefrLevel = "A2" };
        var order = SkillGraph.TopologicalOrder([b, a], [new SkillEdge { PrerequisiteId = 1, SkillId = 2 }]);
        Assert.Equal(["a", "b"], order.Select(s => s.Code).ToArray());
    }
}
```

- [x] **Step 2: Run tests, verify they fail**

Run: `dotnet test QuestGraph.Tests --filter SkillTests`
Expected: FAIL — types/endpoints missing.

- [x] **Step 3: Implement entities, seed data, seeder, endpoints**

`QuestGraph/Domain/Skill.cs`:

```csharp
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
```

`QuestGraph/Domain/SkillGraph.cs` (Kahn's algorithm; throws on cycle):

```csharp
namespace QuestGraph.Domain;

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
```

`QuestGraph/Data/Seed/skills.json` — starter set of 35 skills (expanded to 150 by `expand_skills.py`, see Step 6). `prerequisites` entries are `[prerequisiteCode, skillCode]`:

```json
{
  "skills": [
    { "code": "grammar", "name": "Grammar", "name_vi": "Ngữ pháp", "category": "grammar", "cefr": "A1", "parent": null },
    { "code": "grammar.articles", "name": "Articles", "name_vi": "Mạo từ", "category": "grammar", "cefr": "A1", "parent": "grammar" },
    { "code": "grammar.prepositions", "name": "Prepositions", "name_vi": "Giới từ", "category": "grammar", "cefr": "A2", "parent": "grammar" },
    { "code": "grammar.modals", "name": "Modal Verbs", "name_vi": "Động từ khuyết thiếu", "category": "grammar", "cefr": "A2", "parent": "grammar" },
    { "code": "grammar.tenses", "name": "Tenses", "name_vi": "Các thì", "category": "grammar", "cefr": "A1", "parent": "grammar" },
    { "code": "grammar.tenses.present_simple", "name": "Present Simple", "name_vi": "Thì hiện tại đơn", "category": "grammar", "cefr": "A1", "parent": "grammar.tenses" },
    { "code": "grammar.tenses.present_continuous", "name": "Present Continuous", "name_vi": "Thì hiện tại tiếp diễn", "category": "grammar", "cefr": "A1", "parent": "grammar.tenses" },
    { "code": "grammar.tenses.past_simple", "name": "Past Simple", "name_vi": "Thì quá khứ đơn", "category": "grammar", "cefr": "A2", "parent": "grammar.tenses" },
    { "code": "grammar.tenses.future_forms", "name": "Future Forms", "name_vi": "Các dạng tương lai", "category": "grammar", "cefr": "A2", "parent": "grammar.tenses" },
    { "code": "grammar.tenses.present_perfect", "name": "Present Perfect", "name_vi": "Thì hiện tại hoàn thành", "category": "grammar", "cefr": "B1", "parent": "grammar.tenses" },
    { "code": "grammar.tenses.past_perfect", "name": "Past Perfect", "name_vi": "Thì quá khứ hoàn thành", "category": "grammar", "cefr": "B2", "parent": "grammar.tenses" },
    { "code": "grammar.conditionals", "name": "Conditionals", "name_vi": "Câu điều kiện", "category": "grammar", "cefr": "B1", "parent": "grammar" },
    { "code": "grammar.conditionals.first", "name": "First Conditional", "name_vi": "Câu điều kiện loại 1", "category": "grammar", "cefr": "B1", "parent": "grammar.conditionals" },
    { "code": "grammar.conditionals.second", "name": "Second Conditional", "name_vi": "Câu điều kiện loại 2", "category": "grammar", "cefr": "B1", "parent": "grammar.conditionals" },
    { "code": "grammar.conditionals.third", "name": "Third Conditional", "name_vi": "Câu điều kiện loại 3", "category": "grammar", "cefr": "B2", "parent": "grammar.conditionals" },
    { "code": "grammar.passive_voice", "name": "Passive Voice", "name_vi": "Câu bị động", "category": "grammar", "cefr": "B1", "parent": "grammar" },
    { "code": "grammar.reported_speech", "name": "Reported Speech", "name_vi": "Câu tường thuật", "category": "grammar", "cefr": "B2", "parent": "grammar" },
    { "code": "grammar.relative_clauses", "name": "Relative Clauses", "name_vi": "Mệnh đề quan hệ", "category": "grammar", "cefr": "B1", "parent": "grammar" },
    { "code": "vocabulary", "name": "Vocabulary", "name_vi": "Từ vựng", "category": "vocabulary", "cefr": "A1", "parent": null },
    { "code": "vocabulary.everyday", "name": "Everyday Vocabulary", "name_vi": "Từ vựng hằng ngày", "category": "vocabulary", "cefr": "A1", "parent": "vocabulary" },
    { "code": "vocabulary.travel", "name": "Travel Vocabulary", "name_vi": "Từ vựng du lịch", "category": "vocabulary", "cefr": "A2", "parent": "vocabulary" },
    { "code": "vocabulary.work_business", "name": "Work & Business", "name_vi": "Từ vựng công việc", "category": "vocabulary", "cefr": "B1", "parent": "vocabulary" },
    { "code": "vocabulary.phrasal_verbs", "name": "Phrasal Verbs", "name_vi": "Cụm động từ", "category": "vocabulary", "cefr": "B1", "parent": "vocabulary" },
    { "code": "vocabulary.collocations", "name": "Collocations", "name_vi": "Kết hợp từ", "category": "vocabulary", "cefr": "B2", "parent": "vocabulary" },
    { "code": "vocabulary.academic", "name": "Academic Vocabulary", "name_vi": "Từ vựng học thuật", "category": "vocabulary", "cefr": "B2", "parent": "vocabulary" },
    { "code": "vocabulary.idioms", "name": "Idioms", "name_vi": "Thành ngữ", "category": "vocabulary", "cefr": "C1", "parent": "vocabulary" },
    { "code": "reading", "name": "Reading", "name_vi": "Đọc hiểu", "category": "reading", "cefr": "A1", "parent": null },
    { "code": "reading.skimming", "name": "Skimming", "name_vi": "Đọc lướt", "category": "reading", "cefr": "A2", "parent": "reading" },
    { "code": "reading.main_idea", "name": "Main Idea", "name_vi": "Ý chính", "category": "reading", "cefr": "B1", "parent": "reading" },
    { "code": "reading.inference", "name": "Inference", "name_vi": "Suy luận", "category": "reading", "cefr": "B2", "parent": "reading" },
    { "code": "listening", "name": "Listening", "name_vi": "Nghe hiểu", "category": "listening", "cefr": "A1", "parent": null },
    { "code": "listening.basic_dialogues", "name": "Basic Dialogues", "name_vi": "Hội thoại cơ bản", "category": "listening", "cefr": "A1", "parent": "listening" },
    { "code": "listening.gist", "name": "Listening for Gist", "name_vi": "Nghe ý chính", "category": "listening", "cefr": "A2", "parent": "listening" },
    { "code": "listening.detail", "name": "Listening for Detail", "name_vi": "Nghe chi tiết", "category": "listening", "cefr": "B1", "parent": "listening" },
    { "code": "writing", "name": "Writing", "name_vi": "Viết", "category": "writing", "cefr": "A1", "parent": null },
    { "code": "writing.simple_sentences", "name": "Simple Sentences", "name_vi": "Câu đơn", "category": "writing", "cefr": "A1", "parent": "writing" },
    { "code": "writing.paragraphs", "name": "Paragraphs", "name_vi": "Đoạn văn", "category": "writing", "cefr": "A2", "parent": "writing" },
    { "code": "writing.emails", "name": "Emails", "name_vi": "Viết email", "category": "writing", "cefr": "B1", "parent": "writing" },
    { "code": "writing.essays", "name": "Essays", "name_vi": "Bài luận", "category": "writing", "cefr": "B2", "parent": "writing" }
  ],
  "prerequisites": [
    ["grammar.tenses.present_simple", "grammar.tenses.present_continuous"],
    ["grammar.tenses.present_simple", "grammar.tenses.past_simple"],
    ["grammar.tenses.present_simple", "grammar.tenses.future_forms"],
    ["grammar.tenses.past_simple", "grammar.tenses.present_perfect"],
    ["grammar.tenses.present_perfect", "grammar.tenses.past_perfect"],
    ["grammar.tenses.present_simple", "grammar.conditionals.first"],
    ["grammar.conditionals.first", "grammar.conditionals.second"],
    ["grammar.conditionals.second", "grammar.conditionals.third"],
    ["grammar.tenses.past_simple", "grammar.passive_voice"],
    ["grammar.tenses.past_simple", "grammar.reported_speech"],
    ["grammar.tenses.present_simple", "grammar.relative_clauses"],
    ["vocabulary.everyday", "vocabulary.travel"],
    ["vocabulary.everyday", "vocabulary.work_business"],
    ["vocabulary.work_business", "vocabulary.academic"],
    ["vocabulary.phrasal_verbs", "vocabulary.idioms"],
    ["reading.skimming", "reading.main_idea"],
    ["reading.main_idea", "reading.inference"],
    ["listening.basic_dialogues", "listening.gist"],
    ["listening.gist", "listening.detail"],
    ["writing.simple_sentences", "writing.paragraphs"],
    ["writing.paragraphs", "writing.emails"],
    ["writing.paragraphs", "writing.essays"]
  ]
}
```

Mark the file as copied to output in `QuestGraph.csproj`:

```xml
<ItemGroup>
  <!-- Update, not Include: the Web SDK already includes *.json as Content (NETSDK1022) -->
  <Content Update="Data\Seed\**" CopyToOutputDirectory="PreserveNewest" />
</ItemGroup>
```

`QuestGraph/Data/DbSeeder.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuestGraph.Domain;

namespace QuestGraph.Data;

public static class DbSeeder
{
    private record SkillSeed(string Code, string Name, string Name_vi, string Category, string Cefr, string? Parent);
    private record SeedFile(List<SkillSeed> Skills, List<string[]> Prerequisites);

    public static async Task SeedAsync(AppDbContext db)
    {
        if (await db.Skills.AnyAsync()) return; // idempotent

        var path = Path.Combine(AppContext.BaseDirectory, "Data", "Seed", "skills.json");
        var seed = JsonSerializer.Deserialize<SeedFile>(await File.ReadAllTextAsync(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

        var byCode = new Dictionary<string, Skill>();
        foreach (var s in seed.Skills)
        {
            var skill = new Skill { Code = s.Code, Name = s.Name, NameVi = s.Name_vi,
                Category = s.Category, CefrLevel = s.Cefr };
            byCode[s.Code] = skill;
            db.Skills.Add(skill);
        }
        await db.SaveChangesAsync();

        foreach (var s in seed.Skills.Where(s => s.Parent != null))
            byCode[s.Code].ParentId = byCode[s.Parent!].Id;
        foreach (var pair in seed.Prerequisites)
            db.SkillEdges.Add(new SkillEdge
                { PrerequisiteId = byCode[pair[0]].Id, SkillId = byCode[pair[1]].Id });
        await db.SaveChangesAsync();

        // fail fast on cycles
        SkillGraph.TopologicalOrder(await db.Skills.ToListAsync(), await db.SkillEdges.ToListAsync());
    }
}
```

In `AppDbContext` add:

```csharp
public DbSet<Skill> Skills => Set<Skill>();
public DbSet<SkillEdge> SkillEdges => Set<SkillEdge>();
```

and in `OnModelCreating`:

```csharp
mb.Entity<Skill>().HasIndex(s => s.Code).IsUnique();
mb.Entity<SkillEdge>().HasKey(e => new { e.PrerequisiteId, e.SkillId });
```

`QuestGraph/Endpoints/SkillEndpoints.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;

namespace QuestGraph.Endpoints;

public record SkillDto(int Id, string Code, string Name, string NameVi, string Category, int? ParentId, string CefrLevel);
public record EdgeDto(int From, int To);
public record SkillGraphDto(List<SkillDto> Nodes, List<EdgeDto> Edges);

public static class SkillEndpoints
{
    public static void MapSkills(this WebApplication app)
    {
        app.MapGet("/skills", async (AppDbContext db) =>
            await db.Skills.Select(s => new SkillDto(s.Id, s.Code, s.Name, s.NameVi, s.Category, s.ParentId, s.CefrLevel))
                .ToListAsync());

        app.MapGet("/skills/graph", async (AppDbContext db) => new SkillGraphDto(
            await db.Skills.Select(s => new SkillDto(s.Id, s.Code, s.Name, s.NameVi, s.Category, s.ParentId, s.CefrLevel)).ToListAsync(),
            await db.SkillEdges.Select(e => new EdgeDto(e.PrerequisiteId, e.SkillId)).ToListAsync()));
    }
}
```

In `Program.cs`: add `app.MapSkills();` and seed on startup (after `var app = builder.Build();`):

```csharp
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await DbSeeder.SeedAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>());
}
```

In `TestAppFactory`, after `EnsureCreated()`, add seeding so tests see the data:

```csharp
DbSeeder.SeedAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>()).GetAwaiter().GetResult();
```

(The Development-env seeding in Program.cs runs against SQLite too in tests; the `AnyAsync` guard keeps it idempotent.)

- [x] **Step 4: Run tests, verify they pass**

Run: `dotnet test QuestGraph.Tests`
Expected: PASS.

- [x] **Step 5: Migration + commit**

```powershell
dotnet ef migrations add AddSkills --project QuestGraph
dotnet ef database update --project QuestGraph
git add -A
git commit -m "feat: micro-skill knowledge graph with seed and endpoints"
```

- [x] **Step 6: Expansion script to 150 skills (run once, review output)**

> Executed 2026-07-09 with `gemini-2.5-flash` via the OpenAI-compatible endpoint
> (`OPENAI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/`,
> key in user env `GEMINI_API_KEY`; the OpenAI key has no quota, and
> `gemini-2.5-pro` is not on the free tier). Result: 174 skills / 144 edges,
> validated acyclic, 5 `name_vi` entries hand-fixed. Script accepts
> `EXPAND_MODEL` env override.

`ml/research/expand_skills.py` — asks the LLM (gemini-2.5-flash) to extend `skills.json` to 150 micro-skills, preserving existing entries and the JSON shape. Requires task-5's `ml/.venv` (or `pip install openai`).

```python
"""Expand skills.json to ~150 micro-skills using gemini-2.5-flash. Review the diff by hand."""
import json, sys
from pathlib import Path
from openai import OpenAI

SEED = Path(__file__).parents[2] / "QuestGraph/Data/Seed/skills.json"

PROMPT = """You are designing a knowledge graph for Vietnamese learners of English.
Below is an existing skills.json with 'skills' and 'prerequisites'.
Extend it to ~150 micro-skills total. Rules:
- Keep every existing entry unchanged.
- Same JSON shape. code = dot-separated lowercase path; name_vi = Vietnamese name.
- Each new leaf skill: category in [grammar,vocabulary,reading,listening,writing],
  cefr in [A1..C2], parent must exist, prerequisites must not create cycles.
- Cover: all tenses, gerunds/infinitives, comparatives, question forms, quantifiers,
  vocabulary topic sets per CEFR level, listening sub-skills, reading strategies,
  writing genres (reports, reviews, stories), punctuation, linking words.
Return ONLY the complete JSON document.
{json}"""

def main():
    data = SEED.read_text(encoding="utf-8")
    client = OpenAI()
    resp = client.chat.completions.create(
        model=os.environ.get("EXPAND_MODEL", "gemini-2.5-flash"), temperature=0.3,
        response_format={"type": "json_object"},
        messages=[{"role": "user", "content": PROMPT.format(json=data)}])
    expanded = json.loads(resp.choices[0].message.content)
    old = json.loads(data)
    old_codes = {s["code"] for s in old["skills"]}
    new_codes = {s["code"] for s in expanded["skills"]}
    assert old_codes <= new_codes, f"dropped skills: {old_codes - new_codes}"
    assert len(new_codes) >= 140, f"only {len(new_codes)} skills generated"
    SEED.write_text(json.dumps(expanded, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"skills: {len(old_codes)} -> {len(new_codes)}")

if __name__ == "__main__":
    sys.exit(main())
```

Run: `python ml/research/expand_skills.py`, then **manually review** the diff (spot-check Vietnamese names, prerequisite sanity), re-run `dotnet test` (seeder's cycle check validates the expanded graph — drop the seeded DB first: `docker compose down -v; docker compose up -d db; dotnet ef database update --project QuestGraph`), and commit:

```powershell
git add QuestGraph/Data/Seed/skills.json ml/research/expand_skills.py
git commit -m "feat: expand knowledge graph to 150 micro-skills"
```
