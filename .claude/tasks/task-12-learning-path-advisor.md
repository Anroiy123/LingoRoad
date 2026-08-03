# Task 12: Learning Path & LLM Advisor â€” rule-based path + Vietnamese RAG advisor

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-3, task-10. Sprint 3.

**Files:**
- Create: `QuestGraph/Domain/PathBuilder.cs`, `QuestGraph/Endpoints/PathEndpoints.cs`, `QuestGraph.Tests/PathTests.cs`, `ml/questgraph_ml/llm/__init__.py`, `ml/questgraph_ml/llm/rag.py`, `ml/questgraph_ml/llm/advisor.py`, `ml/questgraph_ml/serving/llm_routes.py`, `ml/tests/test_rag.py`, `ml/tests/test_llm_api.py`, `ml/research/build_rag_index.py`, `ml/data/corpus/present_perfect.md` (sample; add 8â€“12 more by hand)
- Modify: `QuestGraph/Services/MlClient.cs`, `QuestGraph/Program.cs`, `ml/questgraph_ml/serving/app.py`, `QuestGraph.Tests/PlacementTests.cs` (FakeMlClient grows)

**Interfaces:**
- Consumes: `SkillGraph.TopologicalOrder`, `Mastery`, `CefrMap`, `IMlClient`.
- Produces:
  - C#: `CefrMap.Rank(string cefr) : int` (A1=0..C2=5); `PathBuilder.Build(skills, edges, mastery: Dictionary<int,double>, goalCefr, limit=10) : List<PathStep>` with `record PathStep(Skill Skill, double Mastery, string Reason)` (Reason âˆˆ `not_started|below_threshold`); `GET /path?limit=10`; `POST /path/advisor` body `{ question }` â†’ `{ answer }` (Vietnamese).
  - `IMlClient` gains `Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)`; `record AdvisorSkillContext(string Code, string Name, double Mastery, string Reason)`, `record AdvisorRequest(string Question, List<AdvisorSkillContext> Path, string Locale)`, `record AdvisorResponse(string Answer)`.
  - Python: `POST /llm/advisor` `{"question":â€¦, "path":[{"code":â€¦,"name":â€¦,"mastery":0.4,"reason":â€¦}], "locale":"vi"}` â†’ `{"answer":â€¦}`; `rag.build_index(corpus_dir, out_path, embed_fn)`, `rag.retrieve(query, index_path, embed_fn, k=3) -> list[str]`.
  - **Mastery threshold 0.8** â€” a skill is "done" at â‰¥ 0.8 (used here and in the report narrative).

- [x] **Step 1: Write failing PathBuilder tests**

`QuestGraph.Tests/PathTests.cs`:

```csharp
using QuestGraph.Domain;

namespace QuestGraph.Tests;

public class PathBuilderTests
{
    private static Skill S(int id, string code, string cefr, int? parent = null) => new()
        { Id = id, Code = code, Name = code, NameVi = code, Category = "grammar",
          CefrLevel = cefr, ParentId = parent };

    private static readonly List<Skill> Skills =
    [
        S(1, "tenses", "A1"),                       // parent container
        S(2, "present_simple", "A1", 1),
        S(3, "past_simple", "A2", 1),
        S(4, "present_perfect", "B1", 1),
        S(5, "past_perfect", "B2", 1),
        S(6, "idioms", "C1", 1),
    ];
    private static readonly List<SkillEdge> Edges =
    [
        new() { PrerequisiteId = 2, SkillId = 3 },
        new() { PrerequisiteId = 3, SkillId = 4 },
        new() { PrerequisiteId = 4, SkillId = 5 },
    ];

    [Fact]
    public void Prerequisites_come_before_dependents()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "B2");
        var codes = path.Select(p => p.Skill.Code).ToList();
        Assert.True(codes.IndexOf("past_simple") < codes.IndexOf("present_perfect"));
        Assert.True(codes.IndexOf("present_perfect") < codes.IndexOf("past_perfect"));
    }

    [Fact]
    public void Mastered_skills_are_skipped()
    {
        var mastery = new Dictionary<int, double> { [2] = 0.9, [3] = 0.85 };
        var path = PathBuilder.Build(Skills, Edges, mastery, "B2");
        Assert.DoesNotContain(path, p => p.Skill.Code == "present_simple");
        Assert.Equal("present_perfect", path[0].Skill.Code);
    }

    [Fact]
    public void Skills_above_goal_cefr_are_excluded()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "B1");
        Assert.DoesNotContain(path, p => p.Skill.Code == "past_perfect");
        Assert.DoesNotContain(path, p => p.Skill.Code == "idioms");
    }

    [Fact]
    public void Parent_container_skills_are_excluded()
    {
        var path = PathBuilder.Build(Skills, Edges, new(), "C2");
        Assert.DoesNotContain(path, p => p.Skill.Code == "tenses");
    }

    [Fact]
    public void Reason_distinguishes_new_from_partial()
    {
        var mastery = new Dictionary<int, double> { [2] = 0.4 };
        var path = PathBuilder.Build(Skills, Edges, mastery, "A2");
        Assert.Equal("below_threshold", path.Single(p => p.Skill.Code == "present_simple").Reason);
        Assert.Equal("not_started", path.Single(p => p.Skill.Code == "past_simple").Reason);
    }
}
```

