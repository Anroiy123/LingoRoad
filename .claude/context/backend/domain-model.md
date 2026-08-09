# Domain Model — LingoRoad `.NET` API

All configuration is Fluent API in `AppDbContext.OnModelCreating` — no
`[Key]`/`[Required]`-style attributes anywhere in `Domain/`.

## Entities

| File | Type(s) | Shape / notes |
|---|---|---|
| `User.cs` | `User`, `UserRoles`, `UserFocusSkill` | `User`: `Id` (Guid, `NewGuid()` default), `Email` (unique, canonicalized lower/trim via check constraint), `PasswordHash`, `Name?`, `TargetCefr` (default `"B2"`), `TargetCefrConfirmed` (bool), `DailyGoalMinutes` (default 30, DB check `BETWEEN 10 AND 120`), `LearningPurpose?`, `StudyReminderEnabled` (default true), `ReminderTime?`, `TimeZone` (default `"Asia/Ho_Chi_Minh"`), `EmailNotifications`, `AppUpdates` (default true), `Role` (default `UserRoles.Learner`), `CreatedAt`. `UserRoles`: `Learner`/`Admin` string consts. `UserFocusSkill`: composite key `(UserId, SkillId)` — learner-selected focus skills, written from `AuthEndpoints` |
| `Skill.cs` | `Skill`, `SkillEdge` | `Skill`: `Id` (int, DB-generated), `Code` (unique, dotted e.g. `grammar.tenses.present_perfect`), `Name`, `NameVi`, `Category` (`grammar\|vocabulary\|reading\|listening\|writing`), `ParentId?` (self-referencing container hierarchy), `CefrLevel`, `IsDeleted` (soft-delete, query-filtered). `SkillEdge`: `PrerequisiteId`, `SkillId` — directed prerequisite edge, composite PK `(PrerequisiteId, SkillId)` |
| `Item.cs` | `Item` | `Id`, `StableId?` (content-bundle natural key), `SkillId`, `CefrLevel`, `Type` (`mcq\|cloze\|listening_mcq`, content bundles also add `reorder`), `Stem`, `OptionsJson` (JSON-serialized `string[]`), `CorrectAnswer`, `ExplanationVi?`, IRT params `A`,`B`,`C` (double), `AudioUrl?`, `Source`, `License?`, `Reviewer?`, `ContentVersion?`, `CreatedAt`, `IsDeleted` (soft-delete, query-filtered) |
| `TestSession.cs` | `TestSession`, `Response` | `TestSession`: `Status` state machine `"active"→"completed"`, `Theta`, `ThetaSe` (default 1.0), `StartedAt`, `CompletedAt?`, `ResultCefr?`, `CurrentItemId?` (FK to `Item`, `Restrict` delete). `Response`: per-answer IRT trace — `SessionId`, `ItemId`, `Answer?`, `Correct`, `ThetaAfter`, `SeAfter`, `NextItemId?`, `CompletedAfter`, `ResultCefrAfter?`, `AnsweredAt` |
| `Mastery.cs` | `Mastery` | Composite PK `(UserId, SkillId)`, `PCorrect` (default 0.5 — uninformed prior), `UpdatedAt` |
| `ReviewCard.cs` | `Grade` enum, `ReviewCard` | `Grade { Again=1, Hard=2, Good=3, Easy=4 }` — also the wire contract for `GradeRequest.Rating` (`(Grade)req.Rating`). `ReviewCard`: `UserId`, `SkillId`, `SourceExerciseId?`/`SourceItemId?` (Guid?, each unique per user — a card traces back to at most one exercise or one placement item), `Front`, `Back`, `Stability`, `Difficulty`, `Due`, `LastReview?`, `Reps`, `State` (`"new"→"review"`, or `→"relearning"` on `Again`) |
| `Exercise.cs` | `Exercise` | `UserId`, `LessonAttemptId?`, `SourceItemId?` (FK `Item`, `Restrict`), `Sequence`, `SkillId`, `CefrLevel`, `Type`, `Stem`, `OptionsJson`, `CorrectAnswer`, `ModelVersion?`, `ExplanationVi?`, `SubmittedAnswer?`, `IsCorrect?`, `CreatedAt`, `AnsweredAt?` — null until first submit, drives the submit-idempotency check in `ExerciseEndpoints` |
| `SpeakingAttempt.cs` | `SpeakingAttempt` | `UserId`, `PromptText`, `Transcript?`, `Total`, `DurationSeconds`, `ModelVersion`, `FeedbackVi?`, `ScoresJson?` (full ML response serialized), `CreatedAt` |
| `RefreshSession.cs` | `RefreshSession`, `SecurityAuditEvent` | `RefreshSession`: `UserId`, `TokenHash` (unique), `FamilyId` (rotation family), `CreatedAt`, `ExpiresAt`, `RevokedAt?` (concurrency token), `ReplacedById?` — refresh-token rotation/reuse-detection record. `SecurityAuditEvent`: `Id` (long), `UserId?` (nullable — anonymized on account deletion), `EventType`, `Detail?`, `CreatedAt` — auth/security event log (e.g. `account_deletion_requested`) |
| `SavedWord.cs` | `SavedWord` | `UserId`, `SkillId`, `Word`, `Definition`, `Note?`, `CreatedAt`, `UpdatedAt?`, `ReviewStage` (default 1), `NextReviewAt` — dictionary "save word" card, scheduled by `SavedWordSchedule` (see below), not FSRS |
| `SavedWordSchedule.cs` | *(algorithm, see below)* | — |
| `ReviewGradeOperation.cs` | `ReviewGradeOperation` | Immutable response snapshot for an idempotent `POST /reviews/cards/{id}/grade` request: `UserId`, `CardId`, `OperationId` (unique per user), `Rating`, `ExpectedReps`, `Due`, `State`, `Stability`, `Difficulty`, `Reps` — replayed verbatim if the same `OperationId` is resubmitted |
| `Lesson.cs` | `LessonStatuses`, `Lesson`, `LessonItem`, `LessonAttempt`, `UserLessonProgress`, `ExerciseAnswerOperation`, `LessonCompletionOperation`, `ContentBundleImport`, `AdminAuditEvent` | `Lesson`: `StableId`/`Slug` (both unique), `Title`, `TitleVi`, `DescriptionVi?`, `SkillId` (FK `Skill`, `Restrict`), `CefrLevel`, `Order`, `ContentVersion`, `ContentChecksum`, `Source`, `License`, `Reviewer`, `IsPublished` (default true), `IsDeleted` (soft-delete, query-filtered), `UpdatedAt`. `LessonItem`: composite PK `(LessonId, ItemId)`, `Order` (unique per lesson). `LessonAttempt`: `UserId`, `LessonId`, `StartOperationId` (unique per user — start idempotency), `Status` (`LessonStatuses.InProgress\|Completed`, concurrency token), `StartedAt`, `CompletedAt?` — DB-enforced single active attempt per `(UserId, LessonId)` via filtered unique index. `UserLessonProgress`: composite PK `(UserId, LessonId)`, `CompletionCount`, `CorrectAnswers`, `TotalAnswers`, `LastCompletedAt?`. `ExerciseAnswerOperation`/`LessonCompletionOperation`: idempotent-response snapshots (same pattern as `ReviewGradeOperation`), keyed unique on `(UserId, OperationId)`. `ContentBundleImport`: `Version` (unique), `Checksum`, `AppliedAt` — one row per applied `content.vN.json` bundle, enforces bundle immutability (see `ContentBundleSeeder.cs` below). `AdminAuditEvent`: `AdminUserId` (FK `User`, `Restrict`), `Action`, `EntityType`, `EntityId`, `Detail?`, `CreatedAt` — written by `AdminEndpoints`' `Audit()` helper on every admin CRUD action, read back via `GET /admin/audit` |
| `Gamification.cs` | `RewardSources`, `RewardLedgerEntry` | `RewardSources`: `LessonCompletion`/`ReviewGrade` string consts (values used as `RewardLedgerEntry.SourceType`/`QuestCode` inputs). `RewardLedgerEntry`: `UserId`, `SourceOperationId` (idempotency key — one ledger row per originating operation), `SourceType`, `SourceEntityId`, `Xp`, `Coins`, `StreakQualified` (bool — counts toward the daily-streak calendar), `QuestCode`, `CreatedAt`. Appended alongside a `LearningEvent` whenever a lesson/review op completes (`LessonEndpoints`); read back by `GamificationService` |
| `Privacy.cs` | `LearningEventTypes`, `LearningEvent`, `ConsentRecord`, `AccountDeletionStatuses`, `AccountDeletionRequest` | `LearningEventTypes`: `AnswerSubmitted\|LessonCompleted\|ReviewGraded\|SpeakingScored` consts. `LearningEvent`: `Id` (long), `EventId` (Guid, unique — external/export identity), `UserId`, `OperationId`, `EventType`, plus nullable context fields (`LessonId`,`LessonAttemptId`,`ExerciseId`,`ItemId`,`SkillId`,`Correct`,`PredictedCorrectness`,`Rating`,`Score`,`LatencyMs`,`CefrLevel`,`ModelVersion`,`ContentVersion`), `OccurredAt` — append-only ML/analytics event stream, unique on `(UserId, OperationId, EventType)`. `ConsentRecord`: `UserId`, `ConsentType`, `PolicyVersion`, `Source`, `Granted`, `RecordedAt` — append-only consent ledger (`POST/GET /privacy/consents`), never updated in place, one new row per consent change. `AccountDeletionRequest`: `UserId` (unique — one active request per user), `UserEmailHash` (SHA-256, survives after `User` row is gone), `RequestedAt`, `ScheduledFor` (grace period, `Privacy:DeletionGraceDays` config, default 7d), `Status` (`Pending\|Completed\|Failed`), `CompletedAt?`, `FailureCode?` |

