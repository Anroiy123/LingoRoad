# Task 14: Speaking Assessment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audio upload → local Whisper ASR → word-level accuracy/completeness/fluency scoring → Vietnamese feedback via Gemini, persisted as speaking attempts.

**Architecture:** Python gains a pure scoring module (`lingoroad_ml/speech/scoring.py`, no ASR dependency — unit-testable) and a `/speech/score` FastAPI route that runs local `faster-whisper` (GPU, CPU fallback) plus one Gemini call for Vietnamese feedback. The .NET API accepts a multipart upload at `POST /speaking/attempts`, stores the file under `wwwroot/uploads/`, proxies to the ML service via a new `IMlClient.ScoreSpeakingAsync`, and persists a `SpeakingAttempt` row; `GET /speaking/attempts` lists history. Simplified pipeline per requirement.md §7 V-7 — no MFA/GOP, phoneme-level scoring is future work.

**Tech Stack:** faster-whisper ("small" model, cuda float16 → cpu int8 fallback), python-multipart, difflib.SequenceMatcher; .NET 10 minimal API multipart form handling (antiforgery services required), EF Core.

**Repo context (READ FIRST — task file predates the QuestGraph→LingoRoad rename):**
- Working dir for .NET commands: `C:\Projects\LingoRoad\src\backend` (projects `LingoRoad/`, `LingoRoad.Tests/`).
- Python package is `ml/lingoroad_ml/`; tests run from `src/backend/ml` with `.venv\Scripts\python -m pytest tests\ -v`.
- Commit with EXPLICIT paths — never `git add -A`. Never commit `.claude/`, `ml/data/`, `ml/checkpoints/`, `ml/.venv/`, `LingoRoad/wwwroot/uploads/`.
- Baseline before this task: ml suite 35 passed, .NET suite 39 passed (task-13 done).
- `GEMINI_API_KEY` value: see Global Constraints in `src/backend/.claude/tasks/README.md` (never copy the key into committed files).
- Live-run gotchas: API must start with `dotnet run --launch-profile http` from `src/backend/LingoRoad`; the first real `/speech/score` call downloads the Whisper "small" model (~460 MB) to the HF cache — allow time.
- The user is not available to record audio: the live check synthesizes a clip with `edge-tts` (already installed) and uploads that.

---

### Task 1: Python — scoring module + `/speech/score` route

**Files:**
- Create: `src/backend/ml/lingoroad_ml/speech/__init__.py`, `src/backend/ml/lingoroad_ml/speech/scoring.py`, `src/backend/ml/lingoroad_ml/serving/speech_routes.py`
- Modify: `src/backend/ml/lingoroad_ml/serving/app.py`, `src/backend/ml/requirements.txt`
- Test: `src/backend/ml/tests/test_speech.py`

- [ ] **Step 1: Install runtime deps**

```powershell
cd C:\Projects\LingoRoad\src\backend\ml
.venv\Scripts\pip install "python-multipart>=0.0.9" "faster-whisper>=1.0"
```

Append to `src/backend/ml/requirements.txt` (after `nltk>=3.8`):

```
python-multipart>=0.0.9
faster-whisper>=1.0
```

- [ ] **Step 2: Write the failing scoring tests**

`src/backend/ml/tests/test_speech.py`:

```python
from lingoroad_ml.speech.scoring import word_scores, fluency_from_wpm

def test_perfect_match_scores_one():
    s = word_scores("I have lived here for two years", "I have lived here for two years")
    assert s["accuracy"] == 1.0 and s["completeness"] == 1.0 and s["missing_words"] == []

def test_missing_words_lower_accuracy_and_are_listed():
    s = word_scores("I have lived here for two years", "I lived here two years")
    assert 0 < s["accuracy"] < 1
    assert "have" in s["missing_words"] and "for" in s["missing_words"]

def test_case_and_punctuation_ignored():
    s = word_scores("Hello, world!", "hello world")
    assert s["accuracy"] == 1.0

def test_fluency_peaks_in_natural_range_and_clamps():
    assert fluency_from_wpm(130) == 1.0
    assert 0 <= fluency_from_wpm(30) < 1.0
    assert 0 <= fluency_from_wpm(300) < 1.0
    assert fluency_from_wpm(0) == 0.0
```

- [ ] **Step 3: Run tests, verify they FAIL**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\test_speech.py -v`
Expected: collection error — `ModuleNotFoundError: No module named 'lingoroad_ml.speech'`.

- [ ] **Step 4: Implement scoring**

`src/backend/ml/lingoroad_ml/speech/__init__.py` — empty file.

`src/backend/ml/lingoroad_ml/speech/scoring.py`:

```python
"""Word-level speaking scores from an expected prompt vs ASR transcript."""
import re
from difflib import SequenceMatcher