Run: `dotnet test QuestGraph.Tests --filter PathBuilderTests` â†’ FAIL.

- [x] **Step 2: Implement PathBuilder + endpoints, verify pass**

Add to `QuestGraph/Domain/CefrMap.cs`:

```csharp
public static int Rank(string cefr) =>
    Array.IndexOf(["A1", "A2", "B1", "B2", "C1", "C2"], cefr);
```

`QuestGraph/Domain/PathBuilder.cs`:

```csharp
namespace QuestGraph.Domain;

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
```

`QuestGraph/Endpoints/PathEndpoints.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

public record AdvisorQuestion(string Question);

public static class PathEndpoints
{
    private static async Task<List<PathStep>> BuildForUserAsync(
        AppDbContext db, Guid userId, int limit)
    {
        var user = await db.Users.FindAsync(userId);
        var mastery = await db.Masteries.Where(m => m.UserId == userId)
            .ToDictionaryAsync(m => m.SkillId, m => m.PCorrect);
        return PathBuilder.Build(await db.Skills.ToListAsync(),
            await db.SkillEdges.ToListAsync(), mastery, user!.TargetCefr, limit);
    }

    public static void MapPath(this WebApplication app)
    {
        var g = app.MapGroup("/path").RequireAuthorization();

        g.MapGet("", async (int? limit,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            (await BuildForUserAsync(db, user.UserId(), limit ?? 10))
            .Select(p => new { code = p.Skill.Code, name = p.Skill.Name,
                nameVi = p.Skill.NameVi, cefr = p.Skill.CefrLevel,
                mastery = p.Mastery, reason = p.Reason }));

        g.MapPost("/advisor", async (AdvisorQuestion req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml) =>
        {
            var path = await BuildForUserAsync(db, user.UserId(), 10);
            try
            {
                var res = await ml.AdvisorAsync(new AdvisorRequest(req.Question,
                    path.Select(p => new AdvisorSkillContext(
                        p.Skill.Code, p.Skill.Name, p.Mastery, p.Reason)).ToList(), "vi"));
                return Results.Ok(new { answer = res.Answer });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });
    }
}
```

Add to `MlClient.cs` (interface + implementation + records from the Interfaces block above; the implementation is one line):

```csharp
public async Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)
    => await PostAsync<AdvisorRequest, AdvisorResponse>("/llm/advisor", req, ct);
```

Update `FakeMlClient` in `PlacementTests.cs`:

```csharp
public Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)
    => Task.FromResult(new AdvisorResponse("Báº¡n nÃªn há»c ká»¹ nÄƒng nÃ y vÃ¬ nÃ³ lÃ  ná»n táº£ng."));
```

`Program.cs`: `app.MapPath();`

Also append this endpoint test to `PathTests.cs`:

```csharp
using System.Net.Http.Json;

public class PathEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public PathEndpointTests(TestAppFactory f) => _client = f.CreateClient();

    private record PathRow(string Code, string Name, string NameVi, string Cefr,
        double Mastery, string Reason);

    [Fact]
    public async Task Path_returns_seeded_skills_as_not_started()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "P" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var path = await _client.GetFromJsonAsync<List<PathRow>>("/path?limit=5");
        Assert.Equal(5, path!.Count);
        Assert.All(path, p => Assert.Equal("not_started", p.Reason));
    }
}
```

