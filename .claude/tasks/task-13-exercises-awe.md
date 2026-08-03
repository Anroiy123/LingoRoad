# Task 13: Adaptive Exercises & AWE — generation, distractors, writing evaluation

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-3, task-10 (MasteryService), task-12 (llm_routes exists). Sprint 3.

**Files:**
- Create: `ml/questgraph_ml/llm/exercises.py`, `ml/questgraph_ml/llm/distractors.py`, `ml/questgraph_ml/llm/awe.py`, `ml/tests/test_exercises.py`, `QuestGraph/Domain/Exercise.cs`, `QuestGraph/Endpoints/ExerciseEndpoints.cs`, `QuestGraph.Tests/ExerciseTests.cs`
- Modify: `ml/questgraph_ml/serving/llm_routes.py`, `ml/requirements.txt` (add `nltk>=3.8`), `QuestGraph/Services/MlClient.cs`, `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`, `QuestGraph.Tests/PlacementTests.cs` (FakeMlClient grows)

**Interfaces:**
- Consumes: `MasteryService.RecordAnswerAsync`, `Skill`, `IMlClient`, `ApiResults.MlUnavailable()`.
- Produces:
  - `IMlClient` gains:
    - `Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)` — `record ExerciseGenRequest(string SkillCode, string SkillName, string Cefr, string Type, int Count)`, `record GeneratedExercise(string Stem, string[] Options, string CorrectAnswer, string? ExplanationVi)`, `record ExerciseGenResponse(List<GeneratedExercise> Exercises)`
    - `Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)` — `record AweRequest(string TaskPrompt, string Essay)`, `record AweScores(double TaskAchievement, double CoherenceCohesion, double LexicalResource, double GrammaticalAccuracy)`, `record AweFeedback(string Sentence, string Issue, string Suggestion)`, `record AweResponse(AweScores Scores, List<AweFeedback> Feedback, string OverallVi)`
  - C#: `Exercise { Guid Id, Guid UserId, int SkillId, string CefrLevel, string Type, string Stem, string OptionsJson, string CorrectAnswer, string? ExplanationVi, DateTime CreatedAt }`; endpoints `POST /exercises/generate` `{ skillCode, type? }` (type defaults `mcq`, cefr = skill's level) → list without answers; `POST /exercises/{id}/submit` `{ answer }` → `{ correct, correctAnswer, explanationVi }` and updates mastery; `POST /writing/evaluate` `{ taskPrompt, essay }` → AWE result (IELTS rubric, Vietnamese feedback — replaces TOEFL11 fine-tune per requirement.md V-6).
  - Python: `POST /llm/exercises` `{"skill_code","skill_name","cefr","type","count"}` → `{"exercises":[{"stem","options","correct_answer","explanation_vi"}]}`; `POST /llm/awe` `{"task_prompt","essay"}` → `{"scores":{...0-9...},"feedback":[{"sentence","issue","suggestion"}],"overall_vi":…}`; `distractors.wordnet_distractors(word, n=3) -> list[str]`.

- [ ] **Step 1: Write failing Python tests**

`ml/tests/test_exercises.py`:

```python
import json
from questgraph_ml.llm.exercises import build_exercise_messages, parse_exercises
from questgraph_ml.llm.awe import build_awe_messages
from questgraph_ml.llm.distractors import wordnet_distractors

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

Setup: `ml/.venv/Scripts/pip install nltk` then `ml/.venv/Scripts/python -c "import nltk; nltk.download('wordnet')"`.
Run: `cd ml; .venv/Scripts/python -m pytest tests/test_exercises.py -v` → FAIL.

- [ ] **Step 2: Implement Python modules, verify pass**

`ml/questgraph_ml/llm/exercises.py`:

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

`ml/questgraph_ml/llm/distractors.py`:

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

`ml/questgraph_ml/llm/awe.py`:

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

Append to `ml/questgraph_ml/serving/llm_routes.py`:

```python
from questgraph_ml.llm import exercises as ex_mod, awe as awe_mod

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

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [ ] **Step 3: Write failing .NET tests**

`QuestGraph.Tests/ExerciseTests.cs` (uses `PlacementFactory`; extend `FakeMlClient` first — see Step 4 for the two new members):

```csharp
using System.Net.Http.Json;

namespace QuestGraph.Tests;

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

Run: `dotnet test QuestGraph.Tests --filter ExerciseTests` → FAIL.

- [ ] **Step 4: Implement .NET side, verify pass**

Add the records and interface members from the Interfaces block to `MlClient.cs`, plus these implementations:

```csharp
public async Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
    => await PostAsync<ExerciseGenRequest, ExerciseGenResponse>("/llm/exercises", req, ct);

public async Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
    => await PostAsync<AweRequest, AweResponse>("/llm/awe", req, ct);
```

Extend `FakeMlClient` in `PlacementTests.cs`:

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

`QuestGraph/Domain/Exercise.cs`:

```csharp
namespace QuestGraph.Domain;

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

`QuestGraph/Endpoints/ExerciseEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

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

`AppDbContext`: `DbSet<Exercise> Exercises`. `Program.cs`: `app.MapExercises();`

Run: `dotnet test QuestGraph.Tests` → PASS.

- [ ] **Step 5: Migration, live check, commit**

```powershell
dotnet ef migrations add AddExercises --project QuestGraph
```

Live check with both services running: generate exercises for `grammar.conditionals.second`, submit an answer, evaluate one short essay. Save one exercise set and one AWE response to `ml/reports/samples/` (report artifacts).

```powershell
git add -A
git commit -m "feat: LLM exercise generation, distractors, and IELTS-rubric AWE"
```