> **Append-only invariant**: `AppDbContext.SaveChanges*` calls
> `ProtectAppendOnlyRecords()`, which throws `InvalidOperationException`
> if any `LearningEvent` or `ConsentRecord` is `Modified`/`Deleted` in the
> change tracker. This is enforced in code, not just convention — a future
> change that tries to correct/backfill either table in place will throw at
> `SaveChanges` time, not just violate a norm.

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

Used only for `ReviewCard` (skill-level review queue). `SavedWord`
(dictionary vocabulary) uses the separate, much simpler
`SavedWordSchedule.cs` below — the two card types are deliberately not
unified.

### `SavedWordSchedule.cs` — fixed-interval schedule for saved words
Pure static class; gap-based spaced repetition for `SavedWord`, not FSRS
(no grading input). `GapDays = [1, 2, 4, 7]` — represents day 1/3/7/14
checkpoints since first save.
- `InitialDue(createdAt) = createdAt.AddDays(GapDays[0])`.
- `Advance(word, now)`: mutates `word` in place. If `word.ReviewStage` is
  already the final stage (`4`, "day 14"), returns `true` without mutating
  — caller deletes the row (word considered mastered) instead of persisting
  further changes. Otherwise sets `NextReviewAt = now.AddDays(GapDays[stage])`,
  increments `ReviewStage`, returns `false`.

