# Task 13: Adaptive Exercises & AWE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LLM exercise generation (MCQ/cloze/rewrite) with WordNet distractors, exercise submit-and-score wired into mastery, and IELTS-rubric automated writing evaluation (AWE) with Vietnamese feedback.

**Architecture:** Python `ml/lingoroad_ml/llm/` gains three modules (prompt builders + parsers; Gemini via the OpenAI-compatible endpoint) exposed on the existing FastAPI `llm_routes.py` as `POST /llm/exercises` and `POST /llm/awe`. The .NET API (`LingoRoad/`) proxies via `IMlClient`, persists generated exercises (answers server-side only), scores submissions, and updates mastery through the existing `MasteryService`.

**Tech Stack:** Python 3.13 (`ml/.venv`), FastAPI, OpenAI SDK → Gemini (`gemini-2.5-flash`), NLTK WordNet; .NET 10 minimal API, EF Core/Npgsql, xUnit + WebApplicationFactory (SQLite in-memory).

**Repo context (READ FIRST — task file predates the QuestGraph→LingoRoad rename):**
- Working dir for .NET commands: `C:\Projects\LingoRoad\src\backend` (solution `LingoRoad.sln`, projects `LingoRoad/`, `LingoRoad.Tests/`).
- Python package is `ml/lingoroad_ml/` (NOT `questgraph_ml`); tests run from `C:\Projects\LingoRoad\src\backend\ml` with `.venv\Scripts\python -m pytest tests\ -v`.
- C# namespaces are `LingoRoad.*`.
- Commit with EXPLICIT paths — never `git add -A`. Never commit `.claude/`, `ml/data/`, `ml/checkpoints/`, `ml/.venv/`.
- Baseline before this task: ml suite 31 passed, .NET suite 37 passed.
- `GEMINI_API_KEY` value: see Global Constraints in `src/backend/.claude/tasks/README.md` (do not copy the key into committed files).
- Live-run gotchas: start the API with `dotnet run --launch-profile http` from `src/backend/LingoRoad` (NOT `--no-launch-profile`; secrets live in appsettings.Development.json). Vietnamese JSON request bodies must be written to a UTF-8 file and sent with `curl --data-binary "@file"` (inline `-d` mangles UTF-8 on Windows).

---

### Task 1: Python — exercise generation, WordNet distractors, AWE modules + routes

**Files:**
- Create: `src/backend/ml/lingoroad_ml/llm/exercises.py`, `src/backend/ml/lingoroad_ml/llm/distractors.py`, `src/backend/ml/lingoroad_ml/llm/awe.py`
- Modify: `src/backend/ml/lingoroad_ml/serving/llm_routes.py`, `src/backend/ml/requirements.txt`
- Test: `src/backend/ml/tests/test_exercises.py`

- [ ] **Step 1: Install nltk + wordnet data**

```powershell
cd C:\Projects\LingoRoad\src\backend\ml
.venv\Scripts\pip install "nltk>=3.8"
.venv\Scripts\python -c "import nltk; nltk.download('wordnet')"
```

Add `nltk>=3.8` to `src/backend/ml/requirements.txt` (append after `scikit-learn>=1.4`).

- [ ] **Step 2: Write the failing tests**

`src/backend/ml/tests/test_exercises.py`:

```python
import json
from lingoroad_ml.llm.exercises import build_exercise_messages, parse_exercises
from lingoroad_ml.llm.awe import build_awe_messages
from lingoroad_ml.llm.distractors import wordnet_distractors

def test_exercise_prompt_pins_cefr_skill_and_type():
    msgs = build_exercise_messages("grammar.conditionals.second", "Second Conditional",
                                   "B1", "mcq", 3)
    body = msgs[-1]["content"]
    assert "B1" in body and "Second Conditional" in body and "mcq" in body and "3" in body

def test_parse_exercises_validates_correct_answer_in_options():
    raw = json.dumps({"exercises": [
        {"stem": "If I ___ rich...", "options": ["were", "am", "was", "be"],
         "correct_answer": "were", "explanation_vi": "Câu điều kiện loại 2 dùng 'were'."},
        {"stem": "bad item", "options": ["a", "b"], "correct_answer": "zzz"},
    ]})
    parsed = parse_exercises(raw)
    assert len(parsed) == 1            # invalid item dropped
    assert parsed[0]["correct_answer"] == "were"

def test_wordnet_distractors_exclude_the_answer():
    ds = wordnet_distractors("happy", n=3)
    assert "happy" not in ds
    assert len(ds) <= 3

def test_awe_prompt_contains_ielts_criteria():
    msgs = build_awe_messages("Describe your hometown.", "My hometown is small...")
    body = msgs[0]["content"] + msgs[1]["content"]
    for crit in ["Task Achievement", "Coherence", "Lexical Resource", "Grammatical"]:
        assert crit in body
```

