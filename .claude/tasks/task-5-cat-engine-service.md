# Task 5: CAT Engine — IRT 3PL math, FastAPI `/cat/select`, .NET ML client

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-1 (.NET side), task-4 (ml env).

**Files:**
- Create: `ml/questgraph_ml/irt.py`, `ml/questgraph_ml/cat.py`, `ml/questgraph_ml/serving/__init__.py`, `ml/questgraph_ml/serving/app.py`, `ml/tests/test_irt.py`, `ml/tests/test_cat_api.py`, `QuestGraph/Services/MlClient.cs`, `QuestGraph.Tests/MlClientTests.cs`
- Modify: `ml/requirements.txt`, `QuestGraph/Program.cs`, `QuestGraph/appsettings.Development.json`

**Interfaces:**
- Consumes: `ml/.venv` (task-4).
- Produces:
  - Python: `prob_3pl(theta, a, b, c)`, `information(theta, a, b, c)`, `eap_estimate(history) -> (theta, se)` where `history = list[tuple[a, b, c, correct]]`; `select_next(theta, candidates) -> item_id` — all reused verbatim by task-7's simulation.
  - HTTP: `POST /cat/select` body `{"history":[{"a":..,"b":..,"c":..,"correct":true}], "candidates":[{"item_id":"<guid>","a":..,"b":..,"c":..}]}` → `{"theta":..,"se":..,"next_item_id":"<guid>|null"}` (snake_case JSON).
  - .NET: `IMlClient` with `Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)`; records `CatHistory(double A, double B, double C, bool Correct)`, `CatCandidate(Guid ItemId, double A, double B, double C)`, `CatSelectRequest(List<CatHistory> History, List<CatCandidate> Candidates)`, `CatSelectResponse(double Theta, double Se, Guid? NextItemId)`; throws `MlServiceUnavailableException` when the service is unreachable. Registered as typed HttpClient reading `MlService:BaseUrl`.

- [x] **Step 1: Write failing IRT tests**

`ml/tests/test_irt.py`:

```python
import numpy as np
from questgraph_ml.irt import prob_3pl, information, eap_estimate
from questgraph_ml.cat import select_next

def test_prob_at_b_is_midpoint_between_c_and_1():
    np.testing.assert_allclose(prob_3pl(0.5, 1.2, 0.5, 0.2), 0.2 + 0.8 / 2, rtol=1e-9)

def test_prob_monotonic_in_theta():
    thetas = np.linspace(-3, 3, 13)
    ps = [prob_3pl(t, 1.0, 0.0, 0.25) for t in thetas]
    assert all(p2 > p1 for p1, p2 in zip(ps, ps[1:]))

def test_information_peaks_near_b_when_c_zero():
    thetas = np.linspace(-3, 3, 601)
    infos = [information(t, 1.5, 0.8, 0.0) for t in thetas]
    assert abs(thetas[int(np.argmax(infos))] - 0.8) < 0.05

def test_eap_prior_only():
    theta, se = eap_estimate([])
    assert abs(theta) < 1e-9
    assert 0.95 < se <= 1.0

def test_eap_moves_up_after_correct_answers():
    hard = [(1.5, 1.0, 0.2, True)] * 10
    theta, se = eap_estimate(hard)
    assert theta > 1.0
    assert se < 0.5

def test_select_next_prefers_item_matching_ability():
    candidates = [("easy", 1.5, -2.0, 0.2), ("mid", 1.5, 0.1, 0.2), ("hard", 1.5, 2.0, 0.2)]
    assert select_next(theta=0.0, candidates=candidates) == "mid"
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_irt.py -v`
Expected: FAIL — modules missing.

- [x] **Step 2: Implement `irt.py` and `cat.py`, verify pass**

`ml/questgraph_ml/irt.py`:

