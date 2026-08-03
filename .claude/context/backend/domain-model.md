# Domain Model — LingoRoad `.NET` API

All configuration is Fluent API in `AppDbContext.OnModelCreating` — no
`[Key]`/`[Required]`-style attributes anywhere in `Domain/`.

## Entities

| File | Type(s) | Shape / notes |
|---|---|---|
| `User.cs` | `User` | `Id` (Guid, `NewGuid()` default), `Email` (unique), `PasswordHash`, `Name?`, `TargetCefr` (default `"B2"`), `CreatedAt` |
| `Skill.cs` | `Skill`, `SkillEdge` | `Skill`: `Id` (int, DB-generated), `Code` (unique, dotted e.g. `grammar.tenses.present_perfect`), `Name`, `NameVi`, `Category` (`grammar\|vocabulary\|reading\|listening\|writing`), `ParentId?` (self-referencing container hierarchy), `CefrLevel`. `SkillEdge`: `PrerequisiteId`, `SkillId` — directed prerequisite edge, composite PK `(PrerequisiteId, SkillId)` |
| `Item.cs` | `Item` | `Id`, `SkillId`, `CefrLevel`, `Type` (`mcq\|cloze\|listening_mcq`), `Stem`, `OptionsJson` (JSON-serialized `string[]`), `CorrectAnswer`, IRT params `A`,`B`,`C` (double), `AudioUrl?`, `Source`, `CreatedAt` |
| `TestSession.cs` | `TestSession`, `Response` | `TestSession`: `Status` state machine `"active"→"completed"`, `Theta`, `ThetaSe` (default 1.0), `StartedAt`, `CompletedAt?`, `ResultCefr?`. `Response`: per-answer IRT trace — `ItemId`, `Answer?`, `Correct`, `ThetaAfter`, `SeAfter`, `AnsweredAt` |
| `Mastery.cs` | `Mastery` | Composite PK `(UserId, SkillId)`, `PCorrect` (default 0.5 — uninformed prior), `UpdatedAt` |
| `ReviewCard.cs` | `Grade` enum, `ReviewCard` | `Grade { Again=1, Hard=2, Good=3, Easy=4 }` — also the wire contract for `GradeRequest.Rating` (`(Grade)req.Rating`). `ReviewCard`: `Stability`, `Difficulty`, `Due`, `LastReview?`, `Reps`, `State` (`"new"→"review"`, or `→"relearning"` on `Again`) |
| `Exercise.cs` | `Exercise` | `AnsweredAt?` null until first submit — drives the submit-idempotency check in `ExerciseEndpoints` |
| `SpeakingAttempt.cs` | `SpeakingAttempt` | `AudioPath` (relative, e.g. `uploads/{guid}.webm`), `Transcript?`, `Total`, `ScoresJson?` (full ML response serialized) |

## Business-rule algorithms (pure static classes — no EF/HTTP deps)

### `MasteryCalc.cs` — mastery update formula
`Update(prior, correct, daysSinceLast)`:
1. Decay toward the 0.5 baseline: `decayed = 0.5 + (prior - 0.5) * exp(-0.03 * max(0, days))` (Ebbinghaus-style, `DecayRate=0.03`/day).
2. EMA toward the observed outcome: `result = clamp(decayed + 0.3 * (target - decayed), 0, 1)` where `target = correct ? 1 : 0`, `LearningRate=0.3`.

Called from `MasteryService.RecordAnswerAsync`, itself called by both
`PlacementEndpoints` (per placement answer) and `ExerciseEndpoints` (on
first submit only).

### `Fsrs.cs` — FSRS-4.5 spaced-repetition scheduler
Hardcoded 17-weight array `W[]`. Key functions:
- `Retrievability(days, stability) = (1 + Factor*days/stability)^Decay`
  (`Decay=-0.5`, `Factor=19/81`).
- `InitStability`/`InitDifficulty` for new cards (difficulty clamped `[1,10]`).
- `NextDifficulty` — mean-reversion toward `InitDifficulty(Easy)` via `W[7]`.
- `RecallStability` vs `ForgetStability` — branches on `grade==Again`.
- `Review(card, grade, now)` mutates the card in place: `Grade.Again` →
  `State="relearning"`, `Due=now+10min`; otherwise → `State="review"`,
  `Due=now+max(stability,1.0) days`.