- [ ] **Step 3: Run tests, verify they FAIL**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\test_exercises.py -v`
Expected: collection errors — `ModuleNotFoundError: No module named 'lingoroad_ml.llm.exercises'`.

- [ ] **Step 4: Implement the three modules**

`src/backend/ml/lingoroad_ml/llm/exercises.py`:

```python
import json

SYSTEM = "You create English exercises for Vietnamese learners. Return strict JSON."

def build_exercise_messages(skill_code: str, skill_name: str, cefr: str,
                            ex_type: str, count: int) -> list[dict]:
    user = f"""Create {count} exercises. Skill: {skill_name} ({skill_code}).
CEFR level: {cefr} exactly. Type: {ex_type}.
- mcq: 4 options, one correct; distractors = common Vietnamese-learner errors.
- cloze: stem contains '___', options [], correct_answer = missing word/phrase.
- rewrite: stem gives a sentence + instruction; options []; correct_answer = rewritten sentence.
Each item: explanation_vi = short Vietnamese explanation of the answer.
Return JSON: {{"exercises":[{{"stem","options","correct_answer","explanation_vi"}}]}}"""
    return [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user}]

def parse_exercises(raw: str) -> list[dict]:
    items = json.loads(raw).get("exercises", [])
    valid = []
    for it in items:
        if not it.get("stem") or not it.get("correct_answer"):
            continue
        opts = it.get("options") or []
        if opts and it["correct_answer"] not in opts:
            continue
        valid.append({"stem": it["stem"], "options": opts,
                      "correct_answer": str(it["correct_answer"]),
                      "explanation_vi": it.get("explanation_vi", "")})
    return valid

def generate(client, skill_code, skill_name, cefr, ex_type, count) -> list[dict]:
    resp = client.chat.completions.create(
        model="gemini-2.5-flash", temperature=0.7, response_format={"type": "json_object"},
        messages=build_exercise_messages(skill_code, skill_name, cefr, ex_type, count))
    return parse_exercises(resp.choices[0].message.content)
```

`src/backend/ml/lingoroad_ml/llm/distractors.py`:

```python
"""WordNet-based distractors: related-but-wrong words (synonyms of other senses,
antonyms, co-hyponyms). Requires: nltk.download('wordnet')."""
from nltk.corpus import wordnet as wn

def wordnet_distractors(word: str, n: int = 3) -> list[str]:
    word = word.lower()
    pool: list[str] = []
    for syn in wn.synsets(word):
        for lemma in syn.lemmas():
            if lemma.antonyms():
                pool.extend(a.name() for a in lemma.antonyms())
        for hyper in syn.hypernyms():
            for hypo in hyper.hyponyms():          # co-hyponyms: same category, wrong word
                pool.extend(l.name() for l in hypo.lemmas())
    seen, out = set(), []
    for w in pool:
        w = w.replace("_", " ").lower()
        if w != word and w not in seen and " " not in w:
            seen.add(w); out.append(w)
        if len(out) == n:
            break
    return out
```

`src/backend/ml/lingoroad_ml/llm/awe.py`:

```python
import json

SYSTEM = """You are an English writing examiner. Score the essay 0-9 on the IELTS rubric:
Task Achievement, Coherence & Cohesion, Lexical Resource, Grammatical Range & Accuracy.
All feedback text in VIETNAMESE. Return strict JSON:
{"scores":{"task_achievement":n,"coherence_cohesion":n,"lexical_resource":n,
"grammatical_accuracy":n},"feedback":[{"sentence":"<original>","issue":"<vi>",
"suggestion":"<vi>"}],"overall_vi":"<vi summary>"}"""

def build_awe_messages(task_prompt: str, essay: str) -> list[dict]:
    return [{"role": "system", "content": SYSTEM},
            {"role": "user", "content": f"Task: {task_prompt}\n\nEssay:\n{essay}"}]

