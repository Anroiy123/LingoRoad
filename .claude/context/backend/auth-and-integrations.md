# Auth & Integrations — LingoRoad `.NET` API

## Auth flow
- **Register/login**: `Endpoints/AuthEndpoints.cs`. Passwords hashed with
  `BCrypt.Net.BCrypt.HashPassword` (min length 8 enforced server-side);
  login verifies with `BCrypt.Net.BCrypt.Verify`.
- **JWT issuance**: `Services/TokenService.cs` — `TokenService.CreateToken(user)`
  builds a `JwtSecurityToken`: issuer from config `Jwt:Issuer`, symmetric
  HMAC-SHA256 signing key from config `Jwt:Secret`, claims
  `ClaimTypes.NameIdentifier=user.Id` + `ClaimTypes.Email`, **7-day expiry**.
- **Reading the caller's identity**: `ClaimsPrincipal.UserId()` (extension
  in `TokenService.cs`) parses `NameIdentifier` into a `Guid` — used in
  every authenticated handler to scope queries to the caller. There is no
  refresh-token flow; a client just re-authenticates after 7 days.
- **Gating routes**: **minimal-API `.RequireAuthorization()`** only — no
  `[Authorize]` attributes anywhere (this is minimal API, not MVC).
  Chained on `MapGroup(...)` for `placement`, `reviews`, `path`,
  `exercises`, `speaking`; per-route for `mastery` and `/writing/evaluate`.
  Unauthenticated requests to a protected route get 401 automatically from
  the JWT bearer handler — no custom 401 handling needed.
- **Unauthenticated routes**: `/health`, `/auth/*`, `/skills`,
  `/skills/graph`, `GET /items`, `POST /admin/items/import` (Dev-only, and
  notably has **no auth check at all**, not even in Development — see
  `folder-structure.md` for the registration-time gating mechanism).
- **Config location**: `Jwt:Issuer` and `Jwt:Secret` live only in
  `appsettings.Development.json` — **not** in base `appsettings.json`, so
  Production would need these supplied out-of-band (environment variables,
  user-secrets, etc.). The checked-in dev value is a placeholder, not a
  real secret.
- **Admin role / bootstrap**: `User.Role` is `Learner` or `Admin`
  (`UserRoles`); `Program.cs` registers an `"Admin"` authorization policy
  (`RequireRole("Admin")`) that every `/admin/*` route chains via
  `.RequireAuthorization("Admin")`. To get an admin account, set
  `BootstrapAdmin:Email` / `BootstrapAdmin:Password` (password ≥12 chars,
  valid email) in `appsettings.Development.json` — already set in this repo
  to `admin@lingoroad.dev` / `LingoRoadAdmin123!`. `Services/AdminBootstrapper.cs`
  runs on every Development-environment startup (`Program.cs`, before
  `app.Run()`) and creates-or-promotes that user to `Role=Admin`; if either
  key is unset it's a no-op. `LingoRoad.Tests.TestAppFactory` blanks both
  keys via `UseSetting(...)` so the test host's DB is never touched at
  startup by this — a real footgun if a future startup-time config key
  skips that override (see `testing.md`).

## `MlClient` — the fail-soft boundary to the Python service

Registration (`Program.cs`):
```csharp
builder.Services.AddHttpClient<IMlClient, MlClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["MlService:BaseUrl"] ?? "http://localhost:8001");
    c.Timeout = TimeSpan.FromSeconds(30);
});
```
Base URL from config key `MlService:BaseUrl` (set in
`appsettings.Development.json`); falls back to `http://localhost:8001` in
code if the key is absent. **Flat 30s timeout, no retry policy (no
Polly), no per-call override.**

**JSON convention**: `MlClient.Json` static `JsonSerializerOptions` uses
`PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower` (case-insensitive)
so C# PascalCase DTOs auto-convert to the Python side's snake_case (e.g.
`NextItemId` ⇄ `next_item_id`). A few DTOs still need explicit
`[JsonPropertyName]` where the policy wouldn't derive the right name
(`CatCandidate.ItemId → "item_id"`, `SpeakingScoreResponse.FeedbackVi →
"feedback_vi"`).

**The fail-soft mechanism, exactly**: every `IMlClient` method funnels
through a helper that wraps the HTTP call:
```csharp
try { ... EnsureSuccessStatusCode() ... }
catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
{
    throw new MlServiceUnavailableException(e);
}
```
`TaskCanceledException` is what `HttpClient` throws on timeout, so both
"service down" (`HttpRequestException`) and "service too slow" (30s
timeout) collapse into one exception type. Endpoints catch **only**
`MlServiceUnavailableException` and call `ApiResults.MlUnavailable()` → 503
`{"error":"ml_service_unavailable"}`. Any other exception (e.g. malformed
JSON in a 200 response) is **not** treated as fail-soft — it propagates as
an unhandled 500.

**When adding a new ML-backed endpoint**: add a method to `IMlClient`/
`MlClient` following the existing pattern (`CatSelectAsync`,
`AdvisorAsync`, `GenerateExercisesAsync`, `EvaluateWritingAsync`,
`ScoreSpeakingAsync`), then `catch (MlServiceUnavailableException) {
return ApiResults.MlUnavailable(); }` in the endpoint handler — copy this
verbatim rather than inventing a new error shape.

## Other `Services/`
- **`MasteryService.cs`** (scoped) — `RecordAnswerAsync(userId, skillId,
  correct)`: composite-PK lookup on `Masteries` (creates a new
  `Mastery{PCorrect=0.5}` if missing), computes `days =
  (UtcNow - m.UpdatedAt).TotalDays`, calls `MasteryCalc.Update`, saves.
- **`TokenService.cs`** (singleton) — see Auth flow above.

## Config key reference
| Section | Keys | File |
|---|---|---|
| Logging | `Logging:LogLevel:Default`, `Logging:LogLevel:Microsoft.AspNetCore` | both |
| Hosting | `AllowedHosts` | `appsettings.json` |
| Database | `ConnectionStrings:Default` (Npgsql) | `appsettings.Development.json` only |
| Auth | `Jwt:Issuer`, `Jwt:Secret` | `appsettings.Development.json` only |
| Admin bootstrap | `BootstrapAdmin:Email`, `BootstrapAdmin:Password` | `appsettings.Development.json` only; no-op if either is unset |
| ML integration | `MlService:BaseUrl` | `appsettings.Development.json`, with a code fallback |

No `appsettings.Production.json` exists in the repo. No CORS policy is
registered anywhere in `Program.cs` — relevant once a browser client other
than same-origin is built (the proposed React SPA).