def _words(text: str) -> list[str]:
    return re.findall(r"[a-z']+", text.lower())

def word_scores(expected: str, transcript: str) -> dict:
    exp, got = _words(expected), _words(transcript)
    if not exp:
        return {"accuracy": 0.0, "completeness": 0.0, "missing_words": []}
    sm = SequenceMatcher(a=exp, b=got)
    matched_idx = set()
    for block in sm.get_matching_blocks():
        matched_idx.update(range(block.a, block.a + block.size))
    missing = [exp[i] for i in range(len(exp)) if i not in matched_idx]
    return {
        "accuracy": round(len(matched_idx) / len(exp), 3),
        "completeness": round(min(len(got) / len(exp), 1.0), 3),
        "missing_words": missing,
    }

def fluency_from_wpm(wpm: float) -> float:
    """1.0 in the natural 100-160 wpm band, tapering linearly outside."""
    if wpm <= 0:
        return 0.0
    if 100 <= wpm <= 160:
        return 1.0
    if wpm < 100:
        return round(wpm / 100.0, 3)
    return round(max(0.0, 1.0 - (wpm - 160) / 140.0), 3)
```

- [ ] **Step 5: Run tests, verify PASS**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\test_speech.py -v`
Expected: 4 passed.

- [ ] **Step 6: Implement the `/speech/score` route**

`src/backend/ml/lingoroad_ml/serving/speech_routes.py`:

```python
import io
from functools import lru_cache
from fastapi import APIRouter, UploadFile, Form
from lingoroad_ml.speech.scoring import word_scores, fluency_from_wpm

router = APIRouter()

FEEDBACK_PROMPT = """Học viên đọc câu: "{expected}"
Whisper nghe được: "{transcript}". Các từ bị thiếu/sai: {missing}.
Viết 2-3 câu phản hồi tiếng Việt: khen điểm tốt, chỉ ra từ cần luyện,
gợi ý cách phát âm (chú ý lỗi phổ biến của người Việt như /th/, âm cuối)."""

@lru_cache
def _whisper():
    """Local faster-whisper. "small" fits easily in the 4060's 8 GB; CPU fallback for dev boxes."""
    from faster_whisper import WhisperModel
    try:
        return WhisperModel("small", device="cuda", compute_type="float16")
    except Exception:
        return WhisperModel("small", device="cpu", compute_type="int8")

@router.post("/speech/score")
async def speech_score(file: UploadFile, prompt_text: str = Form(...)):
    from lingoroad_ml.serving.llm_routes import _client
    audio = io.BytesIO(await file.read())
    segments, info = _whisper().transcribe(audio, language="en")
    transcript = " ".join(seg.text.strip() for seg in segments)
    duration = max(info.duration or 0.0, 0.1)

    s = word_scores(prompt_text, transcript)
    wpm = len(transcript.split()) / (duration / 60.0)
    fluency = fluency_from_wpm(wpm)
    total = round(0.6 * s["accuracy"] + 0.2 * s["completeness"] + 0.2 * fluency, 3)

    fb = _client().chat.completions.create(model="gemini-2.5-flash", temperature=0.4, messages=[
        {"role": "user", "content": FEEDBACK_PROMPT.format(
            expected=prompt_text, transcript=transcript,
            missing=", ".join(s["missing_words"]) or "không có")}])
    return {"transcript": transcript, "accuracy": s["accuracy"],
            "completeness": s["completeness"], "fluency": fluency,
            "total": total, "feedback_vi": fb.choices[0].message.content}
```

IMPORTANT: this file contains Vietnamese text — write it with the Write tool (UTF-8), never via PowerShell redirection.

In `src/backend/ml/lingoroad_ml/serving/app.py` add with the other imports:

```python
from lingoroad_ml.serving.speech_routes import router as speech_router
```

and after the existing `app.include_router(llm_router)`:

```python
app.include_router(speech_router)
```

- [ ] **Step 7: Run the FULL ml suite, verify no regressions**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\ -v`
Expected: 39 passed (35 baseline + 4 new). (Route module imports must not load faster-whisper at import time — it's lazy inside `_whisper()` — so the suite stays fast.)

- [ ] **Step 8: Commit (explicit paths, from `src/backend`)**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add ml/tests/test_speech.py ml/lingoroad_ml/speech/__init__.py ml/lingoroad_ml/speech/scoring.py ml/lingoroad_ml/serving/speech_routes.py ml/lingoroad_ml/serving/app.py ml/requirements.txt
git commit -m "feat(ml): speaking scores (accuracy/completeness/fluency) + Whisper /speech/score route"
```

---

### Task 2: .NET — SpeakingAttempt entity, upload endpoint, MlClient member, tests

