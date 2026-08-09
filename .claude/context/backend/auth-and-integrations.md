# Auth & Integrations — LingoRoad `.NET` API

## Auth flow
- **Register/login**: `Endpoints/AuthEndpoints.cs`. Passwords hashed with
  `BCrypt.Net.BCrypt.HashPassword` (min length 8, max 128, enforced
  server-side); login verifies with `BCrypt.Net.BCrypt.Verify`.
- **JWT issuance**: `Services/TokenService.cs` — `TokenService.CreateAccessToken(user)`
  (`CreateToken` is a one-line wrapper kept for the same purpose) builds a
  `JwtSecurityToken`: issuer from config `Jwt:Issuer`, symmetric HMAC-SHA256
  signing key from config `Jwt:Secret`, claims `ClaimTypes.NameIdentifier=
  user.Id`, `ClaimTypes.Email`, **and `ClaimTypes.Role=user.Role`** (this is
  what lets the `"Admin"` policy check the role straight off the token —
  see Admin role/bootstrap below). **Expiry is 15 minutes**, configurable
  via `Jwt:AccessTokenMinutes` (`15` in both `appsettings.json` and
  `appsettings.Development.json`) — **not** the 7-day expiry this doc used
  to describe. Short-lived access tokens are paired with the refresh-token
  rotation flow below, not with re-login.
- **Reading the caller's identity**: `ClaimsPrincipal.UserId()` (extension
  in `TokenService.cs`) parses `NameIdentifier` into a `Guid` — used in
  every authenticated handler to scope queries to the caller.
- **Gating routes**: **minimal-API `.RequireAuthorization()`** only — no
  `[Authorize]` attributes anywhere (this is minimal API, not MVC).
  Chained directly on `MapGroup(...)` for `speaking`, `words`, `reviews`,
  `privacy`, `path`, `exercises`, `dictionary`, `placement`. Some newer
  route files (`DashboardEndpoints.cs`, `LessonEndpoints.cs`) instead call
  `.RequireAuthorization()` per-route rather than on a shared group — same
  effect, just don't assume a whole file's routes share one gate. Also
  per-route: `mastery` (single route, `MasteryEndpoints.cs`),
  `/writing/evaluate` (mapped at `app` level, bypassing the `/exercises`
  group), and `/auth/me` (GET/PATCH), `/auth/change-password`,
  `DELETE /auth/me`. Unauthenticated requests to a protected route get 401
  automatically from the JWT bearer handler — no custom 401 handling
  needed.
- **Unauthenticated routes**: `/health`, `/ready`, `/auth/register`,
  `/auth/login`, `/auth/refresh`, `/auth/logout`, `/skills`,
  `/skills/graph`, `GET /items`. Everything under `/admin/*` — including
  content import, now at `/admin/imports/validate` + `/admin/imports` —
  requires the `"Admin"` policy; the `POST /admin/items/import` route this
  doc used to flag as having "no auth check at all, not even in
  Development" **no longer exists in the code**.
- **Account-deletion-pending JWT gate** (`Program.cs`, `OnTokenValidated`):
  after parsing `userId` from the `NameIdentifier` claim, **every**
  authenticated request re-queries whether the user still exists and
  whether they have a pending `AccountDeletionRequest`
  (`Domain.AccountDeletionStatuses.Pending`) — one extra indexed query per
  request (`AccountDeletionRequests.UserId` has a unique index, see
  `Data/AppDbContext.cs`), not just at login. Outcomes:
  - user row gone → `context.Fail("user_not_found")`.
  - a pending deletion request exists → `context.Fail("account_deletion_pending")`
    **unless** the request is `DELETE /auth/me` — the one route a
    pending-deletion user is still allowed to hit (it's idempotent; see
    `PrivacyEndpoints.RequestDeletionAsync`, which just returns the
    existing request if one is already pending).
  - Either failure surfaces to the caller as a plain 401, same as an
    expired/invalid signature — there's no distinct response body for
    "your account is scheduled for deletion."
