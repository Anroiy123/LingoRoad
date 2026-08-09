# Testing — LingoRoad `.NET` API

Framework: xUnit + `Microsoft.AspNetCore.Mvc.Testing` +
`Microsoft.EntityFrameworkCore.Sqlite` + coverlet. Global
`<Using Include="Xunit" />` — no `using Xunit;` needed per file.

## `TestAppFactory.cs`
Extends `WebApplicationFactory<Program>`. **Not the real Postgres DB** —
replaces the `AppDbContext` options registration with an **in-memory
SQLite** connection (`DataSource=:memory:`, held open for the fixture's
lifetime). Calls `Database.EnsureCreated()` (not migrations — schema comes
straight from the current EF model, migration history is irrelevant to
tests) and runs `DbSeeder.SeedAsync` synchronously, so every test class
gets the full seeded skill graph for free. Connection disposed in the
`Dispose(bool)` override.

`PlacementFactory : TestAppFactory` (defined inline in
`PlacementTests.cs`, not its own file) additionally swaps `IMlClient` for
a hand-rolled `FakeMlClient`:
- `CatSelectAsync` returns `theta = 0.1*n`, `se = 1/sqrt(n+1)` —
  deterministic SE decay so the ≥8-items/SE<0.35 stop rule is exercisable.
- A `Throw` flag simulates "ML service down" for 503 tests.
- Other methods return fixed canned responses (fixed writing/speaking
  scores). `GenerateExercisesAsync` returns `req.Count` items — the first is
  always the fixed correct-answer `"has lived"` exercise (existing tests
  index `[0]`), any additional ones are distinguishable filler.

`ContentFactory : TestAppFactory` (defined inline in `LessonTests.cs`, not
its own file) overrides `SeedContent => true`, so `ConfigureWebHost`'s
`ContentSeed:Enabled` setting turns on the real content-bundle seed
(20 lessons / 100 items) instead of the bare skill graph. Shared by
`LessonTests.cs` itself and by `DashboardTests.cs`, which both need real
lesson/item rows to exercise `/path/today`, `/lessons/*`, and `/dashboard`.

`TestAuth.cs` is a shared helper, not a test file: `TestAuth.ClientAsync(factory, role = UserRoles.Admin)`
inserts a `User` row directly (bypassing `/auth/register`) and mints a
token via `TokenService`, returning an already-authorized `HttpClient` —
used by role-gated test classes (e.g. admin endpoints) that just need a
logged-in user of a given role without caring about the register flow.