Run: `dotnet test QuestGraph.Tests` â†’ PASS (all suites).

- [x] **Step 3: Write failing RAG tests (no LLM API calls â€” fake embedder)**

`ml/tests/test_rag.py`:

```python
import numpy as np
from pathlib import Path
from questgraph_ml.llm.rag import build_index, retrieve

def fake_embed(texts: list[str]) -> np.ndarray:
    """Deterministic embedding: 8-dim char histogram."""
    out = np.zeros((len(texts), 8), dtype=np.float32)
    for i, t in enumerate(texts):
        for ch in t.lower():
            out[i, ord(ch) % 8] += 1
    norms = np.linalg.norm(out, axis=1, keepdims=True)
    return out / np.maximum(norms, 1e-9)

def test_build_and_retrieve_roundtrip(tmp_path: Path):
    corpus = tmp_path / "corpus"; corpus.mkdir()
    (corpus / "perfect.md").write_text("present perfect connects past and present",
                                       encoding="utf-8")
    (corpus / "passive.md").write_text("zzz qqq xxx vvv www yyy", encoding="utf-8")
    index = tmp_path / "index.npz"
    build_index(corpus, index, embed_fn=fake_embed)
    hits = retrieve("present perfect usage", index, embed_fn=fake_embed, k=1)
    assert len(hits) == 1
    assert "present perfect" in hits[0]
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_rag.py -v` â†’ FAIL.

- [x] **Step 4: Implement RAG + advisor, verify pass**

`ml/questgraph_ml/llm/rag.py`:

```python
"""Tiny numpy vector store (corpus is small; FAISS unnecessary â€” noted in brainstorm doc)."""
import json
from pathlib import Path
import numpy as np

def _chunks(corpus_dir: Path, size: int = 800):
    for f in sorted(Path(corpus_dir).glob("*.md")):
        text = f.read_text(encoding="utf-8")
        for i in range(0, len(text), size):
            yield text[i: i + size]

def build_index(corpus_dir: Path, out_path: Path, embed_fn):
    chunks = list(_chunks(corpus_dir))
    vecs = embed_fn(chunks)
    np.savez(out_path, vecs=vecs)
    Path(str(out_path) + ".chunks.json").write_text(
        json.dumps(chunks, ensure_ascii=False), encoding="utf-8")

def retrieve(query: str, index_path: Path, embed_fn, k: int = 3) -> list[str]:
    vecs = np.load(index_path)["vecs"]
    chunks = json.loads(Path(str(index_path) + ".chunks.json").read_text(encoding="utf-8"))
    qv = embed_fn([query])[0]
    sims = vecs @ qv / (np.linalg.norm(vecs, axis=1) * np.linalg.norm(qv) + 1e-9)
    return [chunks[i] for i in np.argsort(-sims)[:k]]

def gemini_embed(texts: list[str]) -> np.ndarray:
    import os
    from openai import OpenAI
    client = OpenAI(api_key=os.environ["GEMINI_API_KEY"],
                    base_url="https://generativelanguage.googleapis.com/v1beta/openai/")
    resp = client.embeddings.create(model="gemini-embedding-001", input=texts)
    return np.array([d.embedding for d in resp.data], dtype=np.float32)
```

`ml/questgraph_ml/llm/advisor.py`:

```python
SYSTEM = """Báº¡n lÃ  cá»‘ váº¥n há»c tiáº¿ng Anh cho ngÆ°á»i Viá»‡t. Tráº£ lá»i NGáº®N Gá»ŒN báº±ng tiáº¿ng Viá»‡t.
Dá»±a vÃ o lá»™ trÃ¬nh há»c vÃ  má»©c thÃ nh tháº¡o hiá»‡n táº¡i cá»§a há»c viÃªn (0-1) vÃ  tÃ i liá»‡u tham kháº£o."""

def build_messages(question: str, path: list[dict], context_chunks: list[str]) -> list[dict]:
    path_txt = "\n".join(f"- {p['name']} ({p['code']}): mastery {p['mastery']:.2f}, {p['reason']}"
                         for p in path)
    ctx = "\n---\n".join(context_chunks)
    return [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content":
            f"Lá»™ trÃ¬nh hiá»‡n táº¡i:\n{path_txt}\n\nTÃ i liá»‡u:\n{ctx}\n\nCÃ¢u há»i: {question}"},
    ]

def answer(question: str, path: list[dict], retrieve_fn, client) -> str:
    chunks = retrieve_fn(question)
    resp = client.chat.completions.create(
        model="gemini-2.5-flash", temperature=0.4,
        messages=build_messages(question, path, chunks))
    return resp.choices[0].message.content
```