- **Config location**: `Jwt:Issuer` and `Jwt:Secret` live only in
  `appsettings.Development.json` — **not** in base `appsettings.json`, so
  Production must supply these out-of-band (env vars, user-secrets, etc.);
  enforced at startup, see "CORS & production config gate" below.
  `Jwt:AccessTokenMinutes` **is** in both files (code fallback `15` if
  absent entirely). The checked-in dev secret is a placeholder, not a real
  secret.
- **Admin role / bootstrap**: `User.Role` is `Learner` or `Admin`
  (`UserRoles`); `Program.cs` registers an `"Admin"` authorization policy
  (`RequireRole("Admin")`) that every `/admin/*` route chains via
  `.RequireAuthorization("Admin")`. To get an admin account, set
  `BootstrapAdmin:Email` / `BootstrapAdmin:Password` (password ≥12 chars,
  valid email) — already set in `appsettings.Development.json` to
  `admin@lingoroad.dev` / `LingoRoadAdmin123!`. `Services/AdminBootstrapper.cs`
  creates-or-promotes that user to `Role=Admin` and logs a
  `SecurityAuditEvent{EventType="admin_bootstrapped"}`; a no-op only if
  **both** keys are unset (if only one is set, it throws at startup).
  **Correction to this doc's prior claim**: `Program.cs` calls
  `AdminBootstrapper.BootstrapAsync` **unconditionally** on every startup
  (not gated by `IsDevelopment()`, unlike the `DbSeeder.SeedAsync` call
  right above it which *is* Dev-gated), and `AdminBootstrapper` itself has
  no environment check either. It only behaves as "Development-only" today
  because the `BootstrapAdmin:*` keys live solely in
  `appsettings.Development.json` — if those keys were ever set via env
  vars in Production, this would silently create/promote an admin account
  there too. `LingoRoad.Tests.TestAppFactory` blanks both keys via
  `UseSetting(...)` so the test host's DB is never touched at startup by
  this — a real footgun if a future startup-time config key skips that
  override (see `testing.md`).

## Refresh tokens & session rotation
`RefreshSession` (`Domain/RefreshSession.cs`) is the source of truth for
refresh tokens; there's no JWT-format refresh token, only an opaque random
one.

- **Issuance**: `TokenService.CreateRefreshToken()` — 48 random bytes,
  base64. Only the SHA-256 hash is stored (`TokenService.HashRefreshToken`,
  hex string) in `RefreshSession.TokenHash` (unique index) — the raw token
  is returned to the client exactly once, in the
  `{ token, accessToken, refreshToken }` body from `/auth/register`,
  `/auth/login`, and `/auth/refresh`.
- **Family**: every `RefreshSession` carries a `FamilyId` (indexed with
  `UserId`, not unique — deliberately, since a family holds many rows over
  time). Login/register starts a **new** family (`Guid.NewGuid()`); every
  subsequent `/auth/refresh` rotation carries the **same** `FamilyId`
  forward. A family is the chain of tokens descending from one login.
- **Rotation** (`POST /auth/refresh`): looks up the session by
  `TokenHash`. If found, not revoked, and not expired (`ExpiresAt`, 30
  days from issuance), it revokes the presented session
  (`RevokedAt = now`, `ReplacedById = <new session id>`) and inserts one
  replacement row in the same family — one `SaveChangesAsync`.
- **Reuse detection**: if a presented token's session is **already**
  revoked, that's treated as token theft/reuse. The handler revokes
  **every** still-live session in that `(UserId, FamilyId)` pair (bulk
  `ExecuteUpdateAsync`), logs `SecurityAuditEvent{EventType=
  "refresh_reuse_detected"}`, and returns 401 — forcing the whole chain to
  re-login, not just the caller. The same branch also fires when two
  concurrent `/refresh` calls race: `RefreshSession.RevokedAt` is
  configured `.IsConcurrencyToken()` (`AppDbContext.OnModelCreating`), so
  the loser of the race gets a `DbUpdateConcurrencyException` on save,
  caught and handled identically (family-wide revoke + audit event + 401)
  rather than surfacing as a 500.
- **Logout** (`POST /auth/logout`): revokes only the **one** presented
  session — distinct from reuse detection, which revokes the whole family.