**Pattern for a new feature's tests**: use plain `TestAppFactory` unless
you need to control ML responses, in which case add a similar factory
subclass (or extend `PlacementFactory`'s pattern) rather than hitting the
real Python service from a `.NET` test.

**Footgun**: `WebApplicationFactory<Program>` runs in the `Development`
environment, so it loads `appsettings.Development.json` for real. Any
config key that's read during the pre-`app.Run()` startup block in
`Program.cs` (DB seed, `AdminBootstrapper`, …) executes against the test
host's DB too — including `HealthTests`' deliberately-unreachable-DB
factory, which expects startup to succeed and only `/ready` to fail.
`TestAppFactory.ConfigureWebHost` explicitly blanks such keys
(`ContentSeed:Enabled`, `BootstrapAdmin:Email`/`Password`) via
`UseSetting(...)`; do the same for any new startup-time config key, or a
seemingly unrelated dev-config change can crash every test host.

## Test file map
| File | Covers |
|---|---|
| `AdminTests.cs` | `/admin/*` role gating, skills/items/lessons CRUD + relationship-blocked delete, import validate/apply/replay/idempotency, analytics + audit, `/admin/users` list (search/role/pagination) + `/admin/users/{id}` (profile/mastery/activity/404) |
| `AdminGenerateItemsTests.cs` | `/admin/items/generate` via `PlacementFactory`: persists items with correct IRT/source fields, unknown-skill/unsupported-type validation, ML-down → 503 with no rows persisted, admin-role gating |
| `AuthTests.cs` | `/auth/register` + `/auth/login` happy path, wrong password → 401, duplicate email → 409, email trim/case-normalization, invalid-email rejection (`Theory`); `/auth/refresh` rotation + reuse-of-old-token revokes the whole family, concurrent refresh of the same token is fail-closed (one 200, one 401, the winner's new token also gets revoked); `PATCH /auth/me` profile update (`targetCefr` + `targetCefrConfirmed`, `dailyGoalMinutes`, `focusSkillIds`, reminder/notification prefs); `/auth/change-password` revokes all refresh sessions; `/auth/logout` revokes the supplied refresh token |
| `DashboardTests.cs` | `/dashboard` + `/gamification/me` + `/quests` via `ContentFactory` (real seeded content): name/CEFR/goal/mastery/weak-strong-skills/today-lesson/xp/due-reviews fields on a fresh user, zeroed gamification state, quest codes (`daily_lesson`/`daily_review`/`daily_xp`) all incomplete |
| `ExerciseTests.cs` | `/exercises/generate` (answer-leak check), `/exercises/{id}/submit` (grading + mastery update), resubmit idempotency, `/writing/evaluate` proxy |
| `FsrsTests.cs` | Pure `Fsrs.Review` unit tests (interval ordering by grade, `Again`→relearning, stability growth/decay, difficulty clamping) **and** `/reviews/cards` → `/reviews/due` → `/reviews/{id}/grade` end-to-end flow, `/reviews/mistakes` (returns only wrong-answer cards regardless of due date), grade idempotency/conflict handling (`review_not_due`, stale `expectedReps`, concurrent same-operation grading is safe) |
| `HealthTests.cs` | `/health` returns `"ok"` |
| `ItemTests.cs` | `/admin/items/import` + `/items` filter-by-skill/cefr, default IRT param assignment, unknown-skill 400 |
| `LessonTests.cs` | Defines `ContentFactory`; `ContentBundleTests` (seeded bundle has 20 lessons/100 items across cloze/mcq/reorder, reseed is idempotent, checksum is line-ending-independent) **and** `LessonEndpointTests` covering `/lessons/{id}/attempts` start/resume idempotency, `/lesson-attempts/{id}/complete` (early-completion 409, idempotent replay, reward/quest side effects, `reviewCardsCreated` count), `/exercises/{id}/submit` resubmit-same-answer idempotency, concurrent start/submit/complete race safety (one attempt, one mastery update, one progress row), and retrying a failed lesson doesn't duplicate the mistake review card |
| `MasteryTests.cs` | Pure `MasteryCalc.Update` unit tests (raises/lowers estimate, decay toward baseline, `[0,1]` bounds) **and** placement-answer → `/mastery` integration |
| `MlClientTests.cs` | `MlClient` HTTP serialization (snake_case, explicit `item_id` naming) against a stubbed `HttpMessageHandler`; unreachable service → `MlServiceUnavailableException` |
| `MlFeatureRolloutTests.cs` | Pure `MlFeatureRollout.IsEnabled` unit tests: Production defaults disabled / Development defaults enabled, percentage-cohort assignment is stable for the same user id |
| `PathTests.cs` | Pure `PathBuilder.Build` unit tests (prerequisite ordering, mastered-skill skipping, CEFR ceiling filter, parent-container exclusion, `reason` field) **and** `/path` endpoint smoke test |
| `PlacementTests.cs` | Defines `FakeMlClient` + `PlacementFactory`; full adaptive-test loop via start→answer→result, stop-rule enforcement, unauthenticated 401, ML-down 503; choice-only item filtering (cloze items excluded from CAT selection); answer integrity hardening — rejects an item not issued for the session (`item_not_issued` 409), replaying the same answer is idempotent while changing it 409s (`answer_already_recorded`), an ML failure mid-answer persists neither the response nor mastery, a user cannot answer another user's session (404); also `CefrMapTests` (θ→CEFR boundary data) |
| `PrivacyTests.cs` | `/privacy/consents` create; `/privacy/export` (zip containing the caller's own data, excludes `correctAnswer`/`passwordHash`/`tokenHash`/`audioPath`); `ConsentRecord`/`LearningEvent` are append-only (mutating and saving throws); `DELETE /auth/me` is idempotent and queues a deletion request whose `PrivacyDeletionService.ProcessDueAsync` purges the user + learning events and anonymizes related audit events; `DataRetentionService.ProcessAsync` purges expired security-audit events and completed deletion receipts while preserving learning history |
| `SavedWordTests.cs` | Pure `SavedWordScheduleTests` unit tests for `SavedWordSchedule.InitialDue`/`Advance` (initial due = +1 day, rolling stage gaps of 2/4/7 days, `Advance` on the final stage returns `true`/mastered and leaves the word untouched) **and** `SavedWordEndpointTests` covering `POST /words` (create + unknown-skill 400 + initial stage/due), `GET /words` (newest-first, per-user isolation, `IsDue` annotation, `?due=true` filter), `PATCH /words/{id}` (note-only update, 404 on missing/other-user), `DELETE /words/{id}` (idempotent 404 on second delete, cross-user 404), `POST /words/{id}/review` (advances stage + due date, deletes the word after the final stage, 404 on missing/other-user) |
| `SkillTests.cs` | `/skills`, `/skills/graph`; pure `SkillGraph.TopologicalOrder` ordering unit test |
| `SpeakingTests.cs` | `/speaking/attempts` multipart upload → scores + persisted history via GET, via `PlacementFactory`; rejects declared/actual MIME mismatch (`audio_signature_mismatch`) and over-duration audio (`audio_too_long`); audio-retention hardening — scores are persisted without the raw audio (`ScoresJson` never contains an audio path) |

## Running
```powershell
dotnet test src/backend
```
No CI wires this in currently (no `.github/workflows/`) — developer-run
only. Follow the existing split when adding tests for a new feature: pure
algorithm logic gets its own `*Tests.cs` class with no `TestAppFactory`
dependency; endpoint behavior gets an `IClassFixture<TestAppFactory>` (or
a custom factory subclass) integration test in the same file, matching how
`FsrsTests.cs`, `MasteryTests.cs`, and `PathTests.cs` each mix both styles.
