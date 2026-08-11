# CLAUDE.md

## Project Overview
LingoRoad is an AI-powered English-learning platform for Vietnamese learners
(CEFR placement, knowledge tracing, spaced repetition, personalized learning
paths — see repo-root `README.md`). It is a monorepo with **four**
subprojects under `src/`:

- **`src/backend/`** — split into **two runtimes** on purpose (see
  `docs/system-architecture.md` §1 for the full rationale):
  - **`src/backend/LingoRoad/`** — ASP.NET Core 10 minimal-API application
    backend. Owns everything relational: auth, users, the skill graph, item
    bank, placement sessions, mastery, spaced-repetition cards, exercises,
    speaking attempts. Project type: **Web API**.
  - **`src/backend/ml/`** — Python FastAPI service (`lingoroad_ml` package).
    Owns everything AI/ML: IRT/CAT item selection, knowledge tracing
    (SAINT+), RAG study advisor, exercise/AWE generation, speech scoring —
    all via Gemini + PyTorch + faster-whisper. Project type: **Web API**
    (ML-flavored; stateless, called only by the .NET side).
  The seam between them is `LingoRoad/Services/MlClient.cs` → HTTP. It is a
  **fail-soft boundary**: if the ML service is unreachable or times out, AI
  endpoints return `503 {"error":"ml_service_unavailable"}` while core
  features (auth, item bank, review scheduling) keep working. See
  `.claude/context/backend/auth-and-integrations.md`.
- **`src/mobile/`** — `lingoroad_mobile`, the Flutter frontend (Material 3).
  All UI strings are Vietnamese; target platforms are Android and web, with
  Windows also supported for desktop dev. Project type: **Frontend / UI**.
- **`src/admin/`** — React + TypeScript + Vite CMS for accounts with the
  `Admin` role: Skills/Items/Lessons CRUD, content-bundle import, analytics,
  audit log. Backend still enforces authorization; the client route guard is
  UX-only. Playwright e2e coverage lives in `src/admin/e2e`. See
  `src/admin/README.md`. **No dedicated Claude context exists for this
  subproject yet** — treat `docs/system-architecture.md` §6 as the source of
  truth until one is written.
- **`src/frontend/`** — empty placeholder, not in use.

Both `src/mobile` and `src/admin` call only the .NET API; neither calls the
ML service directly.

> ⚠️ **Docs vs. code drift**: `docs/ai-theory-and-algorithms.md` and
> `docs/system-architecture.md` §5 mark exercise generation/AWE and speaking
> assessment as "Planned" (tasks 13/14). As of this writing the code is
> **fully implemented and tested**: `Endpoints/ExerciseEndpoints.cs`,
> `Endpoints/SpeakingEndpoints.cs`, `ml/lingoroad_ml/llm/{exercises,awe}.py`,
> `ml/lingoroad_ml/speech/scoring.py`, plus sample output in
> `ml/reports/samples/{exercises,awe,speaking}.md`. Verify current status
> against the code (`git log`, `ml/reports/`) rather than trusting those doc
> labels at face value.

## Development Commands
All commands below run from the repo root unless noted.

```powershell
# 1. Database
cd src/backend && docker compose up -d db

# 2. .NET application API → http://localhost:5000
cd src/backend/LingoRoad && dotnet run

# 3. Python ML service → http://localhost:8001
cd src/backend/ml && .venv/Scripts/uvicorn lingoroad_ml.serving.app:app --port 8001

# 4. Flutter mobile app (needs 1-3 running for real auth/placement flows)
cd src/mobile && flutter run -d chrome --dart-define="API_BASE_URL=http://localhost:5000"

# 5. Admin CMS (needs 1-2 running; needs an Admin account bootstrapped via backend config)
cd src/admin && npm ci && npm run dev
```

Tests:
```powershell
dotnet test src/backend
cd src/backend/ml && .venv/Scripts/python -m pytest tests/ -v
cd src/mobile && flutter analyze && flutter test
cd src/admin && npm run lint && npm test -- --run && npm run test:e2e
```
> ML tests and research scripts must run with `src/backend/ml` as the
> working directory — there's no `pyproject.toml`/installed package, so
> `lingoroad_ml`/`research` only resolve when `ml/` is on `sys.path`. See
> `.claude/context/ml/folder-structure.md`.

EF Core migrations (new DB, or after a model change):
```powershell
dotnet ef database update --project src/backend/LingoRoad --startup-project src/backend/LingoRoad
```

End-to-end smoke (both services + DB running, item bank imported):
```powershell
cd src/backend && ml/.venv/Scripts/python ml/research/e2e_smoke.py --api http://localhost:5000
```

Full local-dev runbook (ports, seed/item-bank setup, Android/LAN specifics
for the mobile client, troubleshooting): `docs/mobile-local-development.md`.