- **Password change** (`POST /auth/change-password`): revokes **all**
  refresh sessions for the user across **every** family (not just the
  current one), forcing re-login on every device, and logs
  `SecurityAuditEvent{EventType="password_changed"}`.
- **Rate limiting**: `/auth/refresh` and `/auth/logout` both carry
  `.RequireRateLimiting("refresh")` (10/min per IP by default); `/auth/register`
  and `/auth/login` carry `"auth-write"` instead (5/min per IP) — see Rate
  limiting below.

## Security audit events
`SecurityAuditEvent` is defined in `Domain/RefreshSession.cs` (despite the
file name, it holds both `RefreshSession` and `SecurityAuditEvent`): `Id`,
nullable `UserId`, `EventType`, nullable `Detail`, `CreatedAt` (only
indexed column — no index on `EventType` or `UserId`).

| `EventType` | Written from | `UserId` set? | `Detail` |
|---|---|---|---|
| `login_failed` | `AuthEndpoints.cs` `/auth/login`, bad email or password | no (pre-auth) | normalized email, truncated to 254 chars |
| `login_succeeded` | `AuthEndpoints.cs` `/auth/login` | yes | — |
| `refresh_reuse_detected` | `AuthEndpoints.cs` `/auth/refresh` — both the direct revoked-token check and the concurrency-race catch branch | yes | — |
| `password_changed` | `AuthEndpoints.cs` `/auth/change-password` | yes | — |
| `account_deletion_requested` | `PrivacyEndpoints.cs` `RequestDeletionAsync` (`DELETE /auth/me`) | yes | — |
| `admin_bootstrapped` | `Services/AdminBootstrapper.cs`, every startup where the bootstrap keys are set | yes | — |

- **No endpoint reads `SecurityAuditEvent`** (verified — the only queries
  against `db.SecurityAuditEvents` anywhere are the retention purge and
  the account-deletion anonymization below; no `.Where`/`.ToListAsync` for
  display exists). This is unlike `AdminAuditEvent`, a separate entity
  that `GET /admin/audit` does expose. Rows are write-only until retention
  deletes them or someone queries the DB directly.
- **Retention**: `Services/PrivacyServices.cs` → `DataRetentionService`,
  run hourly by the `PrivacyMaintenanceWorker` background service
  (`AddHostedService`, registered except when `IsEnvironment("Testing")`).
  Deletes rows older than `Privacy:SecurityLogRetentionDays` (default 90,
  clamped 1–365).
- **Account deletion**: `PrivacyDeletionService.DeleteLearnerDataAsync`
  does **not** delete a deleted user's `SecurityAuditEvent` rows — it nulls
  out `UserId` on them (anonymize, not erase), preserving the audit trail
  without linking it back to a since-deleted account.

> ⚠️ Undocumented — verify this: no comment or test states the intended
> consumer of this log (e.g. a planned admin security view, or export-only
> for incident response). Treat it as write-only infrastructure until a
> reader exists.

## Rate limiting
`Program.cs`, `AddRateLimiter` — one global limiter plus three named
policies, all `FixedWindowRateLimiterOptions` (1-minute window,
`QueueLimit = 0` → rejections are immediate, never queued),
`RejectionStatusCode = 429`.

| Policy | Partition key | Default limit | Config key | Applied to |
|---|---|---|---|---|
| *(global, unnamed)* | authenticated → `NameIdentifier` claim; else client IP | 120/min authenticated, 60/min anonymous | `RateLimits:Authenticated`, `RateLimits:Anonymous` | every request (`app.UseRateLimiter()`, no opt-out) |
| `"auth-write"` | client IP | 5/min | `RateLimits:AuthWrite` | `POST /auth/register`, `POST /auth/login` |
| `"refresh"` | client IP | 10/min | `RateLimits:Refresh` | `POST /auth/refresh`, `POST /auth/logout` |
| `"ml-upload"` | authenticated → `NameIdentifier` claim; else client IP | 10/min | `RateLimits:MlUpload` | `POST /speaking/attempts`, `POST /path/advisor`, `POST /exercises/generate`, `POST /writing/evaluate`, `POST /dictionary/lookup`, `POST /admin/items/generate` |