**Files:**
- Create: `src/backend/LingoRoad/Domain/SpeakingAttempt.cs`, `src/backend/LingoRoad/Endpoints/SpeakingEndpoints.cs`
- Modify: `src/backend/LingoRoad/Services/MlClient.cs`, `src/backend/LingoRoad/Data/AppDbContext.cs`, `src/backend/LingoRoad/Program.cs`, `src/backend/LingoRoad.Tests/PlacementTests.cs` (FakeMlClient grows), `src/backend/.gitignore` (uploads dir)
- Test: `src/backend/LingoRoad.Tests/SpeakingTests.cs`

- [ ] **Step 1: Add record + interface member to `MlClient.cs`**

After the exercise/AWE records add:

```csharp
public record SpeakingScoreResponse(string Transcript, double Accuracy, double Completeness,
    double Fluency, double Total,
    [property: JsonPropertyName("feedback_vi")] string FeedbackVi);
```

(`using System.Text.Json.Serialization;` is already at the top of the file.)

Add to `IMlClient`:

```csharp
Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName, string promptText, CancellationToken ct = default);
```

Add to `MlClient` (multipart — cannot reuse the JSON `PostAsync` helper):

```csharp
public async Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName,
    string promptText, CancellationToken ct = default)
{
    try
    {
        using var form = new MultipartFormDataContent
        {
            { new StreamContent(audio), "file", fileName },
            { new StringContent(promptText), "prompt_text" }
        };
        var res = await http.PostAsync("/speech/score", form, ct);
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<SpeakingScoreResponse>(Json, ct))!;
    }
    catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
    {
        throw new MlServiceUnavailableException(e);
    }
}
```

- [ ] **Step 2: Extend `FakeMlClient` in `LingoRoad.Tests/PlacementTests.cs`**

```csharp
public Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName,
    string promptText, CancellationToken ct = default)
    => Task.FromResult(new SpeakingScoreResponse(promptText, 0.9, 1.0, 0.8, 0.88,
        "Phát âm tốt, chú ý âm cuối."));
```

(Write with the Write/Edit tool — Vietnamese text.)

- [ ] **Step 3: Write the failing endpoint test**

`src/backend/LingoRoad.Tests/SpeakingTests.cs`:

```csharp
using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class SpeakingTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public SpeakingTests(PlacementFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Upload_returns_scores_and_stores_attempt()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "S" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        using var form = new MultipartFormDataContent
        {
            { new ByteArrayContent([1, 2, 3, 4]), "audio", "test.webm" },
            { new StringContent("I have lived here for two years"), "promptText" }
        };
        var res = await _client.PostAsync("/speaking/attempts", form);
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("transcript", body);
        Assert.Contains("total", body);

        var history = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>(
            "/speaking/attempts");
        Assert.Single(history!);
    }
}
```

- [ ] **Step 4: Run tests, verify FAIL**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests --filter SpeakingTests`
Expected: after Steps 1–2 compile, this fails with 404 on `/speaking/attempts`.

- [ ] **Step 5: Implement entity + endpoints + wiring**

`src/backend/LingoRoad/Domain/SpeakingAttempt.cs`:

```csharp
namespace LingoRoad.Domain;

