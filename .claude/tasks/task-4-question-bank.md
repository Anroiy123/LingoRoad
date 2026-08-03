# Task 4: Question Bank — schema, generation pipeline, import

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-3. Also bootstraps the `ml/` Python environment (task-5 extends it).

**Files:**
- Create: `QuestGraph/Domain/Item.cs`, `QuestGraph/Endpoints/ItemEndpoints.cs`, `QuestGraph.Tests/ItemTests.cs`, `ml/requirements.txt`, `ml/questgraph_ml/__init__.py`, `ml/questgraph_ml/itemgen.py`, `ml/tests/test_itemgen.py`, `ml/research/build_item_bank.py`, `QuestGraph/wwwroot/audio/.gitkeep`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`

**Interfaces:**
- Consumes: `Skill` entity, `AppDbContext`, `TestAppFactory`.
- Produces: `Item { Guid Id, int SkillId, string CefrLevel, string Type, string Stem, string OptionsJson, string CorrectAnswer, double A, double B, double C, string? AudioUrl, string Source }` (Type ∈ `mcq|cloze|listening_mcq`); `POST /admin/items/import` (Development only) taking `List<ItemImportDto>`; `GET /items?skill=&cefr=`; Python `seed_irt_params(cefr, n_options, rng) -> (a, b, c)` reused by task-7's simulation; `ml/` venv with `requirements.txt`.

- [x] **Step 1: Bootstrap Python env**

```powershell
python -m venv ml/.venv   # already existed (created during task-3 step 6)
ml/.venv/Scripts/pip install -U pip
```

`ml/requirements.txt` (task-5/8/9 append to this; edge-tts added for free listening audio — see Step 7 note):

```
numpy>=1.26
scipy>=1.12
pytest>=8.0
openai>=1.30
httpx>=0.27
edge-tts>=6.1
```

```powershell
ml/.venv/Scripts/pip install -r ml/requirements.txt
```

Create empty `ml/questgraph_ml/__init__.py` and `ml/tests/__init__.py`.

- [x] **Step 2: Write failing Python test for IRT parameter seeding**

`ml/tests/test_itemgen.py`:

```python
import numpy as np
from questgraph_ml.itemgen import seed_irt_params, CEFR_B

def test_params_within_bounds():
    rng = np.random.default_rng(42)
    for cefr in ["A1", "A2", "B1", "B2", "C1", "C2"]:
        a, b, c = seed_irt_params(cefr, n_options=4, rng=rng)
        assert 0.6 <= a <= 2.0
        assert abs(b - CEFR_B[cefr]) <= 0.4
        assert c == 0.25

def test_difficulty_increases_with_level():
    assert CEFR_B["A1"] < CEFR_B["A2"] < CEFR_B["B1"] < CEFR_B["B2"] < CEFR_B["C1"] < CEFR_B["C2"]

def test_deterministic_with_seed():
    p1 = seed_irt_params("B1", 4, np.random.default_rng(7))
    p2 = seed_irt_params("B1", 4, np.random.default_rng(7))
    assert p1 == p2
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_itemgen.py -v`
Expected: FAIL — module missing.

- [x] **Step 3: Implement `itemgen.py`, verify pytest passes**

`ml/questgraph_ml/itemgen.py`:

```python
"""Heuristic IRT parameter seeding (true calibration needs response data - see requirement.md V-2)."""
import numpy as np

CEFR_B = {"A1": -2.0, "A2": -1.2, "B1": -0.4, "B2": 0.5, "C1": 1.4, "C2": 2.2}

def seed_irt_params(cefr: str, n_options: int, rng: np.random.Generator) -> tuple[float, float, float]:
    a = float(np.clip(rng.lognormal(mean=0.0, sigma=0.25), 0.6, 2.0))
    b = float(CEFR_B[cefr] + rng.uniform(-0.4, 0.4))
    c = round(1.0 / n_options, 4)
    return a, b, c
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [x] **Step 4: Write failing .NET tests for item import + listing**

`QuestGraph.Tests/ItemTests.cs`:

