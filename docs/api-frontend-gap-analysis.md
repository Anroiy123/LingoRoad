# API ↔ Frontend Gap Analysis

**Scope:** LingoRoad's `.NET` backend API (`src/backend/LingoRoad`) compared
against the needs of its two frontends: the Flutter mobile app
(`src/mobile`) and the React admin web app (`src/admin`). The Python ML
service (`src/backend/ml`) is out of scope — it is an internal seam
*(giao diện nội bộ)* called only by the `.NET` backend (`MlClient`), never
directly by either frontend.

**Method:** the API side of the comparison is cross-checked directly against
`Program.cs`/`Endpoints/*.cs` and the interactive OpenAPI document served at
`/scalar/v1` in development. The frontend side is read from the actual mobile
and React admin clients, cross-checked against the original product spec,
`MVP_architecture.md`.

Each row below is classified:
- ✅ **Fulfilled** — the backend already supports this; the frontend just needs to call it.
- ⚠️ **Partial** — the backend supports part of this, or the shape/semantics differ from what the frontend expects or needs.
- ❌ **Missing** — no backend capability exists for this at all.

## 1. API inventory summary

The `.NET` API exposes 50 routes across 13 feature groups: Health, Auth,
Skills, Items, Placement, Mastery, Reviews (spaced repetition
*(lặp lại ngắt quãng)*), Path (learning-path recommendation + advisor),
Lessons, Exercises (incl. writing evaluation), Dashboard/Gamification,
Speaking, and Admin. This summary does not duplicate every route's verb, auth requirement
and request/response shape.

As of this report, browsing `http://localhost:5000/scalar/v1` (dev only)
gives an interactive view of the same surface, generated from the
`Microsoft.AspNetCore.OpenApi` document already wired up in `Program.cs`.

## 2. Feature availability matrix

A quick-scan overview of every feature domain across all three surfaces,
before the detailed per-client breakdowns in §3/§4. `—` means the domain
doesn't apply to that surface (e.g. Admin has no placement-test UI).

| Feature domain | Backend (`.NET`) | Mobile (Flutter) | Admin (React) |
|---|---|---|---|
| Auth/session | ✅ Access + rotating refresh, logout, password change, role policy | ✅ Wired (`ApiAuthRepository`/`ApiClient`) | ✅ Login, bearer client, single-flight refresh and fail-closed Admin guard |
| Onboarding (goal, daily study minutes) | ✅ `GET/PATCH /auth/me` | ✅ Profile Setup and editable Profile | — |
| Skill graph (read) | ✅ `/skills`, `/skills/graph` | ✅ Progress joins `/skills` + `/mastery` | ✅ Catalog and CRUD UI |
| Skill/Item management (write) | ✅ Admin CRUD, validation, soft-delete and audit | — | ✅ CRUD UI with API states |
| Lesson management | ✅ Admin CRUD, relation validation and draft/publish | ✅ Detail/player wired to learner API | ✅ CRUD/draft/publish UI |
| Placement test | ✅ Full adaptive-test flow (start/answer/result) | ✅ Wired (`ApiPlacementRepository`) | — |
| Learning path (recommendation) | ✅ `/path` + `/path/today` | ✅ Path/today lesson/player wired | — |
| Learning-path advisor (Q&A) | ✅ `/path/advisor` (RAG) | ✅ Advisor flow with API states/retry | — |
| Mastery tracking | ✅ `/mastery` + lesson answer updates | ✅ Progress uses real catalog/mastery | ⚠️ Aggregate by category in overview; no per-user drill-down |
| Spaced-repetition reviews (SRS) | ✅ FSRS + wrong-answer producer | ✅ Due/grade flow wired | — |
| Exercises (3 seeded types + grading) | ✅ Lesson-bound/idempotent submit and ML generation | ⚠️ Lesson-bound MCQ/cloze/reorder wired; standalone ML generation has no UI | — |
| Writing evaluation (AWE) | ✅ `/writing/evaluate` | ✅ Writing flow with API states/retry | — |
| Speaking assessment | ✅ Safe `/speaking/attempts` upload/history | ✅ Recording, score/history and retry flow | — |
| User profile (read/update) | ✅ `GET/PATCH /auth/me`, password change | ✅ Read/update/preferences/password wired | — |
| Dashboard / gamification (XP, coin, streak, quest, badges) | ⚠️ Aggregate + append-only reward ledger exist; badges missing | ⚠️ Home/Streak use real API; badges remain unavailable | ✅ Overview consumes learner/reward aggregates |
| Admin auth / roles | ✅ `Learner/Admin` role claim + policy + bootstrap | — | ✅ Login and route guard; learner receives 403 from server |
| Analytics (user/skill/question) | ✅ `/admin/analytics/overview` | — | ✅ Activity, completion, correctness, review, mastery, item/content usage |
| Cross-origin access (CORS) | ✅ Production allowlist with fail-fast validation | — (native app, not affected) | ✅ Configurable API base URL; production origin is supplied at deployment |

