# Task 14: Speaking Assessment — upload → Whisper → scoring + Vietnamese feedback

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-2, task-12 (serving app + llm client). Sprint 3.
> Scope note: simplified pipeline (no MFA/GOP — requirement.md §7 V-7); phoneme-level scoring is future work.

**Files:**
- Create: `ml/questgraph_ml/speech/__init__.py`, `ml/questgraph_ml/speech/scoring.py`, `ml/questgraph_ml/serving/speech_routes.py`, `ml/tests/test_speech.py`, `QuestGraph/Domain/SpeakingAttempt.cs`, `QuestGraph/Endpoints/SpeakingEndpoints.cs`, `QuestGraph.Tests/SpeakingTests.cs`
- Modify: `ml/questgraph_ml/serving/app.py`, `ml/requirements.txt` (add `python-multipart>=0.0.9`), `QuestGraph/Services/MlClient.cs`, `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`, `QuestGraph.Tests/PlacementTests.cs` (FakeMlClient grows)

**Interfaces:**
- Consumes: auth, `ApiResults.MlUnavailable()`.
- Produces:
  - Python: `word_scores(expected: str, transcript: str) -> dict` with keys `accuracy, completeness, missing_words:list[str]` (all in [0,1] except the list); `fluency_from_wpm(wpm: float) -> float`; `POST /speech/score` (multipart: `file` = audio, `prompt_text` = form field) → `{"transcript","accuracy","completeness","fluency","total","feedback_vi"}` where `total = 0.6·accuracy + 0.2·completeness + 0.2·fluency`.
  - `IMlClient` gains `Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName, string promptText, CancellationToken ct = default)`; `record SpeakingScoreResponse(string Transcript, double Accuracy, double Completeness, double Fluency, double Total, [property: JsonPropertyName("feedback_vi")] string FeedbackVi)`.
  - C#: `SpeakingAttempt { Guid Id, Guid UserId, string PromptText, string AudioPath, string? Transcript, double Total, string? ScoresJson, DateTime CreatedAt }`; `POST /speaking/attempts` (multipart `audio` + `promptText`) → score payload; `GET /speaking/attempts` → history. Uploads go to `wwwroot/uploads/` (gitignored).

- [ ] **Step 1: Write failing Python scoring tests**

`ml/tests/test_speech.py`:

```python
from questgraph_ml.speech.scoring import word_scores, fluency_from_wpm

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

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_speech.py -v` → FAIL.

- [ ] **Step 2: Implement scoring, verify pass**

`ml/questgraph_ml/speech/scoring.py`:

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

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [ ] **Step 3: Implement `/speech/score` route**

`ml/questgraph_ml/serving/speech_routes.py`:

```python
import io
from functools import lru_cache
from fastapi import APIRouter, UploadFile, Form
from questgraph_ml.speech.scoring import word_scores, fluency_from_wpm

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
    from questgraph_ml.serving.llm_routes import _client
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

In `serving/app.py`: `from questgraph_ml.serving.speech_routes import router as speech_router` + `app.include_router(speech_router)`. Install: `ml/.venv/Scripts/pip install python-multipart faster-whisper` and add both (`python-multipart>=0.0.9`, `faster-whisper>=1.0`) to `ml/requirements.txt`. First `/speech/score` call downloads the "small" model (~460 MB) to the HF cache.

- [ ] **Step 4: Write failing .NET test, then implement**

`QuestGraph.Tests/SpeakingTests.cs`:

```csharp
using System.Net.Http.Json;

namespace QuestGraph.Tests;

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

Extend `FakeMlClient`:

```csharp
public Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName,
    string promptText, CancellationToken ct = default)
    => Task.FromResult(new SpeakingScoreResponse(promptText, 0.9, 1.0, 0.8, 0.88,
        "Phát âm tốt, chú ý âm cuối."));
```

Add to `MlClient.cs`:

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

`QuestGraph/Domain/SpeakingAttempt.cs`:

```csharp
namespace QuestGraph.Domain;

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

`QuestGraph/Endpoints/SpeakingEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

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

`AppDbContext`: `DbSet<SpeakingAttempt> SpeakingAttempts`. `Program.cs`: `app.MapSpeaking();` + `builder.Services.AddAntiforgery();` (required by minimal-API form handling).

Run: `dotnet test QuestGraph.Tests` → PASS.

- [ ] **Step 5: Live check, migration, commit**

Record a short clip (any phone voice memo), start both services, POST it via the OpenAPI UI or curl; verify transcript, sensible scores, Vietnamese feedback. Save one response to `ml/reports/samples/speaking.md`.

```powershell
dotnet ef migrations add AddSpeakingAttempts --project QuestGraph
git add -A
git commit -m "feat: speaking assessment via Whisper with Vietnamese feedback"
```