public class SpeakingAttempt
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string PromptText { get; set; }
    public required string AudioPath { get; set; }
    public string? Transcript { get; set; }
    public double Total { get; set; }
    public string? ScoresJson { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

`src/backend/LingoRoad/Endpoints/SpeakingEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public static class SpeakingEndpoints
{
    public static void MapSpeaking(this WebApplication app)
    {
        var g = app.MapGroup("/speaking").RequireAuthorization();

        g.MapPost("/attempts", async (IFormFile audio, [Microsoft.AspNetCore.Mvc.FromForm] string promptText,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db,
            IMlClient ml, IWebHostEnvironment env) =>
        {
            var dir = Path.Combine(env.ContentRootPath, "wwwroot", "uploads");
            Directory.CreateDirectory(dir);
            var path = Path.Combine(dir, $"{Guid.NewGuid():N}{Path.GetExtension(audio.FileName)}");
            await using (var fs = File.Create(path))
                await audio.CopyToAsync(fs);

            try
            {
                await using var stream = File.OpenRead(path);
                var score = await ml.ScoreSpeakingAsync(stream, audio.FileName, promptText);
                var attempt = new SpeakingAttempt
                {
                    UserId = user.UserId(), PromptText = promptText, AudioPath = path,
                    Transcript = score.Transcript, Total = score.Total,
                    ScoresJson = JsonSerializer.Serialize(score)
                };
                db.SpeakingAttempts.Add(attempt);
                await db.SaveChangesAsync();
                return Results.Ok(new { attemptId = attempt.Id, score.Transcript,
                    score.Accuracy, score.Completeness, score.Fluency, score.Total,
                    feedbackVi = score.FeedbackVi });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).DisableAntiforgery();

        g.MapGet("/attempts", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.SpeakingAttempts.Where(a => a.UserId == user.UserId())
                .OrderByDescending(a => a.CreatedAt)
                .Select(a => new { a.Id, a.PromptText, a.Transcript, a.Total, a.CreatedAt })
                .ToListAsync());
    }
}
```

Match the `user.UserId()` extension usage to the existing endpoint files. If the compiler wants `IFormFile`/`[FromForm]` bound differently in .NET 10 minimal APIs, mirror what compiles — the observable contract (multipart `audio` + `promptText`, response shape) must not change.

`src/backend/LingoRoad/Data/AppDbContext.cs`: add `DbSet<SpeakingAttempt> SpeakingAttempts` in the file's existing style.

`src/backend/LingoRoad/Program.cs`:
- `builder.Services.AddAntiforgery();` with the other service registrations (required by minimal-API form binding),
- `app.UseAntiforgery();` after `app.UseAuthorization();` (only if the framework demands it at runtime — the upload endpoint itself has `.DisableAntiforgery()`; if the app runs and tests pass without the middleware line, omit it),
- `app.MapSpeaking();` with the other `app.Map...()` calls.

`src/backend/.gitignore`: ensure a `LingoRoad/wwwroot/uploads/` entry exists (add if missing).

- [ ] **Step 6: Run the speaking tests, verify PASS**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests --filter SpeakingTests`
Expected: 1 passed.

- [ ] **Step 7: Run the FULL .NET suite, verify no regressions**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests`
Expected: 40 passed (39 baseline + 1 new).

- [ ] **Step 8: Commit (explicit paths)**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add LingoRoad/Domain/SpeakingAttempt.cs LingoRoad/Endpoints/SpeakingEndpoints.cs LingoRoad/Services/MlClient.cs LingoRoad/Data/AppDbContext.cs LingoRoad/Program.cs LingoRoad.Tests/SpeakingTests.cs LingoRoad.Tests/PlacementTests.cs .gitignore
git commit -m "feat: speaking attempts upload endpoint with ML scoring proxy"
```

(If `.gitignore` needed no change, drop it from the `git add`.)

---

### Task 3: Migration, live check with synthesized audio, report sample

**Files:**
- Create: migration `AddSpeakingAttempts` (generated), `src/backend/ml/reports/samples/speaking.md`

- [ ] **Step 1: Add + apply the EF migration**

```powershell
cd C:\Projects\LingoRoad\src\backend
docker compose up -d db
dotnet ef migrations add AddSpeakingAttempts --project LingoRoad
dotnet ef database update --project LingoRoad
```

- [ ] **Step 2: Synthesize a test clip with edge-tts**

```powershell
cd C:\Projects\LingoRoad\src\backend\ml
.venv\Scripts\python -m edge_tts --voice en-US-AriaNeural --text "I have lived here for two years" --write-media "$env:TEMP\speaking_clip.mp3"
```

(Any temp path outside the repo works — e.g. the session scratchpad directory; do NOT put the clip in the repo.)

- [ ] **Step 3: Start both services and live-check**

```powershell
# ML service (background), with GEMINI_API_KEY set (value: src/backend/.claude/tasks/README.md)
cd C:\Projects\LingoRoad\src\backend\ml
.venv\Scripts\uvicorn lingoroad_ml.serving.app:app --port 8001

# API (background)
cd C:\Projects\LingoRoad\src\backend\LingoRoad
dotnet run --launch-profile http
```

Register a fresh user, then:

```powershell
curl -s -X POST http://localhost:5000/speaking/attempts -H "Authorization: Bearer $tok" -F "audio=@<scratchpad>\speaking_clip.mp3" -F "promptText=I have lived here for two years"
```

First call downloads the Whisper "small" model (~460 MB) — allow a few minutes; bump curl timeout accordingly. Verify: transcript ≈ the prompt, accuracy near 1.0, sensible fluency, Vietnamese `feedbackVi`; then `GET /speaking/attempts` shows the row. Also verify the direct ML route once (`POST http://localhost:8001/speech/score` multipart) so the sample can show both layers.

- [ ] **Step 4: Save the report sample**

`src/backend/ml/reports/samples/speaking.md` — the prompt text, how the clip was produced (edge-tts voice), the JSON response (transcript, scores, Vietnamese feedback), and a note that a TTS clip stands in for a human recording (report can replace with a real recording later).

- [ ] **Step 5: Commit + stop services**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add LingoRoad/Migrations ml/reports/samples/speaking.md
git commit -m "feat: AddSpeakingAttempts migration + speaking live sample"
```

Stop the uvicorn/dotnet background processes when done.