A named policy layers **on top of** the global limiter, not instead of it
— e.g. a request to `/auth/login` is checked against both the global
limiter and `"auth-write"`. `.RequireRateLimiting(...)` is chained
per-route, not per-`MapGroup`, so check each `Endpoints/*.cs` handler
directly (`grep RequireRateLimiting`) rather than assuming a whole group
shares a policy — e.g. `POST /exercises/{id}/submit` (same file as
`/exercises/generate`) carries **no** rate-limit policy at all, because it
doesn't call the ML service.

## CORS & production config gate
- **CORS**: `Program.cs` `AddCors` registers a default policy from
  `Cors:AllowedOrigins` (string array config; `AllowAnyHeader().AllowAnyMethod()`
  for the listed origins). Empty/absent → the policy is still registered
  but has no origins added, so it behaves as effectively no cross-origin
  access. `app.UseCors()` runs before `UseAuthentication()`/
  `UseRateLimiter()`. Dev config sets it to `["http://localhost:5173"]`
  (the admin CMS's Vite dev server).
- **Fail-fast in Production**: when `IsProduction()` and **not**
  `IsEnvironment("Testing")`, `Program.cs` throws
  `InvalidOperationException` at startup — before any DI registration —
  if any of these are missing or too short:

  | Key | Constraint |
  |---|---|
  | `ConnectionStrings:Default` | non-empty |
  | `Jwt:Issuer` | non-empty |
  | `Jwt:Secret` | ≥32 chars |
  | `MlService:BaseUrl` | non-empty |
  | `MlService:InternalToken` | ≥32 chars |
  | `Storage:TempPath` | non-empty |
  | `Cors:AllowedOrigins` | array, length > 0 |

  There's still no `appsettings.Production.json` in the repo — this list
  is exactly what a real Production deploy must supply out-of-band (env
  vars, secrets manager, etc.) or the app refuses to start.

## `MlClient` — the fail-soft boundary to the Python service

Registration (`Program.cs`):
```csharp
builder.Services.AddSingleton<MlCircuitBreaker>();
...
builder.Services.AddHttpClient<IMlClient, MlClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["MlService:BaseUrl"] ?? "http://localhost:8001");
    c.Timeout = Timeout.InfiniteTimeSpan;
    var internalToken = builder.Configuration["MlService:InternalToken"];
    if (!string.IsNullOrWhiteSpace(internalToken))
        c.DefaultRequestHeaders.Add("X-Internal-Token", internalToken);
});
```
Base URL from config key `MlService:BaseUrl`; falls back to
`http://localhost:8001` in code if absent. **The `HttpClient` itself now
has no timeout** (`Timeout.InfiniteTimeSpan`) — `MlClient` manages timeouts
itself per call (below), no longer a flat 30s at the `HttpClient` level.
Every outgoing request carries an `X-Internal-Token` header sourced from
`MlService:InternalToken` — the .NET→Python auth secret for this seam; the
header is simply omitted if no token is configured, so a dev setup with no
`MlService:InternalToken` still works against an ML service that doesn't
enforce it.

**JSON convention**: `MlClient.Json` static `JsonSerializerOptions` uses
`PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower` (case-insensitive)
so C# PascalCase DTOs auto-convert to the Python side's snake_case (e.g.
`NextItemId` ⇄ `next_item_id`). A few DTOs still need explicit
`[JsonPropertyName]` where the policy wouldn't derive the right name
(`CatCandidate.ItemId → "item_id"`, `SpeakingScoreResponse.FeedbackVi →
"feedback_vi"`, `ExerciseGenResponse.ModelVersion → "model_version"`).

**The fail-soft mechanism, in full** — every `IMlClient` method funnels
through `MlClient.SendAsync`, which composes three layers:

1. **Circuit breaker** (`MlCircuitBreaker`, singleton — process-local
   state, not distributed, shared by every request). Before attempting
   the HTTP call, `ThrowIfOpen()` throws `MlServiceUnavailableException`
   immediately, **without touching the network**, if the breaker is open.
   It opens after **3 consecutive failures** (`RecordFailure()`) for a
   flat **30-second** window; any success anywhere (`RecordSuccess()`)
   resets the failure count to 0. Once the 30s window elapses, the next
   call resets state and gets a normal attempt — it's not a single
   half-open "trial" call, it takes 3 more consecutive failures to reopen.