```csharp
using System.Net.Http.Json;
using QuestGraph.Endpoints;

namespace QuestGraph.Tests;

public class ItemTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public ItemTests(TestAppFactory f) => _client = f.CreateClient();

    private static object SampleItem(string skillCode = "grammar.tenses.present_perfect") => new
    {
        skillCode,
        cefrLevel = "B1",
        type = "mcq",
        stem = "She ___ in Hanoi since 2019.",
        options = new[] { "has lived", "lived", "lives", "is living" },
        correctAnswer = "has lived",
        source = "test"
    };

    [Fact]
    public async Task Import_then_list_filters_by_skill_and_cefr()
    {
        var res = await _client.PostAsJsonAsync("/admin/items/import", new[] { SampleItem() });
        res.EnsureSuccessStatusCode();

        var items = await _client.GetFromJsonAsync<List<ItemDto>>(
            "/items?skill=grammar.tenses.present_perfect&cefr=B1");
        Assert.Single(items!);
        Assert.Equal("has lived", items![0].CorrectAnswer);
        Assert.True(items[0].A >= 0.6 && items[0].A <= 2.0); // params were seeded server-side? no: import provides them or defaults
    }

    [Fact]
    public async Task Import_with_unknown_skill_returns_400()
    {
        var res = await _client.PostAsJsonAsync("/admin/items/import",
            new[] { SampleItem(skillCode: "nope.nope") });
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, res.StatusCode);
    }
}
```

Note: the import DTO carries optional `a,b,c` (the Python pipeline seeds them); when absent the endpoint applies the same defaults (a=1.0, b from CEFR map, c=1/options).

Run: `dotnet test QuestGraph.Tests --filter ItemTests` → FAIL (404).

- [x] **Step 5: Implement entity + endpoints**

`QuestGraph/Domain/Item.cs`:

```csharp
namespace QuestGraph.Domain;

public class Item
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public required string Type { get; set; }          // mcq | cloze | listening_mcq
    public required string Stem { get; set; }
    public required string OptionsJson { get; set; }   // JSON string[] (empty array for cloze)
    public required string CorrectAnswer { get; set; }
    public double A { get; set; }
    public double B { get; set; }
    public double C { get; set; }
    public string? AudioUrl { get; set; }
    public required string Source { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

`AppDbContext`: add `public DbSet<Item> Items => Set<Item>();` and in `OnModelCreating`:
`mb.Entity<Item>().HasIndex(i => new { i.SkillId, i.CefrLevel });`

`QuestGraph/Endpoints/ItemEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;

namespace QuestGraph.Endpoints;

public record ItemImportDto(string SkillCode, string CefrLevel, string Type, string Stem,
    string[] Options, string CorrectAnswer, string Source,
    double? A = null, double? B = null, double? C = null, string? AudioUrl = null);
public record ItemDto(Guid Id, string SkillCode, string CefrLevel, string Type, string Stem,
    string[] Options, string CorrectAnswer, double A, double B, double C, string? AudioUrl);

public static class ItemEndpoints
{
    private static readonly Dictionary<string, double> CefrB = new()
        { ["A1"] = -2.0, ["A2"] = -1.2, ["B1"] = -0.4, ["B2"] = 0.5, ["C1"] = 1.4, ["C2"] = 2.2 };

