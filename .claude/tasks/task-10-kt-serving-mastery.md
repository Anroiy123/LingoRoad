# Task 10: KT Serving & Mastery — `/kt/predict` + per-skill mastery in .NET

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-6, task-9. Sprint 2.

**Design note (spec bridge):** the SAINT+ checkpoint speaks EdNet's question vocabulary, so it cannot score QuestGraph's own items directly (cross-domain vocabulary gap — document this in the report). Therefore: (a) the ML service serves the real SAINT+ at `POST /kt/predict` for EdNet-format sequences — live inference demo + report evidence; (b) product mastery per micro-skill is a pure, unit-tested estimator in C# (exponential moving average + Ebbinghaus-style decay toward 0.5), updated on every answered item, with SAINT+ retraining on QuestGraph's own accumulated responses listed as future work.

**Files:**
- Create: `QuestGraph/Domain/Mastery.cs`, `QuestGraph/Domain/MasteryCalc.cs`, `QuestGraph/Services/MasteryService.cs`, `QuestGraph/Endpoints/MasteryEndpoints.cs`, `QuestGraph.Tests/MasteryTests.cs`, `ml/questgraph_ml/serving/kt_routes.py`, `ml/tests/test_kt_api.py`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Endpoints/PlacementEndpoints.cs`, `QuestGraph/Program.cs`, `ml/questgraph_ml/serving/app.py`

**Interfaces:**
- Consumes: `saint_plus.pt` checkpoint (task-9), placement answer flow (task-6).
- Produces:
  - C#: `Mastery { Guid UserId, int SkillId, double PCorrect, DateTime UpdatedAt }` (composite PK); `MasteryCalc.Update(double prior, bool correct, double daysSinceLast) : double`; `MasteryService.RecordAnswerAsync(Guid userId, int skillId, bool correct)` — **task-13 calls this on exercise submissions**; `GET /mastery` → `[{ skillCode, skillName, pCorrect, updatedAt }]`.
  - Python: `POST /kt/predict` body `{"sequence":[{"q_idx":1,"part":1,"correct":1,"elapsed":0.2,"lag":0.1}]}` → `{"p_next":[0.61,...]}`; checkpoint path from env `QG_KT_CHECKPOINT` (default `ml/checkpoints/saint_plus.pt`); 503 `{"error":"model_not_loaded"}` if missing.

- [x] **Step 1: Write failing C# tests**

`QuestGraph.Tests/MasteryTests.cs`:

```csharp
using QuestGraph.Domain;

namespace QuestGraph.Tests;

public class MasteryCalcTests
{
    [Fact]
    public void Correct_answer_raises_estimate()
        => Assert.True(MasteryCalc.Update(0.5, true, 0) > 0.5);

    [Fact]
    public void Wrong_answer_lowers_estimate()
        => Assert.True(MasteryCalc.Update(0.5, false, 0) < 0.5);

    [Fact]
    public void Long_gap_decays_high_mastery_toward_baseline()
    {
        var fresh = MasteryCalc.Update(0.9, true, 0);
        var stale = MasteryCalc.Update(0.9, true, 60);
        Assert.True(stale < fresh);
    }