## 3. Mobile (Flutter) gap analysis

The tables below derive the mobile mock-vs-live split from the current client
code and reframe it against backend capability.

### 3.1 Already wired to the real API

| Feature | Status | Notes |
|---|---|---|
| Auth (login/register) | ✅ Fulfilled | `ApiAuthRepository` → `/auth/register`, `/auth/login`. |
| Profile/onboarding | ✅ Fulfilled | `GET/PATCH /auth/me` plus `/auth/change-password`; target CEFR, daily goal, purpose, focus, reminder and preferences persist through the API with rollback on save failure. |
| Placement test | ✅ Fulfilled | `ApiPlacementRepository` → `/placement/status`, `/placement/start`, `/placement/{sessionId}/answer`, `/placement/{sessionId}/result`. |
| Learning Path | ✅ Fulfilled | `ApiLearningPathRepository` → `GET /path?limit=N`, parsed into `LearningPathStep(code, name, nameVi, cefr, mastery, reason)` — matches the endpoint's actual shape exactly. Wired since this report was first drafted (`mock_repository.dart`'s old `path()`/`PathNode` mock was removed); the screen was redesigned around what `/path` returns rather than the old lesson-tree/XP mock — see §6 item 3 (resolved). |
| Lesson/Exercise | ✅ Fulfilled | `/path/today` opens a start/resume attempt; the player supports MCQ, cloze and reorder, retains operation UUIDs across retry and refreshes Path/Progress/Review/Dashboard after completion. |
| Home/Dashboard | ✅ Fulfilled | `GET /dashboard` supplies learner name, current/target CEFR, mastery, weak/strong skills, goals, next lesson, due reviews, completion/recent activity and reward stats. `/quests` supplies daily quest state. |
| Streak | ✅ Fulfilled | The details screen derives current/longest streak and active calendar dates from the reward ledger; the former October 2025 mock was removed. |
| AI practice | ✅ Fulfilled, production-gated | Home opens Advisor, Writing and Speaking flows. Multipart upload carries MIME/auth, microphone denial and request retry are handled, and duplicate submission is blocked. Speaking artifacts/evaluation remain gated for production. |

### 3.2 Review and Progress integration update (2026-08-01)

Review now consumes authenticated `GET /reviews/due` and posts explicit ratings to
`POST /reviews/{cardId}/grade`. The grade request carries an operation UUID and
expected repetition count, so manual retry after an uncertain outcome is
idempotent. Completing a lesson now creates `ReviewCard` rows for wrong answers;
an empty Review state remains valid when no learned item is due.

Progress now joins public `GET /skills` with authenticated `GET /mastery` and
shows aggregated leaf-skill categories. Home consumes `GET /dashboard`; XP,
coin, streak and quests come from the append-only reward ledger. Achievements/
badges and mastery passive decay remain unavailable.

### 3.3 Historical mock gap snapshot (resolved, retained for traceability)

The rows below describe the state when this report was first drafted. They are
not the current implementation: Progress, Review and Home have since moved to
API repositories, and `mock_repository.dart` has been deleted from production.

| Screen | Mock data shape | Closest backend endpoint | Status | Recommendation |
|---|---|---|---|---|
| Progress | `SkillProgress(skillKey, percent, icon)` — 6 hardcoded skills | `GET /mastery` → `[{skillCode, skillName, pCorrect, updatedAt}]` | ⚠️ Partial | The endpoint returns the right kind of data (`pCorrect` → `percent`), but mobile's 6 skills are a static localization-key list, not driven by the real skill graph (`GET /skills`, 156 leaf skills) or the caller's actual mastery rows. Needs a mapping from returned `skillCode`s to display/i18n keys and icons, and handling for skills the endpoint hasn't returned yet (unpracticed skills). |
| Review | `ReviewCardData(wordKey, meaningKey, exampleKey, categoryKey)` — 3 static flashcards with Forgot/Hard/Good/Easy controls | `GET /reviews/due`, `POST /reviews/cards`, `POST /reviews/{cardId}/grade` | ⚠️ Partial | The four grade controls are present, but the screen still loads `const MockRepository().reviews()`. It has no due-date/API loading/error/empty states, no double-submit guard, and neither fetches due cards nor posts a grade. Nothing currently calls `POST /reviews/cards` to create a card in the first place — that has to happen somewhere (e.g. after a wrong exercise answer) before there's anything to review. |
| Home | `DailyQuest(key, current, target, icon)` — daily quests | none | ❌ Missing | No daily-quest/goal concept (or XP/streak/badge tracking) exists anywhere in the `.NET` domain model. Note: `progress_screen.dart` also hardcodes streak ('12'-day), XP ('1.240'), badge counts ('12/48'), and quest progress ('2/3') inline, with no backend equivalent — this is a net-new feature, not a wiring task. |