## Context Files
| File | Description |
|---|---|
| `.claude/context/backend/folder-structure.md` | `.NET` project layout, naming conventions, how to add a new endpoint module |
| `.claude/context/backend/api-catalog.md` | Every `.NET` route: verb, path, auth, request/response shape |
| `.claude/context/backend/domain-model.md` | Entities, business-rule algorithms (FSRS, mastery EMA, path builder, CEFR mapping), migration history |
| `.claude/context/backend/auth-and-integrations.md` | JWT/BCrypt auth flow, the `MlClient` fail-soft pattern, config keys |
| `.claude/context/backend/testing.md` | `TestAppFactory` (in-memory SQLite), fake ML client, test file map |
| `.claude/context/ml/folder-structure.md` | Python package layout, research-script invocation gotcha, env setup, requirements files |
| `.claude/context/ml/api-catalog.md` | Every FastAPI route: verb, path, request/response shape |
| `.claude/context/ml/models-and-artifacts.md` | KT models, RL (DQN/DP) module, checkpoints, env vars, gitignored `data/` |
| `.claude/context/ml/testing.md` | pytest conventions, what needs fakes vs. what's pure-logic |
| `.claude/context/frontend/folder-structure.md` | Flutter (`src/mobile`) directory layout, naming conventions, where to add new features vs. tab screens |
| `.claude/context/frontend/component-architecture.md` | Flutter route tree, navigation/redirect logic, state management pattern, mock-vs-live data split |
| `.claude/context/frontend/api-and-auth.md` | Flutter `ApiClient`/session/token design, repository contracts, error-code taxonomy |
| `.claude/context/frontend/testing.md` | Flutter test layout, conventions, how the widget-key scheme supports tests, run commands |

All paths in the `backend`/`ml` context files are relative to `src/backend/`
(e.g. `ml/` means `src/backend/ml/`, `LingoRoad/Data/...` means
`src/backend/LingoRoad/Data/...`); paths in the `frontend` context files are
relative to `src/mobile/` (e.g. `lib/` means `src/mobile/lib/`) — they were
written from within those subprojects before this file moved to repo root.

Other `.claude/` content: `.claude/requirement.md` and
`.claude/requirement-brainstorm.md` (the original five-module requirement
this repo was built against), `.claude/theory-reqquirement.md` (Mảng 3
theory requirement — see `docs/learning-path-optimization.md` and
`docs/system-architecture.md`), and `.claude/tasks/` (the 16-task
implementation plan the backend was built from, all completed — see
`.claude/tasks/README.md`). Backend session history/state for the
spec-driven-development workflow lives separately in
`src/backend/.superpowers/sdd/progress.md`.

> Always keep the context files up-to-date when making changes that affect the above areas.

## Architecture
```
LingoRoad/
├── docs/                          # architecture, theory, gap-analysis, VN reports (start at docs/README.md)
├── DESIGN.md, MVP_architecture.md, LingoRoad.md   # original (Vietnamese) design documents
└── src/
    ├── backend/
    │   ├── LingoRoad/              # ASP.NET Core 10 minimal API
    │   │   ├── Program.cs          # composition root: DI, middleware, all app.Map*() calls
    │   │   ├── Endpoints/          # one static class per feature area (see api-catalog.md)
    │   │   ├── Domain/             # entities + pure business-rule algorithms
    │   │   ├── Data/                # AppDbContext (Fluent config), DbSeeder, Seed/skills.json
    │   │   ├── Migrations/          # EF Core migrations, one per feature area
    │   │   └── Services/            # MlClient (fail-soft HTTP client), MasteryService, TokenService
    │   ├── LingoRoad.Tests/         # xUnit; in-memory SQLite via TestAppFactory
    │   ├── ml/                      # Python FastAPI ML service (lingoroad_ml package)
    │   │   ├── lingoroad_ml/        # irt/cat/cefr/itemgen/simulation, kt/, rl/, llm/, speech/, serving/
    │   │   ├── research/            # standalone scripts — run as `python -m research.<name>` from ml/
    │   │   └── tests/               # pytest, run from ml/
    │   └── docker-compose.yml       # PostgreSQL 16
    ├── mobile/                     # Flutter app (lib/, test/ — see frontend context files)
    ├── admin/                      # React + TypeScript + Vite CMS (src/, e2e/)
    └── frontend/                   # empty placeholder, not in use
```

Dependency direction: `LingoRoad/Endpoints/` → `Domain/` + `Data/` + `Services/`;
nothing in `Domain/` depends back on `Endpoints/` or `Services/`. On the
Python side, `serving/*_routes.py` → the framework-agnostic logic modules
(`irt.py`, `kt/saint_plus.py`, `llm/advisor.py`, ...) — routing/pydantic
concerns never leak into the logic modules themselves. On the Flutter side,
`screens/` and `features/*/presentation` depend on `core/` and `theme/`;
`features/*/data` depend on `core/network`; nothing under `core/` depends
back on `features/` or `screens/`.

