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
| `AuthTests.cs` | `/auth/register` + `/auth/login` happy path, wrong password → 401, duplicate email → 409 |
| `ExerciseTests.cs` | `/exercises/generate` (answer-leak check), `/exercises/{id}/submit` (grading + mastery update), resubmit idempotency, `/writing/evaluate` proxy |
| `FsrsTests.cs` | Pure `Fsrs.Review` unit tests (interval ordering by grade, `Again`→relearning, stability growth/decay, difficulty clamping) **and** `/reviews/cards` → `/reviews/due` → `/reviews/{id}/grade` end-to-end flow |
| `HealthTests.cs` | `/health` returns `"ok"` |
| `ItemTests.cs` | `/admin/items/import` + `/items` filter-by-skill/cefr, default IRT param assignment, unknown-skill 400 |
| `MasteryTests.cs` | Pure `MasteryCalc.Update` unit tests (raises/lowers estimate, decay toward baseline, `[0,1]` bounds) **and** placement-answer → `/mastery` integration |
| `MlClientTests.cs` | `MlClient` HTTP serialization (snake_case, explicit `item_id` naming) against a stubbed `HttpMessageHandler`; unreachable service → `MlServiceUnavailableException` |
| `PathTests.cs` | Pure `PathBuilder.Build` unit tests (prerequisite ordering, mastered-skill skipping, CEFR ceiling filter, parent-container exclusion, `reason` field) **and** `/path` endpoint smoke test |
| `PlacementTests.cs` | Defines `FakeMlClient` + `PlacementFactory`; full adaptive-test loop via start→answer→result, stop-rule enforcement, unauthenticated 401, ML-down 503; also `CefrMapTests` (θ→CEFR boundary data) |
| `SkillTests.cs` | `/skills`, `/skills/graph`; pure `SkillGraph.TopologicalOrder` ordering unit test |
| `SpeakingTests.cs` | `/speaking/attempts` multipart upload → scores + persisted history via GET |

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
