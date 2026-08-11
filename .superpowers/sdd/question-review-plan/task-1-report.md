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