    public static void MapItems(this WebApplication app)
    {
        app.MapGet("/items", async (string? skill, string? cefr, AppDbContext db) =>
        {
            var q = db.Items.Join(db.Skills, i => i.SkillId, s => s.Id, (i, s) => new { i, s.Code });
            if (skill != null) q = q.Where(x => x.Code == skill);
            if (cefr != null) q = q.Where(x => x.i.CefrLevel == cefr);
            return (await q.ToListAsync()).Select(x => new ItemDto(
                x.i.Id, x.Code, x.i.CefrLevel, x.i.Type, x.i.Stem,
                JsonSerializer.Deserialize<string[]>(x.i.OptionsJson)!,
                x.i.CorrectAnswer, x.i.A, x.i.B, x.i.C, x.i.AudioUrl));
        });

        if (!app.Environment.IsDevelopment()) return;

        app.MapPost("/admin/items/import", async (List<ItemImportDto> dtos, AppDbContext db) =>
        {
            var skills = await db.Skills.ToDictionaryAsync(s => s.Code, s => s.Id);
            var items = new List<Item>();
            foreach (var d in dtos)
            {
                if (!skills.TryGetValue(d.SkillCode, out var skillId))
                    return Results.BadRequest(new { error = "unknown_skill", skill = d.SkillCode });
                items.Add(new Item
                {
                    SkillId = skillId, CefrLevel = d.CefrLevel, Type = d.Type, Stem = d.Stem,
                    OptionsJson = JsonSerializer.Serialize(d.Options),
                    CorrectAnswer = d.CorrectAnswer, Source = d.Source, AudioUrl = d.AudioUrl,
                    A = d.A ?? 1.0,
                    B = d.B ?? CefrB[d.CefrLevel],
                    C = d.C ?? (d.Options.Length > 0 ? Math.Round(1.0 / d.Options.Length, 4) : 0.0)
                });
            }
            db.Items.AddRange(items);
            await db.SaveChangesAsync();
            return Results.Ok(new { imported = items.Count });
        });
    }
}
```

`Program.cs`: add `app.UseStaticFiles();` (before endpoints; serves `wwwroot/audio/`) and `app.MapItems();`. Create `QuestGraph/wwwroot/audio/.gitkeep`.

- [x] **Step 6: Run tests, verify pass; migration; commit**

```powershell
dotnet test QuestGraph.Tests
dotnet ef migrations add AddItems --project QuestGraph
dotnet ef database update --project QuestGraph
git add -A
git commit -m "feat: question bank schema, import endpoint, IRT param seeding"
```

- [x] **Step 7: Write the generation pipeline**

`ml/research/build_item_bank.py` — generates ~600 items across leaf skills, seeds IRT params, synthesizes listening audio, writes `ml/data/items.json`, and POSTs to the import endpoint.

> **Executed 2026-07-09 with deviations** (OpenAI account has no quota — see memory note `llm-api-keys-quota`):
> - Provider-agnostic LLM client: `OPENAI_BASE_URL` + `GEN_MODEL` env vars (run used Gemini
>   `gemini-2.5-flash` via the OpenAI-compat endpoint).
> - TTS: `tts-1` needs OpenAI quota and Gemini's compat endpoint has no audio API, so default is
>   **edge-tts** (free Microsoft neural TTS, mp3, no key); `TTS_PROVIDER=openai` restores tts-1.
> - Free-tier hardening: `--sleep` pacing (10 RPM cap), 429 retry with backoff, per-skill error
>   tolerance, and **item validation** — first smoke run showed Gemini returning mcq items with
>   empty `options`; `valid_item()` drops malformed items and the prompt now demands exactly
>   4 non-empty options for mcq/listening_mcq.
>
> The authoritative script is the file itself; key differences from the original plan listing are
> the docstring/env handling, `valid_item()`, `generate_with_retry()`, `synth_speech()`, and
> `source` set to the actual model name instead of hard-coded `"gpt4o"`.

- [x] **Step 8: Smoke-run the pipeline, then full run** — **COMPLETE (2026-07-10): 617 items / all 156 skills imported** (353 mcq, 188 cloze, 48 listening_mcq + mp3s), generated on the billed-tier Gemini key. Note: `gemini-2.5-flash` intermittently 404'd ("no longer available" — rolling deprecation?); `GEN_MODEL=gemini-flash-latest` worked as a fallback for the last skill. Historical partial-run note below.

> Smoke run passed (after adding item validation — first attempt surfaced empty-options mcq items).
> Full run hit Gemini free-tier daily caps: **20 requests/day per model** (`flash` and `flash-lite`
> both). Result: **82 valid items across 22 skills imported** (54 mcq, 28 cloze, 0 listening yet).
> User decided current bank is enough for now; will enable billing later.
>
> **To finish the bank later:** `--resume` regenerates only missing skills. Because the import
> endpoint is not idempotent, clear the Items table before the final full import:
> `docker exec questgraph-db-1 psql -U questgraph -c 'TRUNCATE "Items";'` then re-run with
> `--resume --post http://localhost:5000` (drop `--sleep` once on a paid tier).

(No `PYTHONPATH` needed — the script bootstraps `sys.path` itself.)

```powershell
$env:OPENAI_API_KEY = [Environment]::GetEnvironmentVariable("GEMINI_API_KEY", "User")
$env:OPENAI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/"
$env:GEN_MODEL = "gemini-2.5-flash"
ml/.venv/Scripts/python ml/research/build_item_bank.py --per-skill 2 --limit 3
```

Expected: `ml/data/items.json` with 6 valid items. Spot-check content quality by reading 3 items.

Full run (156 leaf skills after task-3 expansion; with API running via `dotnet run --project QuestGraph`; `--sleep 7` keeps under the Gemini free-tier 10 RPM cap, ~40 min):

```powershell
ml/.venv/Scripts/python ml/research/build_item_bank.py --per-skill 4 --sleep 7 --post http://localhost:5000
```

Expected: ≥ 500 items imported (`GET /items` returns them). 500 is the target, 300 the floor. Listening items have mp3 files in `wwwroot/audio/`.

- [x] **Step 9: Commit**

```powershell
git add ml/ QuestGraph/wwwroot/audio
git commit -m "feat: question bank generation pipeline (Gemini + edge-tts + IRT seeding)"
```
