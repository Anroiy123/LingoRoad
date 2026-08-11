# Task 1 — Backend question-review API and persistence

## Delivered files

- `src/backend/LingoRoad/Endpoints/ReviewEndpoints.cs`
  - Added `GET /reviews/questions/due?limit=1..10` returning `{ items, totalDue }`.
  - Added read-only `POST /reviews/{id}/check`.
  - Extended grade requests with optional answers, answer-aware rating validation, mastery recording, response rewards, and answer-aware idempotency.
- `src/backend/LingoRoad/Domain/ReviewGradeOperation.cs`
  - Added nullable `SubmittedAnswer` and `Correct` persistence fields.
- `src/backend/LingoRoad/Migrations/20260811052419_AddQuestionReviewGradeAnswers.cs`
  - Adds the two nullable columns; corresponding designer and model snapshot are updated.
- `src/backend/LingoRoad.Tests/QuestionReviewEndpointTests.cs`
  - Eight integration tests covering queue filtering/ordering/cap/isolation, check behavior, grading matrix and atomically persisted effects, replay conflict, legacy grades, and concurrency.

## TDD evidence

### RED

Command:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --filter FullyQualifiedName~QuestionReviewEndpointTests --no-restore
```

Before production code, it compiled and failed 6/7 tests for the expected missing behaviors: `/reviews/questions/due` and `/{id}/check` returned `404 NotFound`; question-card grade accepted a rating-only request (`200 OK`) instead of requiring an answer. The existing manual-card compatibility test was the one passing case.

### GREEN

Focused command after implementation:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --filter FullyQualifiedName~QuestionReviewEndpointTests --no-restore
```

Result: `8 passed, 0 failed`.

Full backend command:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --no-restore
```

Final result: `122 passed, 0 failed`.

Migration model validation also passed:

```powershell
dotnet ef migrations has-pending-model-changes --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj --no-build
```

Result: no pending model changes.

## Self-review

- Queue is an inner join to an owned, wrong lesson exercise with only `mcq`, `cloze`, or `reorder`; missing source, unsupported type, future cards, correct exercises, and other users are excluded.
- Queue projection contains only id/reps/type/stem/options and deserializes options after the database query, preventing translation problems and avoiding correct-answer/explanation fields.
- Check performs no writes and enforces answer, owner, due state, and a supported lesson-mistake source before returning feedback.
- Question grades normalize answers with `Trim` + ordinal case-insensitive comparison, enforce `wrong => 1` and `correct => 2..4`, and keep legacy no-source cards on the existing rating-only path.
- Mastery, FSRS transition, idempotency operation, learning event, and reward ledger entry are all tracked in the same `SaveChangesAsync` call. Existing unique-operation/concurrency recovery remains in place and is exercised for question cards.
- Replay matching includes normalized answer (case-insensitive) as well as card/rating/reps, so a changed answer conflicts rather than reusing a stored result.

## Concerns

- The local EF CLI reports version `10.0.9` while runtime packages are `10.0.10`; migration generation and pending-model validation succeeded, but updating the developer tool would remove that non-blocking warning.

---

## Fix round 1/5

### Review findings addressed

- Source-backed lesson cards that are not supported question types (including valid
  `listening_mcq`) now follow the legacy rating-only grade path. Only an owned,
  wrong, lesson-backed `mcq`, `cloze`, or `reorder` source enters the answer-aware
  grade branch.
- The question queue now obtains `totalDue` with `CountAsync`, then applies ordered
  `Take(limit)` before materializing/deserializing option JSON.
- Tests now assert stored answer/correctness, FSRS `Reps`/`State`/future `Due`,
  mastery decreases after a wrong grade then returns above the neutral baseline
  after a correct grade, and each reward ledger row is exactly 5 XP and 1 coin.

### Compatibility TDD evidence

RED regression test was added before modifying production code:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --filter FullyQualifiedName~Legacy_source_backed_unsupported_lesson_card_still_accepts_rating_only_grade --no-restore
```

Output: `1 failed, 0 passed`; expected `OK`, actual `NotFound`. This reproduced
the reviewed `listening_mcq` source-backed legacy compatibility regression.

GREEN after restricting answer-aware processing to supported question sources:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --filter FullyQualifiedName~QuestionReviewEndpointTests --no-restore
```

Output: `9 passed, 0 failed`.

Final backend verification:

```powershell
dotnet test src/backend/LingoRoad.Tests/LingoRoad.Tests.csproj --no-restore
dotnet ef migrations has-pending-model-changes --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj --no-build
```

Output: `123 passed, 0 failed`; no pending model changes.

### PostgreSQL migration evidence and CI boundary

No local disposable PostgreSQL runtime was available: `docker=unavailable` and
`psql=unavailable`. No user connection strings or existing databases were used.
The Npgsql migration scripts generated successfully and show the exact production
upgrade and rollback SQL:

```powershell
dotnet ef migrations script 20260809154200_AddSavedWordReviewSchedule 20260811052419_AddQuestionReviewGradeAnswers --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj --no-build
dotnet ef migrations script 20260811052419_AddQuestionReviewGradeAnswers 20260809154200_AddSavedWordReviewSchedule --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj --no-build
```

Output respectively begins with `ALTER TABLE "ReviewGradeOperations" ADD
"Correct" boolean`, `ADD "SubmittedAnswer" text`, and with the reciprocal
`DROP COLUMN` statements, each wrapped in `START TRANSACTION`/`COMMIT`.

SQLite integration tests use `EnsureCreated`, so they intentionally cannot apply
Npgsql migration SQL. The CI PostgreSQL job must provision a unique disposable
database and run the following (the CI service teardown drops that database):

```powershell
$env:ConnectionStrings__Default = "Host=postgres;Port=5432;Database=lingoroad_task1_$env:CI_PIPELINE_ID;Username=postgres;Password=postgres"
dotnet ef database update 20260811052419_AddQuestionReviewGradeAnswers --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj
psql $env:ConnectionStrings__Default -c 'SELECT column_name FROM information_schema.columns WHERE table_name = ''ReviewGradeOperations'' AND column_name IN (''Correct'', ''SubmittedAnswer'') ORDER BY column_name;'
dotnet ef database update 20260809154200_AddSavedWordReviewSchedule --project src/backend/LingoRoad/LingoRoad.csproj --startup-project src/backend/LingoRoad/LingoRoad.csproj
psql $env:ConnectionStrings__Default -c 'SELECT column_name FROM information_schema.columns WHERE table_name = ''ReviewGradeOperations'' AND column_name IN (''Correct'', ''SubmittedAnswer'');'
```

Expected CI output is two columns after apply and zero rows after rollback. This
is the remaining environment-only evidence boundary; the generated up/down SQL
and model-drift check passed locally.