```python
"""3PL IRT: P(theta) = c + (1-c) / (1 + exp(-a(theta-b))). EAP over N(0,1) prior."""
import numpy as np

_GRID = np.linspace(-4.0, 4.0, 161)
_PRIOR = np.exp(-0.5 * _GRID**2)

def prob_3pl(theta, a: float, b: float, c: float):
    return c + (1.0 - c) / (1.0 + np.exp(-a * (np.asarray(theta) - b)))

def information(theta, a: float, b: float, c: float):
    p = prob_3pl(theta, a, b, c)
    q = 1.0 - p
    return (a**2) * ((p - c) ** 2 / (1.0 - c) ** 2) * (q / p)

def eap_estimate(history: list[tuple[float, float, float, bool]]) -> tuple[float, float]:
    like = np.ones_like(_GRID)
    for a, b, c, correct in history:
        p = prob_3pl(_GRID, a, b, c)
        like = like * (p if correct else 1.0 - p)
    post = like * _PRIOR
    post = post / post.sum()
    theta = float((_GRID * post).sum())
    se = float(np.sqrt(((_GRID - theta) ** 2 * post).sum()))
    return theta, se
```

`ml/questgraph_ml/cat.py`:

```python
"""Maximum-Information item selection."""
from questgraph_ml.irt import information

def select_next(theta: float, candidates: list[tuple]) -> object | None:
    """candidates: list of (item_id, a, b, c). Returns item_id with max Fisher information."""
    if not candidates:
        return None
    return max(candidates, key=lambda it: information(theta, it[1], it[2], it[3]))[0]
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [x] **Step 3: Write failing FastAPI test**

Append to `ml/requirements.txt`: `fastapi>=0.111`, `uvicorn>=0.29` then `ml/.venv/Scripts/pip install -r ml/requirements.txt`.

`ml/tests/test_cat_api.py`:

```python
from fastapi.testclient import TestClient
from questgraph_ml.serving.app import app

client = TestClient(app)

def test_cat_select_returns_theta_and_next_item():
    body = {
        "history": [{"a": 1.0, "b": 0.0, "c": 0.25, "correct": True}],
        "candidates": [
            {"item_id": "11111111-1111-1111-1111-111111111111", "a": 1.2, "b": 0.3, "c": 0.25},
            {"item_id": "22222222-2222-2222-2222-222222222222", "a": 1.2, "b": -2.5, "c": 0.25},
        ],
    }
    r = client.post("/cat/select", json=body)
    assert r.status_code == 200
    data = r.json()
    assert {"theta", "se", "next_item_id"} <= data.keys()
    assert data["next_item_id"] == "11111111-1111-1111-1111-111111111111"

def test_cat_select_empty_candidates_returns_null_item():
    r = client.post("/cat/select", json={"history": [], "candidates": []})
    assert r.status_code == 200
    assert r.json()["next_item_id"] is None
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_cat_api.py -v` → FAIL.

- [x] **Step 4: Implement FastAPI app, verify pass**

`ml/questgraph_ml/serving/app.py`:

```python
from fastapi import FastAPI
from pydantic import BaseModel
from questgraph_ml.cat import select_next
from questgraph_ml.irt import eap_estimate

app = FastAPI(title="QuestGraph ML Service")

class HistoryEntry(BaseModel):
    a: float; b: float; c: float; correct: bool

class Candidate(BaseModel):
    item_id: str; a: float; b: float; c: float

class CatSelectRequest(BaseModel):
    history: list[HistoryEntry]
    candidates: list[Candidate]

class CatSelectResponse(BaseModel):
    theta: float; se: float; next_item_id: str | None

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/cat/select", response_model=CatSelectResponse)
def cat_select(req: CatSelectRequest):
    theta, se = eap_estimate([(h.a, h.b, h.c, h.correct) for h in req.history])
    next_id = select_next(theta, [(c.item_id, c.a, c.b, c.c) for c in req.candidates])
    return CatSelectResponse(theta=theta, se=se, next_item_id=next_id)