Key design decisions:
- **Two backend runtimes, one HTTP seam, fail-soft.** See Project Overview
  above and `.claude/context/backend/auth-and-integrations.md` for the exact
  exception-to-503 mechanism.
- **No ORM attributes** — all EF Core configuration is Fluent API in
  `AppDbContext.OnModelCreating`, not `[Key]`/`[Required]` decorations.
- **Minimal-API, not MVC controllers.** Auth gating is `.RequireAuthorization()`
  chained on `MapGroup`/`MapPost`/`MapGet`, never `[Authorize]` attributes.
- **The Python ML side is stateless.** It never touches Postgres directly;
  the .NET side assembles all context (response sequences, path/mastery) and
  sends it over HTTP per request.
- **`src/backend/ml/` has no `pyproject.toml`/installed package** — it only
  imports correctly when `ml/` is the working directory. This is a real
  footgun; see `.claude/context/ml/folder-structure.md` before writing a new
  script there.
- **Flutter: no state-management package.** View models extend
  `ChangeNotifier`; screens rebuild via `AnimatedBuilder`. Session/auth state
  flows through `go_router`'s `refreshListenable`. Repositories are
  abstract interfaces with one real and one fake/in-memory implementation
  used in tests — never call `http`/`flutter_secure_storage`/`audioplayers`
  directly from a screen or view model.
- **Admin has no client router dependency** — `App.tsx` applies the role
  guard and `AdminShell` owns the CMS sections directly.

## Key Technologies
**`.NET` side:** ASP.NET Core 10 minimal API, EF Core + Npgsql, JWT Bearer
auth (`Microsoft.AspNetCore.Authentication.JwtBearer`), BCrypt.Net for
password hashing, xUnit + `Microsoft.AspNetCore.Mvc.Testing` +
`Microsoft.EntityFrameworkCore.Sqlite` (in-memory test DB), coverlet.

**Python ML side:** FastAPI, Pydantic, PyTorch 2.11 (cu128 build) for KT
models, `openai` SDK pointed at Gemini's OpenAI-compatible endpoint
(`gemini-2.5-flash` chat, `gemini-embedding-001` embeddings), faster-whisper
(speech-to-text), pytest.

**Flutter mobile:** Flutter `>=3.44` / Dart SDK `>=3.12.0 <4.0.0`, Material 3, `go_router`,
`http` package directly (no Dio/Retrofit), `flutter_secure_storage`,
`audioplayers`, `flutter_test` + `package:http/testing.dart`.

**Admin:** React 18 + TypeScript + Vite, Playwright (e2e).

**Data:** PostgreSQL 16 via `src/backend/docker-compose.yml` (db/user/password all
`lingoroad`).

## Commit Message Convention
Conventional Commits: `feat(ml): ...`, `feat(mobile): ...`, `docs(sdd): ...`,
`chore: ...`. Scope names observed in history include `ml`, `mobile`, `sdd`
(spec-driven-development docs), and unscoped `docs:`/`chore:` for repo-wide
changes. See `git log` for examples; there's no enforced scope list — pick
the one matching the area you touched (`ml`, `mobile`, `admin`, or a new
scope like `api`/`backend` for `.NET`-only changes, following the pattern).
Subject in imperative mood, no trailing period.

## Code Quality
- `.NET`: `dotnet test src/backend` (xUnit). No linter/formatter config
  (`.editorconfig`) was found — match surrounding code style.
- Python: `cd src/backend/ml && .venv/Scripts/python -m pytest tests/ -v`.
  No `pytest.ini`/`conftest.py`/lint config exists — tests must run with
  `ml/` as cwd (see above). No formatter/linter (black/ruff) config found.
- Flutter: `flutter analyze` must pass (backed by `flutter_lints` + two
  custom rules in `src/mobile/analysis_options.yaml`); `flutter test` covers
  unit + widget/flow tests. Widgets that matter for tests carry explicit
  `Key('...')` values — keep this convention for anything a flow test needs
  to find.
- Admin: `npm run lint`, `npm test -- --run`, `npm run build`,
  `npm run test:e2e` (Playwright, Chromium).
- No CI workflow runs any of this in this repo (no `.github/workflows/` test
  jobs as of this writing). > ⚠️ Undocumented — verify this is still the
  case before assuming CI enforcement; all test suites are currently
  developer-run only.
- No CORS policy is configured on the `.NET` API for the admin's React
  origin by default — relevant when running `src/admin` against a
  non-localhost backend; see `docs/system-architecture.md` §7.
