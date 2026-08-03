# API & Auth — lingoRoad Mobile

## `AppConfig` / base URL
`AppConfig` (`core/config/app_config.dart`) reads `API_BASE_URL` from
`String.fromEnvironment`, default `http://10.0.2.2:5000` (Android emulator
loopback). It's **baked in at build time** via `--dart-define` — changing the
backend host requires a rebuild (and reinstall, for APKs), not just an app
restart. `normalizeBaseUrl` validates scheme/host and throws `ArgumentError`
on garbage input — this runs at `AppConfig()` construction, i.e. at app
startup.

## `ApiClient` (`core/network/api_client.dart`)
Thin wrapper over `package:http`, constructed once in `main.dart`:
- `get(path, {authenticated, timeout})` / `postJson(path, {body, authenticated, timeout})`; default timeout 15s.
- Auth header: `Authorization: Bearer <token>` added automatically from
  `SessionController.token` when `authenticated: true` (the default).
- Response decoding: empty body → `null`; `content-type` containing `json` →
  `jsonDecode`; otherwise raw text (used for plain `/health` responses).
- **On HTTP 401, the client calls `session.invalidate()` (== `logout()`) as a
  side effect of the failed request** — a screen doesn't need to handle 401
  specially, but should expect the router to redirect to `/login` right
  after.
- All failure paths (timeout, network error, non-2xx, malformed JSON) are
  normalized into `ApiException` — screens/view models only ever catch
  `ApiException`, never raw `http`/`dart:io` exceptions.
- `resolveUrl(value)` is used for server-provided absolute-or-relative URLs
  (placement audio) — prefer it over hand-rolling `Uri.parse`.

## `ApiException` error-code taxonomy
`ApiException(code, message, statusCode, cause)`. `code` is either the
backend's `error` field (echoed from a JSON `{"error": "..."}` body) or a
client-generated code:

| Code | Origin | Meaning |
|---|---|---|
| `request_timeout` | client | request exceeded `defaultTimeout` |
| `network_unavailable` | client | `http.ClientException` or other transport failure |
| `malformed_response` | client | non-JSON body where JSON expected, or a domain model's `fromJson` validation failed |
| `http_<status>` | client | non-2xx with no `error` field in the body |
| *(backend-defined, e.g. `email_taken`, `password_too_short`, `empty_item_bank`, `ml_service_unavailable`, `session_completed`)* | server | passed through verbatim |

View models map codes to Vietnamese user-facing strings locally
(`AuthViewModel.messageFor`, `PlacementViewModel._messageFor`) — **add new
codes to both the backend and the relevant view model's switch**, there's no
shared/generated mapping between the two projects.

## Session & token (`core/session/`)
- `SessionStore` — interface (`readToken`/`writeToken`/`clearToken`).
  `SecureSessionStore` (real, `flutter_secure_storage`, key
  `lingoroad.access_token`) vs `MemorySessionStore` (tests).
- `SessionController extends ChangeNotifier` — the single source of truth for
  `SessionStatus` (`checking`/`unauthenticated`/`authenticated`) and
  `PlacementOnboardingStatus`. All store reads/writes are serialized through
  an internal `_storeQueue` to avoid races between `restore()`,
  `authenticate()`, and `logout()` firing concurrently.
- Epoch/generation counters (`_sessionEpoch`, `_placementLookupGeneration`)
  guard against stale async callbacks mutating state after a newer
  `restore()`/`authenticate()`/`logout()` has superseded them — if you touch
  this file, preserve that guard pattern rather than removing it as
  "unnecessary complexity".
- Placement status lookup (`refreshPlacementStatus`) retries once on failure
  before setting `PlacementOnboardingStatus.error`; the retry count
  (`attempt < 2`) is intentional and is asserted directly by
  `AuthFlowPlacementRepository`'s `statusCalls == 2` test.

## Repositories
Both are `abstract interface class` + one concrete implementation,
constructed in `main.dart` and injected via constructor — never instantiate
`http.Client`/`ApiClient` inside a screen or view model.

- `AuthRepository` / `ApiAuthRepository` — `login`/`register` →
  `POST /auth/login` / `POST /auth/register`, extracts `token` from the
  response, throws `malformed_response` if absent.
- `PlacementRepository` / `ApiPlacementRepository` — `isCompleted`
  (`GET /placement/status`), `start` (`POST /placement/start`), `answer`
  (`POST /placement/{sessionId}/answer`), `result`
  (`GET /placement/{sessionId}/result`). Rewrites any `audioUrl` in returned
  items through `apiClient.resolveUrl` so relative backend paths resolve
  against the configured host.

## Local development
Full runbook (ports, PostgreSQL/backend/ML startup order, Android emulator
vs. LAN device `API_BASE_URL` values, Windows Firewall rule for LAN devices,
troubleshooting the "Không thể kiểm tra tiến độ" status-error screen) lives
in repo-root `docs/mobile-local-development.md` — read it before debugging a
connectivity issue instead of re-deriving it.