> The anchor for each gap is the actual review moment (rolling `now`), not
> the original `CreatedAt` (absolute) — a late review pushes all subsequent
> checkpoints back rather than the schedule staying fixed to the save date.

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
| `User` | unique index on `Email`; check constraint `Email` = canonical lower/trim form; check constraint `DailyGoalMinutes BETWEEN 10 AND 120` |
| `UserFocusSkill` | composite PK `(UserId, SkillId)`; FKs to `User`/`Skill`, both `Cascade` |
| `RefreshSession` | unique index on `TokenHash`; index `(UserId, FamilyId)`; `RevokedAt` is a concurrency token; FK to `User`, `Cascade` |
| `SecurityAuditEvent` | index on `CreatedAt` |
| `Skill` | unique index on `Code`; query filter `!IsDeleted` |
| `SkillEdge` | composite PK `(PrerequisiteId, SkillId)` |
| `Item` | composite index `(SkillId, CefrLevel)`; unique index on `StableId`; query filter `!IsDeleted` |
| `Response` | index on `SessionId`; unique composite index `(SessionId, ItemId)` |
| `TestSession` | FK `CurrentItemId → Item`, `Restrict` |
| `Mastery` | composite PK `(UserId, SkillId)` |
| `ReviewCard` | composite index `(UserId, Due)`; unique index on `SourceExerciseId`; unique composite index `(UserId, SourceItemId)`; `Reps` is a concurrency token |
| `SavedWord` | composite index `(UserId, CreatedAt)`; composite index `(UserId, NextReviewAt)` |
| `ReviewGradeOperation` | unique composite index `(UserId, OperationId)` |
| `Lesson` | unique index on `StableId`; unique index on `Slug`; query filter `!IsDeleted`; composite index `(SkillId, Order)`; FK `SkillId → Skill`, `Restrict` |
| `LessonItem` | composite PK `(LessonId, ItemId)`; unique composite index `(LessonId, Order)`; FK `LessonId → Lesson`, `Cascade`; FK `ItemId → Item`, `Restrict` |
| `LessonAttempt` | unique composite index `(UserId, StartOperationId)`; unique composite index `(UserId, LessonId, Status)` filtered to `Status = 'in_progress'` (enforces single active attempt); FK `UserId → User`, `Cascade`; FK `LessonId → Lesson`, `Restrict`; `Status` is a concurrency token |
| `UserLessonProgress` | composite PK `(UserId, LessonId)`; FK `UserId → User`, `Cascade`; FK `LessonId → Lesson`, `Cascade` |
| `Exercise` | unique composite index `(LessonAttemptId, SourceItemId)`; unique composite index `(LessonAttemptId, Sequence)`; `AnsweredAt` is a concurrency token; FK `LessonAttemptId → LessonAttempt`, `Cascade`; FK `SourceItemId → Item`, `Restrict` |
| `ExerciseAnswerOperation` | unique composite index `(UserId, OperationId)` |
| `LessonCompletionOperation` | unique composite index `(UserId, OperationId)` |
| `ContentBundleImport` | unique index on `Version` |
| `RewardLedgerEntry` | unique composite index `(UserId, SourceOperationId)`; composite index `(UserId, CreatedAt)`; FK `UserId → User`, `Cascade` |
| `AdminAuditEvent` | composite index `(AdminUserId, CreatedAt)`; FK `AdminUserId → User`, `Restrict` |
| `LearningEvent` | unique composite index `(UserId, OperationId, EventType)`; unique index on `EventId`; composite index `(UserId, OccurredAt)`; composite index `(SkillId, OccurredAt)`; `EventType` max length 50, `CefrLevel` max length 10, `ModelVersion` max length 200, `ContentVersion` max length 100; FK `UserId → User`, `Cascade` |
| `ConsentRecord` | composite index `(UserId, ConsentType, RecordedAt)`; `ConsentType` max length 50, `PolicyVersion` max length 100, `Source` max length 50; FK `UserId → User`, `Cascade` |
| `AccountDeletionRequest` | unique index on `UserId`; composite index `(Status, ScheduledFor)`; `UserEmailHash` max length 64, `Status` max length 20, `FailureCode` max length 100 |