def evaluate(client, task_prompt: str, essay: str) -> dict:
    resp = client.chat.completions.create(
        model="gemini-2.5-flash", temperature=0.2, response_format={"type": "json_object"},
        messages=build_awe_messages(task_prompt, essay))
    return json.loads(resp.choices[0].message.content)
```

- [ ] **Step 5: Run tests, verify PASS**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\test_exercises.py -v`
Expected: 4 passed.

- [ ] **Step 6: Add the FastAPI routes**

Append to `src/backend/ml/lingoroad_ml/serving/llm_routes.py` (the file already imports `APIRouter`, `BaseModel`, defines `router` and `_client`):

```python
from lingoroad_ml.llm import exercises as ex_mod, awe as awe_mod

class ExerciseReq(BaseModel):
    skill_code: str; skill_name: str; cefr: str; type: str = "mcq"; count: int = 3

@router.post("/llm/exercises")
def llm_exercises(req: ExerciseReq):
    items = ex_mod.generate(_client(), req.skill_code, req.skill_name,
                            req.cefr, req.type, req.count)
    return {"exercises": items}

class AweReq(BaseModel):
    task_prompt: str; essay: str

@router.post("/llm/awe")
def llm_awe(req: AweReq):
    return awe_mod.evaluate(_client(), req.task_prompt, req.essay)
```

Also change the top import line `from lingoroad_ml.llm import advisor, rag` — leave it; just add the new import line after it.

- [ ] **Step 7: Run the FULL ml suite, verify no regressions**

Run: `cd C:\Projects\LingoRoad\src\backend\ml; .venv\Scripts\python -m pytest tests\ -v`
Expected: 35 passed (31 baseline + 4 new).

- [ ] **Step 8: Commit (explicit paths, from `src/backend`)**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add ml/tests/test_exercises.py ml/lingoroad_ml/llm/exercises.py ml/lingoroad_ml/llm/distractors.py ml/lingoroad_ml/llm/awe.py ml/lingoroad_ml/serving/llm_routes.py ml/requirements.txt
git commit -m "feat(ml): LLM exercise generation, WordNet distractors, IELTS-rubric AWE"
```

---

### Task 2: .NET — Exercise entity, endpoints, MlClient members, tests

**Files:**
- Create: `src/backend/LingoRoad/Domain/Exercise.cs`, `src/backend/LingoRoad/Endpoints/ExerciseEndpoints.cs`
- Modify: `src/backend/LingoRoad/Services/MlClient.cs`, `src/backend/LingoRoad/Data/AppDbContext.cs`, `src/backend/LingoRoad/Program.cs`, `src/backend/LingoRoad.Tests/PlacementTests.cs` (FakeMlClient grows)
- Test: `src/backend/LingoRoad.Tests/ExerciseTests.cs`

- [ ] **Step 1: Add records + interface members to `MlClient.cs`**

In `src/backend/LingoRoad/Services/MlClient.cs`, after the advisor records add:

```csharp
public record ExerciseGenRequest(string SkillCode, string SkillName, string Cefr, string Type, int Count);
public record GeneratedExercise(string Stem, string[] Options, string CorrectAnswer, string? ExplanationVi);
public record ExerciseGenResponse(List<GeneratedExercise> Exercises);

public record AweRequest(string TaskPrompt, string Essay);
public record AweScores(double TaskAchievement, double CoherenceCohesion, double LexicalResource, double GrammaticalAccuracy);
public record AweFeedback(string Sentence, string Issue, string Suggestion);
public record AweResponse(AweScores Scores, List<AweFeedback> Feedback, string OverallVi);
```

Add to `IMlClient`:

```csharp
Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default);
Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default);
```

Add to `MlClient` (the snake_case `Json` options already map `explanation_vi`→`ExplanationVi`, `task_achievement`→`TaskAchievement`, `overall_vi`→`OverallVi`):

```csharp
public async Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
    => await PostAsync<ExerciseGenRequest, ExerciseGenResponse>("/llm/exercises", req, ct);

public async Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
    => await PostAsync<AweRequest, AweResponse>("/llm/awe", req, ct);
```

- [ ] **Step 2: Extend `FakeMlClient` in `LingoRoad.Tests/PlacementTests.cs`**

Add inside `FakeMlClient`:

```csharp
public Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
    => Task.FromResult(new ExerciseGenResponse([
        new GeneratedExercise("She ___ here since 2019.",
            ["has lived", "lived", "lives", "living"], "has lived",
            "Dùng thì hiện tại hoàn thành với 'since'.")]));

public Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
    => Task.FromResult(new AweResponse(new AweScores(6, 6, 5, 5),
        [new AweFeedback("My hometown is Da Nang.", "Câu quá ngắn", "Thêm chi tiết mô tả.")],
        "Bài viết ổn, cần phát triển ý."));
```

- [ ] **Step 3: Write the failing endpoint tests**

`src/backend/LingoRoad.Tests/ExerciseTests.cs`:

```csharp
using System.Net.Http.Json;

namespace LingoRoad.Tests;

public class ExerciseTests : IClassFixture<PlacementFactory>
{
    private readonly HttpClient _client;
    public ExerciseTests(PlacementFactory f) => _client = f.CreateClient();

    private record ExDto(Guid Id, string Stem, string[] Options);
    private record SubmitDto(bool Correct, string CorrectAnswer, string? ExplanationVi);

    private async Task AuthAsync()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "E" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
    }

    [Fact]
    public async Task Generate_returns_exercises_without_answers_then_submit_scores()
    {
        await AuthAsync();
        var gen = await _client.PostAsJsonAsync("/exercises/generate",
            new { skillCode = "grammar.tenses.present_perfect" });
        gen.EnsureSuccessStatusCode();
        var list = await gen.Content.ReadFromJsonAsync<List<ExDto>>();
        Assert.NotEmpty(list!);
        Assert.DoesNotContain("has lived", System.Text.Json.JsonSerializer.Serialize(list));

        var submit = await _client.PostAsJsonAsync($"/exercises/{list![0].Id}/submit",
            new { answer = "has lived" });   // FakeMlClient's fixed correct answer
        var result = await submit.Content.ReadFromJsonAsync<SubmitDto>();
        Assert.True(result!.Correct);

        var mastery = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
        Assert.NotEmpty(mastery!);
    }

    [Fact]
    public async Task Writing_evaluate_proxies_awe()
    {
        await AuthAsync();
        var res = await _client.PostAsJsonAsync("/writing/evaluate",
            new { taskPrompt = "Describe your hometown", essay = "My hometown is Da Nang." });
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("taskAchievement", body);
        Assert.Contains("overallVi", body);
    }
}
```

NOTE: the generate test uses skill code `grammar.tenses.present_perfect` — verify it exists in the seeded skills (`LingoRoad.Tests` seeds the graph via `TestAppFactory`). If the seeded test data uses different codes, pick any seeded skill code and keep the rest of the test identical. Check with: `grep -r "grammar.tenses" src/backend/LingoRoad.Tests src/backend/LingoRoad` or inspect the test seed helper.

- [ ] **Step 4: Run tests, verify they FAIL to compile / fail**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests --filter ExerciseTests`
Expected: compile error (missing endpoints/entity) — that is the red state, since FakeMlClient can't implement not-yet-declared members until Step 1 is in; after Steps 1–2 it fails with 404s on `/exercises/generate`.

- [ ] **Step 5: Implement entity + endpoints**

`src/backend/LingoRoad/Domain/Exercise.cs`:

```csharp
namespace LingoRoad.Domain;

public class Exercise
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public required string CefrLevel { get; set; }
    public required string Type { get; set; }
    public required string Stem { get; set; }
    public required string OptionsJson { get; set; }
    public required string CorrectAnswer { get; set; }
    public string? ExplanationVi { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

`src/backend/LingoRoad/Endpoints/ExerciseEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record GenerateExercisesRequest(string SkillCode, string? Type);
public record SubmitExerciseRequest(string Answer);
public record WritingEvalRequest(string TaskPrompt, string Essay);