    [Fact]
    public void Estimate_stays_in_unit_interval()
    {
        var m = 0.5;
        for (var i = 0; i < 50; i++) m = MasteryCalc.Update(m, true, 0);
        Assert.InRange(m, 0.0, 1.0);
        for (var i = 0; i < 50; i++) m = MasteryCalc.Update(m, false, 0);
        Assert.InRange(m, 0.0, 1.0);
    }
}
```

Integration test in the same file (placement answers update mastery; reuses `PlacementFactory` from task-6):

```csharp
public class MasteryEndpointTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public MasteryEndpointTests(PlacementFactory f) => _client = f.CreateClient();

    private record MasteryRow(string SkillCode, string SkillName, double PCorrect, DateTime UpdatedAt);
    private record PlacementItem(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
    private record StartDto(Guid SessionId, PlacementItem Item);
    private record StepDto(bool Done, PlacementItem? Item);

    [Fact]
    public async Task Answering_placement_items_updates_mastery_for_their_skill()
    {
        var email = $"{Guid.NewGuid():N}@t.com";
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "M" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var items = Enumerable.Range(0, 10).Select(i => new
        {
            skillCode = "grammar.tenses.present_simple", cefrLevel = "B1", type = "mcq",
            stem = $"M{i}: she ___ tea.", options = new[] { "drinks", "drink", "drank", "drunk" },
            correctAnswer = "drinks", source = "test"
        });
        (await _client.PostAsJsonAsync("/admin/items/import", items)).EnsureSuccessStatusCode();

        var start = await (await _client.PostAsync("/placement/start", null))
            .Content.ReadFromJsonAsync<StartDto>();
        var step = await (await _client.PostAsJsonAsync($"/placement/{start!.SessionId}/answer",
            new { itemId = start.Item.Id, answer = "drinks" })).Content.ReadFromJsonAsync<StepDto>();
        await _client.PostAsJsonAsync($"/placement/{start.SessionId}/answer",
            new { itemId = step!.Item!.Id, answer = "drinks" });

        var mastery = await _client.GetFromJsonAsync<List<MasteryRow>>("/mastery");
        var row = Assert.Single(mastery!, m => m.SkillCode == "grammar.tenses.present_simple");
        Assert.True(row.PCorrect > 0.5);
    }
}
```

(add `using System.Net.Http.Json;` at the top of the file)

Run: `dotnet test QuestGraph.Tests --filter Mastery` → FAIL.

- [x] **Step 2: Implement mastery domain + endpoints, verify pass**

`QuestGraph/Domain/Mastery.cs`:

```csharp
namespace QuestGraph.Domain;

public class Mastery
{
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public double PCorrect { get; set; } = 0.5;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
```

`QuestGraph/Domain/MasteryCalc.cs`:

```csharp
namespace QuestGraph.Domain;

/// EMA update with Ebbinghaus-style decay toward the 0.5 uninformed baseline.
public static class MasteryCalc
{
    private const double DecayRate = 0.03;   // per day
    private const double LearningRate = 0.3;