`Exercise` (beyond the above), `SpeakingAttempt`, and a few others use
convention-only single-column PK (`Id`), no further explicit Fluent config.

> **Append-only invariant**: see the callout under `## Entities` —
> `LearningEvent`/`ConsentRecord` rows can only be inserted, never
> `Modified`/`Deleted`, enforced by `AppDbContext.ProtectAppendOnlyRecords()`
> on every `SaveChanges*` override.

### `DbSeeder.cs`
`SeedAsync(db, includeContent = true)` is an **upsert**, not a one-shot
insert — `if (await db.Skills.AnyAsync()) return;` is stale/gone. It loads
`Data/Seed/skills.json` (deployed via `<Content Update="Data\Seed\**" .../>`
in the `.csproj`), builds a `byCode` dictionary from existing `Skill` rows,
and for each seed row either adds a new `Skill` or updates the existing
one's `Name`/`NameVi`/`Category`/`CefrLevel` in place — safe to re-run
against a populated DB. Two-pass: upsert all `Skill` rows → `SaveChangesAsync`
(to get generated `Id`s) → wire `ParentId`/`SkillEdge` by code lookup →
`SaveChangesAsync` again → calls `SkillGraph.TopologicalOrder` purely to
fail fast on a seed-data cycle. If `includeContent`, also calls
`ContentBundleSeeder.SeedAsync(db)`. Runs on startup only
`if (app.Environment.IsDevelopment() && ContentSeed:Enabled != false)` (see
`Program.cs`), or via the `--seed-only` one-shot CLI flag; `TestAppFactory`
calls it for every test class with `includeContent = SeedContent` (a
`protected virtual bool`, default `false` — most tests skip content
seeding for speed).