> The weights are compile-time constants — retuning FSRS requires a code
> change + redeploy, not a config change. Don't add a "quick" runtime
> override without updating this note.

### `PathBuilder.cs` — learning-path generation
`PathStep(Skill, Mastery, Reason)`. `MasteryThreshold = 0.8` (const).
`Build(skills, edges, masteryDict, goalCefr, limit=10)`:
1. Topological order over the prerequisite DAG (`SkillGraph.TopologicalOrder`).
2. Filter out parent/container skills (anything referenced as a `ParentId`).
3. Filter to `CefrMap.Rank(skill.CefrLevel) ≤ CefrMap.Rank(goalCefr)`.
4. Map to `PathStep`, `Reason = "below_threshold"` if a mastery record
   exists, else `"not_started"`.
5. Filter `Mastery < 0.8`, `Take(limit)`.

> Unmastered skills **above** the goal CEFR are silently excluded even if
> they're prerequisites of an in-scope skill — the topological order is
> preserved among what remains, but the filter can hide a real dependency.
> Full theory/alternatives (Greedy vs DP vs RL) in
> `docs/learning-path-optimization.md`.

### `SkillGraph.cs` — topological sort
`TopologicalOrder(skills, edges)` — Kahn's algorithm, ties broken by
`CefrLevel` then `Code`. **Throws `InvalidOperationException("Skill graph
contains a cycle")`** if the result count doesn't match the input count.
Used both at request time (`PathBuilder`) and as a fail-fast seed-data
integrity check in `DbSeeder`.

### `CefrMap.cs` — θ ↔ CEFR mapping
`FromTheta(theta)`: piecewise cutoffs `<-1.5→A1, <-0.5→A2, <0.5→B1,
<1.5→B2, <2.25→C1, else→C2` (asymmetric — the C1 band is narrower than the
others). `Rank(cefr)` = index into `["A1","A2","B1","B2","C1","C2"]`,
**returns `-1` for an unknown string** — not guarded, a typo'd CEFR string
elsewhere would silently rank below everything.

> This mapping must mirror `ml/lingoroad_ml/cefr.py`'s `cefr_from_theta` —
> the two are independently maintained on either side of the HTTP seam. If
> you change one, change the other.

## Data layer (`Data/AppDbContext.cs`)

Fluent config:
| Entity | Config |
|---|---|
| `User` | unique index on `Email` |
| `Skill` | unique index on `Code` |
| `SkillEdge` | composite PK `(PrerequisiteId, SkillId)` |
| `Item` | composite index `(SkillId, CefrLevel)` |
| `Response` | index on `SessionId` |
| `Mastery` | composite PK `(UserId, SkillId)` |
| `ReviewCard` | composite index `(UserId, Due)` |

`Exercise` and `SpeakingAttempt` use convention-only single-column PK
(`Id`), no explicit Fluent config.

### `DbSeeder.cs`
`SeedAsync(db)` is idempotent (`if (await db.Skills.AnyAsync()) return;`).
Reads `Data/Seed/skills.json` from `AppContext.BaseDirectory` (deployed via
`<Content Update="Data\Seed\**" .../>` in the `.csproj`). Two-pass insert:
insert all `Skill` rows → `SaveChangesAsync` (to get generated `Id`s) →
wire `ParentId`/`SkillEdge` by code lookup → `SaveChangesAsync` again →
calls `SkillGraph.TopologicalOrder` purely to fail fast on a seed-data
cycle. Runs on startup only `if (app.Environment.IsDevelopment())`, and
from `TestAppFactory` for every test class.

### Migrations (`Migrations/`), in order
1. `InitialCreate` — empty placeholder (no-op `Up`/`Down`)
2. `AddUsers`
3. `AddSkills`
4. `AddItems`
5. `AddTestSessions`
6. `AddMastery`
7. `AddReviewCards`
8. `AddExercises`
9. `AddSpeakingAttempts`

One migration per feature area, added incrementally as endpoints were
built — matches the `Endpoints/`/entity list exactly.