### 3.4 Advanced learner capability update (2026-08-02)

The remaining backend-only learner capabilities are:

| Backend capability | Status | Notes |
|---|---|---|
| `/path/today`, `/lessons/*`, `/lesson-attempts/*` | ✅ Fulfilled, used | Versioned content, resume, completion and review-card production are wired to the mobile player. |
| `POST /exercises/generate`, `POST /exercises/{id}/submit` | ⚠️ Partial mobile use | Lesson-bound submit/feedback is wired; standalone AI-generated exercise creation still has no mobile entry point. |
| `POST /writing/evaluate` | ✅ Fulfilled, used | Mobile Writing posts a task/essay and renders rubric feedback with loading/error/retry. |
| `POST /speaking/attempts`, `GET /speaking/attempts` | ✅ Fulfilled, used | Mobile records WAV with permission handling; API validates declared MIME plus signature, caps 10 MiB/120 seconds, deletes raw audio and persists only score metadata/history. |
| `POST /path/advisor` | ✅ Fulfilled, used | Mobile Advisor posts the question with loading/error/retry and blocks concurrent submits. |

The frontend/API integration gap is closed. Production defaults these optional
AI flows to a zero-percent cohort unless explicitly configured; development uses
100 percent. Production remains gated on quota/cost UX, pinned ML/RAG artifacts
and consent-based Whisper evaluation; the model manifest deliberately labels
SAINT+ and Whisper as non-production. The .NET ML client uses bounded retry,
per-flow timeout and a shared circuit breaker; standalone exercise generation
falls back to the versioned item bank when ML is unavailable.

## 4. Admin (React) gap analysis

`src/admin` is now a guarded React CMS backed by Admin-only API routes. The
surface implements the minimum scope from `MVP_architecture.md`
§4.4/§5.2/§8.4/§10.9 (Admin CMS + Analytics).

| Feature (from MVP spec) | Status | Notes |
|---|---|---|
| Admin login / role separation | ✅ Fulfilled | `User.Role`, JWT role claim, Admin policy, secret-driven bootstrap, React login and fail-closed route guard are implemented; anonymous gets 401 and learner gets 403. |
| Skill management (create/edit/delete, assign prerequisites) | ✅ Fulfilled | Admin API/UI support create/update/soft-delete, parent relation validation and cycle prevention. |
| Lesson management | ✅ Fulfilled | Draft/published CRUD, ordered item relationships, soft-delete and audit are implemented. |
| Question management (create/edit/delete, assign answer/difficulty/CEFR) | ✅ Fulfilled | Protected CRUD exposes answer/difficulty metadata only within the Admin surface and blocks unsafe relation deletion. |
| User / skill / question analytics | ✅ MVP overview | Active learners, completion, correctness, due reviews, mastery by category, item usage and content usage are available. Per-user drill-down remains an extension. |
| Versioned import | ✅ Fulfilled | `validate/preview → apply` is transactional, version/checksum idempotent and rejects changed replay, broken references, duplicates and skill cycles. |
| Audit trail | ✅ Fulfilled | Admin mutations append content/security audit events and the protected UI can inspect recent events. |

The minimum Admin gate is now implemented and has API/component/Playwright
coverage plus a browser smoke against the real API/PostgreSQL. Remaining work
is production deployment configuration, running browser E2E in CI, pagination/search and
optional per-user analytics/role management.

## 5. Cross-cutting gaps

- **CORS, role foundations and the Admin surface are complete** for the minimum
  scope: every CRUD/import/analytics/audit route requires the Admin policy and
  the browser client has a fail-closed guard.
- **Lesson domain is complete on the learner API and wired on mobile**, including
  versioned content, attempts, feedback and completion. Admin draft/publish
  tooling remains. The post-placement learner loop passed a MuMu smoke with
  offline retry, application restart and ML unavailable.
- **Idempotency is enforced server-side** for start/answer/completion, review
  grading and rewards; the lesson/review clients retain operation UUIDs across
  uncertain retries and block duplicate taps.

## 6. Integration options

Concrete next steps, ordered by dependency:

1. **Pin and distribute ML/RAG artifacts** and keep SAINT+/Whisper disabled until
   their evaluation gates are met; add quota/cost UX for optional AI calls.
2. **Add learning-event/privacy lifecycle APIs** now that lesson traffic and the reward
   ledger exist, so
   completion, correctness and item-difficulty reports have real inputs.
3. **Add a clean-account full-stack E2E** for registration, placement, profile
   setup and the already smoke-tested learner loop.
4. **Run the committed Admin Playwright specs in CI** and add pagination/search
   before the content catalog grows substantially.
5. **Consider client codegen from OpenAPI for Admin** once CRUD contracts stop
   changing; Flutter can keep its existing hand-written repository pattern.