### `ContentBundleSeeder.cs`
`SeedAsync(db)` reads `Data/Seed/content.v1.json` into a `Bundle` (version,
source, license, reviewer, lessons→items). `Validate(bundle)` enforces
minimums before touching the DB: ≥20 lessons, ≥100 items total, unique
lesson IDs/slugs/orders, CEFR ∈ `{A1,A2,B1,B2}`, item types ⊆
`{mcq,cloze,reorder}` but must cover all three, MCQ options ≥2 and include
the correct answer, reorder options ≥2.

Immutability check: looks up `ContentBundleImport` by `bundle.Version`. If
a prior import exists with a **different** checksum (SHA-256 of the file
with CRLF normalized to LF), **throws** — a given version string can never
change content once applied. If the checksum matches, no-ops (already
applied).

Otherwise upserts `Lesson`/`Item`/`LessonItem` rows keyed by `StableId`
(lesson/item natural key from the JSON) inside one DB transaction. IDs are
deterministic: `StableGuid(naturalId) = Guid(SHA256("lingoroad:" + naturalId)[0..16])`
— the same content file always produces the same entity `Id`s across
environments. Seeded `Item.B` (IRT difficulty) is a fixed CEFR-band lookup
(`A1→-1.5 … B2→1.5`, else `0`), not calibrated. Finishes by inserting a
`ContentBundleImport { Version, Checksum }` row so the next run's
immutability check has something to compare against.

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
10. `HardenPlacementIntegrity`
11. `AddReviewGradeOperations`
12. `AddIdentityProfileSecurity`
13. `AddTargetCefrConfirmation`
14. `AddLessonContentLoop`
15. `EnforceSingleActiveLessonAttempt`
16. `AddDashboardGamification`
17. `AddAdminContentManagement`
18. `HardenSpeakingAudioRetention`
19. `AddPrivacyLearningLifecycle`
20. `AddVocabCardsAndReviewExplanation`
21. `AddSavedWords`
22. `AddReviewCardSourceItem`
23. `AddSavedWordReviewSchedule`

One migration per feature area, added incrementally as endpoints were
built — matches the `Endpoints/`/entity list exactly.