public static class ExerciseEndpoints
{
    public static void MapExercises(this WebApplication app)
    {
        var g = app.MapGroup("/exercises").RequireAuthorization();

        g.MapPost("/generate", async (GenerateExercisesRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml) =>
        {
            var skill = await db.Skills.SingleOrDefaultAsync(s => s.Code == req.SkillCode);
            if (skill is null) return Results.BadRequest(new { error = "unknown_skill" });
            try
            {
                var res = await ml.GenerateExercisesAsync(new ExerciseGenRequest(
                    skill.Code, skill.Name, skill.CefrLevel, req.Type ?? "mcq", 3));
                var rows = res.Exercises.Select(e => new Exercise
                {
                    UserId = user.UserId(), SkillId = skill.Id, CefrLevel = skill.CefrLevel,
                    Type = req.Type ?? "mcq", Stem = e.Stem,
                    OptionsJson = JsonSerializer.Serialize(e.Options),
                    CorrectAnswer = e.CorrectAnswer, ExplanationVi = e.ExplanationVi
                }).ToList();
                db.Exercises.AddRange(rows);
                await db.SaveChangesAsync();
                return Results.Ok(rows.Select(r => new { r.Id, r.Stem,
                    options = JsonSerializer.Deserialize<string[]>(r.OptionsJson) }));
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });

        g.MapPost("/{id:guid}/submit", async (Guid id, SubmitExerciseRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db,
            MasteryService masteries) =>
        {
            var ex = await db.Exercises.SingleOrDefaultAsync(
                e => e.Id == id && e.UserId == user.UserId());
            if (ex is null) return Results.NotFound();
            var correct = string.Equals(req.Answer.Trim(), ex.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            await masteries.RecordAnswerAsync(user.UserId(), ex.SkillId, correct);
            return Results.Ok(new { correct, correctAnswer = ex.CorrectAnswer,
                explanationVi = ex.ExplanationVi });
        });

        app.MapPost("/writing/evaluate", async (WritingEvalRequest req, IMlClient ml) =>
        {
            try { return Results.Ok(await ml.EvaluateWritingAsync(
                new AweRequest(req.TaskPrompt, req.Essay))); }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).RequireAuthorization();
    }
}
```

Adapt the `using` lines and the `user.UserId()` extension exactly as the existing `PathEndpoints.cs` / `ReviewEndpoints.cs` do (copy their pattern; the extension already exists). If `Skill`'s properties differ (e.g. `CefrLevel` vs `Cefr`), match the actual `LingoRoad/Domain/Skill.cs` property names.

`src/backend/LingoRoad/Data/AppDbContext.cs`: add `public DbSet<Exercise> Exercises => Set<Exercise>();` matching the existing DbSet style in that file.

`src/backend/LingoRoad/Program.cs`: add `app.MapExercises();` next to the existing `app.Map...()` calls.

- [ ] **Step 6: Run the exercise tests, verify PASS**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests --filter ExerciseTests`
Expected: 2 passed.

- [ ] **Step 7: Run the FULL .NET suite, verify no regressions**

Run: `cd C:\Projects\LingoRoad\src\backend; dotnet test LingoRoad.Tests`
Expected: 39 passed (37 baseline + 2 new).

- [ ] **Step 8: Commit (explicit paths)**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add LingoRoad/Domain/Exercise.cs LingoRoad/Endpoints/ExerciseEndpoints.cs LingoRoad/Services/MlClient.cs LingoRoad/Data/AppDbContext.cs LingoRoad/Program.cs LingoRoad.Tests/ExerciseTests.cs LingoRoad.Tests/PlacementTests.cs
git commit -m "feat: exercise generate/submit endpoints and writing evaluation via ML service"
```

---

### Task 3: Submit-replay fix, migration, live check with real Gemini, report samples

**Files:**
- Modify: `src/backend/LingoRoad/Domain/Exercise.cs`, `src/backend/LingoRoad/Endpoints/ExerciseEndpoints.cs`, `src/backend/LingoRoad.Tests/ExerciseTests.cs`
- Create: migration `AddExercises` (generated), `src/backend/ml/reports/samples/exercises.md`, `src/backend/ml/reports/samples/awe.md`

- [ ] **Step 0: Submit idempotency (code-review follow-up — replayable submit inflated mastery)**

Task 2's quality review found that re-POSTing `/exercises/{id}/submit` with the revealed answer re-runs `RecordAnswerAsync` each time, letting a learner ratchet mastery. Fix before generating the migration so the schema change rides along:

1. `Exercise.cs`: add `public DateTime? AnsweredAt { get; set; }` after `CreatedAt`.
2. `ExerciseEndpoints.cs` submit handler: keep grading as-is, but only record mastery on the FIRST submit:

```csharp
var correct = string.Equals(req.Answer.Trim(), ex.CorrectAnswer.Trim(),
    StringComparison.OrdinalIgnoreCase);
if (ex.AnsweredAt is null)
{
    ex.AnsweredAt = DateTime.UtcNow;
    await masteries.RecordAnswerAsync(user.UserId(), ex.SkillId, correct);
    await db.SaveChangesAsync();
}
return Results.Ok(new { correct, correctAnswer = ex.CorrectAnswer,
    explanationVi = ex.ExplanationVi });
```

3. Failing test first in `ExerciseTests.cs` (red: second submit currently changes mastery):

```csharp
[Fact]
public async Task Resubmit_does_not_inflate_mastery()
{
    await AuthAsync();
    var gen = await _client.PostAsJsonAsync("/exercises/generate",
        new { skillCode = "grammar.tenses.present_perfect" });
    var list = await gen.Content.ReadFromJsonAsync<List<ExDto>>();
    await _client.PostAsJsonAsync($"/exercises/{list![0].Id}/submit", new { answer = "has lived" });
    var after1 = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
    var submit2 = await _client.PostAsJsonAsync($"/exercises/{list[0].Id}/submit", new { answer = "has lived" });
    var result2 = await submit2.Content.ReadFromJsonAsync<SubmitDto>();
    Assert.True(result2!.Correct);                       // still graded
    var after2 = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>("/mastery");
    Assert.Equal(System.Text.Json.JsonSerializer.Serialize(after1),
                 System.Text.Json.JsonSerializer.Serialize(after2));   // mastery unchanged
}
```

Run red → implement → `dotnet test LingoRoad.Tests` all green (expect 40) → commit:

```powershell
git add LingoRoad/Domain/Exercise.cs LingoRoad/Endpoints/ExerciseEndpoints.cs LingoRoad.Tests/ExerciseTests.cs
git commit -m "fix: exercise submit records mastery only once (replay guard)"
```

- [ ] **Step 1: Add + apply the EF migration**

```powershell
cd C:\Projects\LingoRoad\src\backend
docker compose up -d db
dotnet ef migrations add AddExercises --project LingoRoad
dotnet ef database update --project LingoRoad
```

Expected: migration files appear under `LingoRoad/Migrations/`, update applies cleanly.

- [ ] **Step 2: Start both services**

```powershell
# terminal 1 (background): ML service with the Gemini key
cd C:\Projects\LingoRoad\src\backend\ml
$env:GEMINI_API_KEY = "<value from src/backend/.claude/tasks/README.md Global Constraints>"
.venv\Scripts\uvicorn lingoroad_ml.serving.app:app --port 8001

# terminal 2 (background): API — MUST use the launch profile (secrets in appsettings.Development.json)
cd C:\Projects\LingoRoad\src\backend\LingoRoad
dotnet run --launch-profile http
```

- [ ] **Step 3: Live check — generate, submit, evaluate**

Register a fresh user, generate for `grammar.conditionals.second` (or any seeded B1 skill), submit one answer, then evaluate one short essay. Vietnamese/UTF-8 bodies: write JSON to a UTF-8 file and use `curl --data-binary "@file"`.

```powershell
# essay body file (UTF-8!)
# { "taskPrompt": "Describe your hometown.", "essay": "My hometown is Da Nang. It have many beautiful beach." }
curl -s -X POST http://localhost:5000/writing/evaluate -H "Authorization: Bearer $tok" -H "Content-Type: application/json" --data-binary "@awe_body.json"
```

Verify: exercises are level-appropriate English with 4 options and Vietnamese explanations; submit returns `correct/correctAnswer/explanationVi` and `/mastery` shows the skill; AWE returns 0–9 scores on the four IELTS criteria with Vietnamese feedback sentences.

- [ ] **Step 4: Save report samples**

- `src/backend/ml/reports/samples/exercises.md` — the generate request, the returned exercise set (with the post-submit revealed answer/explanation), and 1–2 `wordnet_distractors` examples (e.g. for "happy").
- `src/backend/ml/reports/samples/awe.md` — the essay, the scores JSON, and the Vietnamese feedback. (Task-16's evidence checklist expects exactly these two filenames.)

- [ ] **Step 5: Commit + stop services**

```powershell
cd C:\Projects\LingoRoad\src\backend
git add LingoRoad/Migrations ml/reports/samples/exercises.md ml/reports/samples/awe.md
git commit -m "feat: AddExercises migration + exercise/AWE live samples"
```

Stop the uvicorn/dotnet background processes when done.