2. **Timeout + retry**, per call: JSON calls get a 30s timeout
   (`DefaultTimeout`) and up to **2 attempts** (`MaxAttempts`); the speech
   upload (`ScoreSpeakingAsync` → `POST /speech/score`) gets a 90s timeout
   (`SpeechTimeout`) and is retried only if `audio.CanSeek` (a
   non-seekable stream can't be replayed, so it gets 1 attempt). Retries
   trigger on `HttpRequestException` / `TaskCanceledException` /
   `JsonException`, and on HTTP 408/429/5xx responses (`IsTransient`). A
   caller-side cancellation (`ct.IsCancellationRequested` true — the
   original token, not the internal per-call timeout token) is **not**
   retried; it propagates immediately, skipping the fail-soft machinery
   entirely.
3. **Result classification**:
   - Success (2xx + parseable body) → `circuitBreaker.RecordSuccess()`,
     return the value.
   - **Input-rejection status** (400, 413, 415, 422 — `IsInputRejection`)
     → throws `MlInputRejectedException(statusCode, error)` immediately,
     **no retry, circuit breaker untouched**. `error` is read from the
     response body's `error` or `detail` JSON field, falling back to
     `"ml_input_rejected"`. This is new since this doc last described
     `MlClient`: a genuinely-bad request (oversized speaking upload,
     ML-side validation failure) is **not** folded into a 503 — endpoints
     catch it separately and call `ApiResults.MlRejected(error)`, which
     passes the ML service's own status code straight through as
     `{"error": <code>}`.
   - Any other non-success outcome — retries exhausted on a transient
     status, or an immediate non-transient/non-rejection status like
     401/403/404 — ends the retry loop, calls
     `circuitBreaker.RecordFailure()`, and throws
     `MlServiceUnavailableException`. So any ML-side failure that isn't
     one of the four input-rejection codes still collapses to 503
     `ml_service_unavailable`, same as "service unreachable" or "timed
     out."
   - Endpoints catch **only** `MlServiceUnavailableException` (→
     `ApiResults.MlUnavailable()`, 503 `{"error":"ml_service_unavailable"}`)
     and, where relevant, `MlInputRejectedException` (→
     `ApiResults.MlRejected(error)`). Any other exception (e.g. a bug in
     response-shape handling) is **not** fail-soft — it propagates as an
     unhandled 500.

**Fallback content, not just 503**: `POST /exercises/generate`
(`Endpoints/ExerciseEndpoints.cs`) goes further than a bare 503 — on
`MlServiceUnavailableException` it falls back to serving up to 3 items
straight from the seeded item bank (matching skill + exercise type,
`!IsDeleted`) instead, and only returns `ApiResults.MlUnavailable()` if
that fallback query also comes up empty. Worth copying for other
generation endpoints where graceful degradation matters more than a hard
503.

**`MlFeatureRollout`** (`Services/MlFeatureRollout.cs`, static) — a
separate concern from fail-soft: it gates **whether an ML call is
attempted at all**, per user, per feature, via a deterministic percentage
rollout (`SHA256(userId bytes) mod 100` vs. a configured percent — the
same user always lands on the same side of the threshold for a given
feature/percentage). `IsEnabled(configuration, environment, feature,
userId)`; config key `MlFeatures:{feature}RolloutPercent`. Default when
unset: **100 in non-Production, 0 in Production** — a new ML-backed
feature is fail-closed by default in prod until explicitly rolled out.
Gates exactly three endpoints today (confirmed by grepping every call
site — not all ML endpoints are gated):
- `"Speaking"` → `POST /speaking/attempts`
- `"Writing"` → `POST /writing/evaluate`
- `"Advisor"` → `POST /path/advisor`

`POST /exercises/generate`, `POST /admin/items/generate`, and
`POST /dictionary/lookup` call `IMlClient` directly with **no** rollout
gate. When a feature is disabled, the handler returns
`ApiResults.FeatureDisabled()` → 503 `{"error":"feature_disabled"}` — **a
different 503 body from `ml_service_unavailable`**, easy to conflate when
skimming logs or tests.

**When adding a new ML-backed endpoint**: add a method to `IMlClient`/
`MlClient` following the existing pattern (`CatSelectAsync`,
`AdvisorAsync`, `GenerateExercisesAsync`, `EvaluateWritingAsync`,
`ScoreSpeakingAsync`), then in the endpoint handler:
```csharp
catch (MlInputRejectedException error) { return ApiResults.MlRejected(error); }
catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
```
— copy this verbatim rather than inventing a new error shape. Decide
deliberately whether the new endpoint needs an `MlFeatureRollout.IsEnabled`
gate (most existing ones don't) and whether `"ml-upload"` rate limiting
applies (most ML-backed writes do — see Rate limiting above).

## Other `Services/`
- **`MasteryService.cs`** (scoped) — `RecordAnswerAsync(userId, skillId,
  correct)`: composite-PK lookup on `Masteries` (creates a new
  `Mastery{PCorrect=0.5}` if missing), computes `days =
  (UtcNow - m.UpdatedAt).TotalDays`, calls `MasteryCalc.Update`, saves.
- **`TokenService.cs`** (singleton) — see Auth flow above.
- **`MlCircuitBreaker` / `MlFeatureRollout`** (singleton / static
  respectively) — see the `MlClient` section above. Naming trap:
  `MlCircuitBreaker` is defined inside `Services/MlClient.cs`, not its own
  file, despite `MlFeatureRollout` getting one (`Services/MlFeatureRollout.cs`).

## Config key reference
| Section | Keys | File | Notes |
|---|---|---|---|
| Logging | `Logging:LogLevel:Default`, `Logging:LogLevel:Microsoft.AspNetCore` | both | |
| Hosting | `AllowedHosts` | `appsettings.json` | |
| Database | `ConnectionStrings:Default` (Npgsql) | `appsettings.Development.json` only | required in Production |
| Auth | `Jwt:Issuer`, `Jwt:Secret` | `appsettings.Development.json` only | both required in Production; `Secret` ≥32 chars |
| Auth | `Jwt:AccessTokenMinutes` | both (`15` in each) | code fallback `15` if absent |
| Admin bootstrap | `BootstrapAdmin:Email`, `BootstrapAdmin:Password` | `appsettings.Development.json` only | no-op only if **both** unset; runs in **any** environment where set (not Dev-gated in code) |
| ML integration | `MlService:BaseUrl` | `appsettings.Development.json`, with a code fallback | required in Production |
| ML integration | `MlService:InternalToken` | `appsettings.Development.json` only | sent as `X-Internal-Token` on every ML call; required in Production, ≥32 chars |
| ML rollout | `MlFeatures:SpeakingRolloutPercent`, `MlFeatures:WritingRolloutPercent`, `MlFeatures:AdvisorRolloutPercent` | `appsettings.Development.json` (all `100`) | code fallback: 100 non-Production / 0 Production |
| Storage | `Storage:TempPath` | `appsettings.Development.json` only (`temp/speaking`) | required in Production |
| CORS | `Cors:AllowedOrigins` (string array) | `appsettings.Development.json` only (`["http://localhost:5173"]`) | required non-empty in Production |
| Rate limiting | `RateLimits:Anonymous` (60), `RateLimits:Authenticated` (120), `RateLimits:AuthWrite` (5), `RateLimits:Refresh` (10), `RateLimits:MlUpload` (10) | `appsettings.Development.json` only | values shown are the code fallback defaults, mirrored in dev config |
| Privacy / retention | `Privacy:DeletionGraceDays` (7), `Privacy:SecurityLogRetentionDays` (90), `Privacy:DeletionReceiptRetentionDays` (90) | `appsettings.json` (base) | drives `PrivacyDeletionService` / `DataRetentionService` — see Security audit events above |

No `appsettings.Production.json` exists in the repo — see "CORS &
production config gate" above for the full list of keys a real Production
deploy must supply out-of-band.