    public static double Update(double prior, bool correct, double daysSinceLast)
    {
        var decayed = 0.5 + (prior - 0.5) * Math.Exp(-DecayRate * Math.Max(0, daysSinceLast));
        var target = correct ? 1.0 : 0.0;
        return Math.Clamp(decayed + LearningRate * (target - decayed), 0.0, 1.0);
    }
}
```

`QuestGraph/Services/MasteryService.cs`:

```csharp
using QuestGraph.Data;
using QuestGraph.Domain;

namespace QuestGraph.Services;

public class MasteryService(AppDbContext db)
{
    public async Task RecordAnswerAsync(Guid userId, int skillId, bool correct)
    {
        var m = await db.Masteries.FindAsync(userId, skillId);
        if (m is null)
        {
            m = new Mastery { UserId = userId, SkillId = skillId };
            db.Masteries.Add(m);
        }
        var days = (DateTime.UtcNow - m.UpdatedAt).TotalDays;
        m.PCorrect = MasteryCalc.Update(m.PCorrect, correct, days);
        m.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
    }
}
```

`AppDbContext`: `DbSet<Mastery> Masteries`; `mb.Entity<Mastery>().HasKey(m => new { m.UserId, m.SkillId });`
`Program.cs`: `builder.Services.AddScoped<MasteryService>();` and `app.MapMastery();`

`QuestGraph/Endpoints/MasteryEndpoints.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

public static class MasteryEndpoints
{
    public static void MapMastery(this WebApplication app)
    {
        app.MapGet("/mastery", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.Masteries.Where(m => m.UserId == user.UserId())
                .Join(db.Skills, m => m.SkillId, s => s.Id, (m, s) => new
                    { skillCode = s.Code, skillName = s.Name, pCorrect = m.PCorrect, updatedAt = m.UpdatedAt })
                .ToListAsync()).RequireAuthorization();
    }
}
```

In `PlacementEndpoints` answer handler, after computing `correct` and saving the `Response`, add (inject `MasteryService masteries` into the delegate):

```csharp
await masteries.RecordAnswerAsync(user.UserId(), item.SkillId, correct);
```

Run: `dotnet test QuestGraph.Tests` → PASS. Then `dotnet ef migrations add AddMastery --project QuestGraph`.

- [x] **Step 3: Write failing Python test for `/kt/predict`**

`ml/tests/test_kt_api.py`:

```python
import torch
from pathlib import Path
from fastapi.testclient import TestClient

def make_checkpoint(tmp_path: Path) -> Path:
    from questgraph_ml.kt.saint_plus import SAINTPlus
    m = SAINTPlus(n_questions=100, seq_len=100, d=32, heads=4, layers=1)
    p = tmp_path / "saint_plus.pt"
    torch.save({"state_dict": m.state_dict(),
                "config": {"model": "saint_plus", "n_questions": 100,
                           "d": 32, "seq_len": 100, "heads": 4, "layers": 1}}, p)
    return p

def test_kt_predict_returns_probabilities(tmp_path, monkeypatch):
    monkeypatch.setenv("QG_KT_CHECKPOINT", str(make_checkpoint(tmp_path)))
    from questgraph_ml.serving import kt_routes
    kt_routes.reset_model()          # force reload with the env var
    from questgraph_ml.serving.app import app
    r = TestClient(app).post("/kt/predict", json={"sequence": [
        {"q_idx": 5, "part": 1, "correct": 1, "elapsed": 0.1, "lag": 0.0},
        {"q_idx": 9, "part": 2, "correct": 0, "elapsed": 0.2, "lag": 0.3},
    ]})
    assert r.status_code == 200
    probs = r.json()["p_next"]
    assert len(probs) == 2 and all(0.0 <= p <= 1.0 for p in probs)

def test_kt_predict_without_checkpoint_returns_503(monkeypatch, tmp_path):
    monkeypatch.setenv("QG_KT_CHECKPOINT", str(tmp_path / "missing.pt"))
    from questgraph_ml.serving import kt_routes
    kt_routes.reset_model()
    from questgraph_ml.serving.app import app
    r = TestClient(app).post("/kt/predict", json={"sequence": []})
    assert r.status_code == 503
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_kt_api.py -v` → FAIL.

- [x] **Step 4: Implement `/kt/predict`, verify pass**

`ml/questgraph_ml/serving/kt_routes.py`:

```python
import os
from pathlib import Path
import torch
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from questgraph_ml.kt.saint_plus import SAINTPlus

router = APIRouter()
_model: SAINTPlus | None = None
_seq_len = 100

def reset_model():
    global _model
    _model = None

def _load():
    global _model, _seq_len
    if _model is None:
        path = Path(os.environ.get("QG_KT_CHECKPOINT", "checkpoints/saint_plus.pt"))
        if not path.exists():
            return None
        ckpt = torch.load(path, map_location="cpu", weights_only=False)
        cfg = ckpt["config"]
        _seq_len = cfg["seq_len"]
        _model = SAINTPlus(cfg["n_questions"], d=cfg["d"], seq_len=cfg["seq_len"],
                           heads=cfg.get("heads", 8), layers=cfg.get("layers", 2))
        _model.load_state_dict(ckpt["state_dict"])
        _model.eval()
    return _model

class KtEvent(BaseModel):
    q_idx: int; part: int; correct: int; elapsed: float; lag: float

class KtRequest(BaseModel):
    sequence: list[KtEvent]

@router.post("/kt/predict")
def kt_predict(req: KtRequest):
    model = _load()
    if model is None:
        return JSONResponse({"error": "model_not_loaded"}, status_code=503)
    n = len(req.sequence)
    if n == 0:
        return {"p_next": []}
    seq = req.sequence[-_seq_len:]
    L = len(seq)
    batch = {
        "q": torch.tensor([[e.q_idx for e in seq]]),
        "part": torch.tensor([[e.part for e in seq]]),
        "correct": torch.tensor([[e.correct for e in seq]]),
        "elapsed": torch.tensor([[e.elapsed for e in seq]], dtype=torch.float32),
        "lag": torch.tensor([[e.lag for e in seq]], dtype=torch.float32),
        "mask": torch.ones(1, L),
    }
    with torch.no_grad():
        probs = torch.sigmoid(model(batch))[0].tolist()
    # covers the last min(n, seq_len) events; longer histories are truncated
    return {"p_next": probs}
```

In `serving/app.py` add:

```python
from questgraph_ml.serving.kt_routes import router as kt_router
app.include_router(kt_router)
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [x] **Step 5: Commit**

```powershell
git add -A
git commit -m "feat: SAINT+ inference endpoint and per-skill mastery tracking"
```