`ml/questgraph_ml/serving/llm_routes.py`:

```python
import os
from functools import lru_cache
from pathlib import Path
from fastapi import APIRouter
from pydantic import BaseModel
from questgraph_ml.llm import advisor, rag

router = APIRouter()
INDEX = Path(os.environ.get("QG_RAG_INDEX", "data/corpus_index.npz"))

@lru_cache
def _client():
    from openai import OpenAI
    return OpenAI(api_key=os.environ["GEMINI_API_KEY"],
                  base_url="https://generativelanguage.googleapis.com/v1beta/openai/")

class PathEntry(BaseModel):
    code: str; name: str; mastery: float; reason: str

class AdvisorReq(BaseModel):
    question: str
    path: list[PathEntry]
    locale: str = "vi"

@router.post("/llm/advisor")
def llm_advisor(req: AdvisorReq):
    def retrieve_fn(q):
        if not INDEX.exists():
            return []
        return rag.retrieve(q, INDEX, embed_fn=rag.gemini_embed, k=3)
    text = advisor.answer(req.question, [p.model_dump() for p in req.path],
                          retrieve_fn, _client())
    return {"answer": text}
```

In `serving/app.py`: `from questgraph_ml.serving.llm_routes import router as llm_router` + `app.include_router(llm_router)`.

`ml/tests/test_llm_api.py` (prompt-shape test, no API call):

```python
from questgraph_ml.llm.advisor import build_messages

def test_messages_include_path_and_context_in_vietnamese_frame():
    msgs = build_messages("Táº¡i sao há»c present perfect?",
                          [{"code": "pp", "name": "Present Perfect",
                            "mastery": 0.35, "reason": "below_threshold"}],
                          ["Present perfect connects past and present."])
    assert msgs[0]["role"] == "system" and "tiáº¿ng Viá»‡t" in msgs[0]["content"]
    body = msgs[1]["content"]
    assert "Present Perfect" in body and "0.35" in body and "connects past" in body
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` â†’ PASS.

- [ ] **Step 5: Build the corpus + index (manual content step)**

Create `ml/data/corpus/present_perfect.md` (sample below) and 8â€“12 more short guides (one per major grammar topic; generate drafts with gemini-2.5-flash and review them yourself â€” they are report artifacts):

```markdown
# Present Perfect (ThÃ¬ hiá»‡n táº¡i hoÃ n thÃ nh)

Form: have/has + past participle. Use for: experiences (I have visited Hue),
unfinished time (She has lived in Hanoi since 2019), recent results (I have lost my key).
Common Vietnamese-learner error: using past simple with "since/for"
(âŒ "I lived here since 2019" â†’ âœ… "I have lived here since 2019").
Signal words: since, for, already, yet, just, ever, never.
```

`ml/research/build_rag_index.py`:

```python
from pathlib import Path
from questgraph_ml.llm.rag import build_index, gemini_embed

ROOT = Path(__file__).parents[1]
build_index(ROOT / "data/corpus", ROOT / "data/corpus_index.npz", embed_fn=gemini_embed)
print("index built")
```

Run it, then start both services and manually POST `/path/advisor` with `{"question":"Táº¡i sao tÃ´i nÃªn há»c thÃ¬ hiá»‡n táº¡i hoÃ n thÃ nh tiáº¿p theo?"}` â€” expect a coherent Vietnamese answer citing the learner's mastery. Save one good response to `ml/reports/samples/advisor.md` (report artifact).

- [x] **Step 6: Commit**

```powershell
git add -A
git commit -m "feat: rule-based learning path and Vietnamese RAG advisor"
```
