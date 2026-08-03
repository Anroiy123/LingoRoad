# Folder Structure — LingoRoad `.NET` API

## Top level (`src/backend/LingoRoad/`)
| Path | Purpose |
|---|---|
| `Program.cs` | Composition root: DI registrations, middleware pipeline, all `app.Map*()` calls |
| `Endpoints/` | One static class per feature area — routes + request/response DTOs |
| `Domain/` | Entities + pure business-rule algorithms (no EF/HTTP dependencies) |
| `Data/` | `AppDbContext`, `DbSeeder`, `Data/Seed/skills.json` |
| `Migrations/` | EF Core migrations, one per feature area, in build order |
| `Services/` | `MlClient` (HTTP to the Python service), `MasteryService`, `TokenService` |
| `wwwroot/` | Static files: listening-item audio under `/audio`, speaking uploads under `/uploads` |
| `appsettings.json` / `appsettings.Development.json` | Config — see `auth-and-integrations.md` for key names |

Sibling: `LingoRoad.Tests/` — see `testing.md`.

## `Endpoints/` — naming and shape
One file per feature area, named `<Feature>Endpoints.cs`:
```
AuthEndpoints.cs       ItemEndpoints.cs       PlacementEndpoints.cs
MasteryEndpoints.cs    ReviewEndpoints.cs     PathEndpoints.cs
ExerciseEndpoints.cs   SpeakingEndpoints.cs   SkillEndpoints.cs
ApiResults.cs           # shared 503 helper only, no Map method
```
Each is `public static class <Feature>Endpoints` with one
`public static void Map<Feature>(this WebApplication app)` extension
method. Request/response DTOs for that feature are declared as
`public record`s at the top of the **same file** — there is no separate
`Dtos/` folder.

Routes are grouped with `app.MapGroup("/prefix")` when a shared prefix +
shared `.RequireAuthorization()` makes sense (`auth`, `placement`,
`reviews`, `path`, `exercises`, `speaking`); `SkillEndpoints`,
`ItemEndpoints`, `MasteryEndpoints` map directly on `app` since their
routes don't share a common auth requirement or prefix.

## `Domain/` — naming and shape
One file per entity or tightly related cluster:
- `TestSession.cs` holds both `TestSession` and `Response`.
- `Skill.cs` holds both `Skill` and `SkillEdge`.
- `ReviewCard.cs` holds both the `Grade` enum and `ReviewCard`.
- Pure algorithm/calculation logic is a **static class**, co-located by
  concern: `Fsrs.cs`, `MasteryCalc.cs`, `PathBuilder.cs`, `SkillGraph.cs`,
  `CefrMap.cs`. These have no EF Core or HTTP dependency — safe to unit
  test in isolation (see `LingoRoad.Tests/FsrsTests.cs`,
  `MasteryTests.cs`, `PathTests.cs`).

Full entity/algorithm catalog: `domain-model.md`.

## `Services/` — naming and shape
One file per service: `<Name>Service.cs` or `<Name>Client.cs`. Interfaces
(`IMlClient`) live in the **same file** as their implementation, not split
into a separate interfaces folder.

## Adding a new endpoint module
Follow the existing pattern exactly:
1. Create `Endpoints/<Feature>Endpoints.cs`:
   ```csharp
   public static class FeatureEndpoints
   {
       public static void MapFeature(this WebApplication app)
       {
           var g = app.MapGroup("/feature").RequireAuthorization(); // if it needs auth
           g.MapGet("/", ...);
           g.MapPost("/", ...);
       }
   }
   ```
2. Add one line in `Program.cs` after the existing `app.Map*()` calls:
   `app.MapFeature();` — call order doesn't currently matter (no route
   conflicts, no ordering-dependent middleware).
3. If it needs a new service, register it in `Program.cs`'s builder
   section (`AddSingleton`/`AddScoped`/`AddHttpClient`, following the
   existing registrations).
4. If it's gated to Development only (like `/admin/items/import`), guard
   the `MapPost`/`MapGet` call itself with an early `if
   (!app.Environment.IsDevelopment()) return;` **inside** the `Map*`
   method — not a runtime check inside the handler. This is a
   registration-time guard: outside Development the route never enters
   the route table, so requests 404 rather than getting an auth error.
5. Add a migration if you added/changed an entity: `dotnet ef migrations
   add <Name> --project src/backend/LingoRoad --startup-project
   src/backend/LingoRoad`, then `dotnet ef database update`.
6. Add tests in `LingoRoad.Tests/<Feature>Tests.cs` using `TestAppFactory`
   (see `testing.md`).

## What's *not* here
No `.editorconfig`, no MVC controllers, no `[Authorize]` attributes, no
`Dtos/`, `Interfaces/`, or `Repositories/` folders — this codebase is
deliberately flat: minimal API + Fluent-configured EF Core + static
algorithm classes, no extra layering.