```

Create empty `ml/questgraph_ml/serving/__init__.py`.
Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

Manual check: `ml/.venv/Scripts/uvicorn questgraph_ml.serving.app:app --port 8001 --app-dir ml` then GET `http://localhost:8001/health` → `{"status":"ok"}`.

- [x] **Step 5: Write failing .NET MlClient test**

`QuestGraph.Tests/MlClientTests.cs` (stub `HttpMessageHandler` — no live service needed):

```csharp
using System.Net;
using System.Text;
using QuestGraph.Services;

namespace QuestGraph.Tests;

public class MlClientTests
{
    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public string? LastBody;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
        {
            LastBody = req.Content is null ? null : await req.Content.ReadAsStringAsync(ct);
            return respond(req);
        }
    }

    [Fact]
    public async Task CatSelect_serializes_snake_case_and_parses_response()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(
                """{"theta":0.42,"se":0.31,"next_item_id":"11111111-1111-1111-1111-111111111111"}""",
                Encoding.UTF8, "application/json")
        });
        var client = new MlClient(new HttpClient(handler) { BaseAddress = new Uri("http://ml") });

        var res = await client.CatSelectAsync(new CatSelectRequest(
            [new CatHistory(1.0, 0.0, 0.25, true)],
            [new CatCandidate(Guid.NewGuid(), 1.2, 0.3, 0.25)]));

        Assert.Equal(0.42, res.Theta, 3);
        Assert.Equal(Guid.Parse("11111111-1111-1111-1111-111111111111"), res.NextItemId);
        Assert.Contains("\"item_id\"", handler.LastBody);
        Assert.Contains("\"correct\":true", handler.LastBody);
    }

    [Fact]
    public async Task Unreachable_service_throws_MlServiceUnavailableException()
    {
        var handler = new StubHandler(_ => throw new HttpRequestException("boom"));
        var client = new MlClient(new HttpClient(handler) { BaseAddress = new Uri("http://ml") });
        await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
            client.CatSelectAsync(new CatSelectRequest([], [])));
    }
}
```

Run: `dotnet test QuestGraph.Tests --filter MlClientTests` → FAIL (types missing).

- [x] **Step 6: Implement MlClient, verify pass**

`QuestGraph/Services/MlClient.cs`:

```csharp
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace QuestGraph.Services;

public class MlServiceUnavailableException(Exception inner)
    : Exception("ML service unavailable", inner);

public record CatHistory(double A, double B, double C, bool Correct);
public record CatCandidate([property: JsonPropertyName("item_id")] Guid ItemId,
    double A, double B, double C);
public record CatSelectRequest(List<CatHistory> History, List<CatCandidate> Candidates);
public record CatSelectResponse(double Theta, double Se,
    [property: JsonPropertyName("next_item_id")] Guid? NextItemId);

public interface IMlClient
{
    Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default);
}

public class MlClient(HttpClient http) : IMlClient
{
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };

    public async Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)
        => await PostAsync<CatSelectRequest, CatSelectResponse>("/cat/select", req, ct);

    protected async Task<TRes> PostAsync<TReq, TRes>(string path, TReq body, CancellationToken ct)
    {
        try
        {
            var res = await http.PostAsJsonAsync(path, body, Json, ct);
            res.EnsureSuccessStatusCode();
            return (await res.Content.ReadFromJsonAsync<TRes>(Json, ct))!;
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            throw new MlServiceUnavailableException(e);
        }
    }
}
```

`Program.cs` — register the typed client:

```csharp
builder.Services.AddHttpClient<IMlClient, MlClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["MlService:BaseUrl"] ?? "http://localhost:8001");
    c.Timeout = TimeSpan.FromSeconds(30);
});
```

`appsettings.Development.json` — add `"MlService": { "BaseUrl": "http://localhost:8001" }`.

Run: `dotnet test QuestGraph.Tests` → PASS.

- [x] **Step 7: Commit**

```powershell
git add -A
git commit -m "feat: IRT 3PL CAT engine, FastAPI /cat/select, .NET ML client"
```
