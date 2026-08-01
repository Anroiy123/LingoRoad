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
client code and, where the admin client is still an empty scaffold, from the
original product spec, `MVP_architecture.md`.

Each row below is classified:
- ✅ **Fulfilled** — the backend already supports this; the frontend just needs to call it.
- ⚠️ **Partial** — the backend supports part of this, or the shape/semantics differ from what the frontend expects or needs.
- ❌ **Missing** — no backend capability exists for this at all.

## 1. API inventory summary

The `.NET` API exposes 35 routes across 12 feature groups: Health, Auth,
Skills, Items, Placement, Mastery, Reviews (spaced repetition
*(lặp lại ngắt quãng)*), Path (learning-path recommendation + advisor),
Lessons, Exercises (incl. writing evaluation), Dashboard/Gamification, and
Speaking. This summary does not duplicate every route's verb, auth requirement
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
| Auth/session | ✅ Access + rotating refresh, logout, password change, role policy | ✅ Wired (`ApiAuthRepository`/`ApiClient`) | ⚠️ Backend role-ready; Admin UI still scaffold |
| Onboarding (goal, daily study minutes) | ✅ `GET/PATCH /auth/me` | ✅ Profile Setup and editable Profile | — |
| Skill graph (read) | ✅ `/skills`, `/skills/graph` | ✅ Progress joins `/skills` + `/mastery` | ⚠️ Read-only if wired; no create/update/delete |
| Skill/Item management (write) | ⚠️ Bulk import only (`/admin/items/import`, dev-gated); no single create/update/delete | — | ❌ No CRUD UI exists |
| Lesson management | ⚠️ Lesson learner API exists; Admin CRUD missing | ✅ Detail/player wired to learner API | ❌ CRUD UI missing |
| Placement test | ✅ Full adaptive-test flow (start/answer/result) | ✅ Wired (`ApiPlacementRepository`) | — |
| Learning path (recommendation) | ✅ `/path` + `/path/today` | ✅ Path/today lesson/player wired | — |
| Learning-path advisor (Q&A) | ✅ `/path/advisor` (RAG) | ❌ No chat/advisor screen | — |
| Mastery tracking | ✅ `/mastery` + lesson answer updates | ✅ Progress uses real catalog/mastery | ❌ No aggregate/per-user view |
| Spaced-repetition reviews (SRS) | ✅ FSRS + wrong-answer producer | ✅ Due/grade flow wired | — |
| Exercises (3 seeded types + grading) | ✅ Lesson-bound/idempotent submit and ML generation | ⚠️ Lesson-bound MCQ/cloze/reorder wired; standalone ML generation has no UI | — |
| Writing evaluation (AWE) | ✅ `/writing/evaluate` | ❌ No writing screen | — |
| Speaking assessment | ✅ `/speaking/attempts` (upload, score, history) | ❌ No recording UI (audio *playback* only) | — |
| User profile (read/update) | ✅ `GET/PATCH /auth/me`, password change | ✅ Read/update/preferences/password wired | — |
| Dashboard / gamification (XP, coin, streak, quest, badges) | ⚠️ Aggregate + append-only reward ledger exist; badges missing | ⚠️ Home/Streak use real API; badges remain unavailable | ❌ Missing |
| Admin auth / roles | ✅ `Learner/Admin` role claim + policy + bootstrap | — | ❌ Route guard/login UI missing |
| Analytics (user/skill/question) | ❌ No `/admin/analytics/*` routes | — | ❌ Missing |
| Cross-origin access (CORS) | ✅ Production allowlist with fail-fast validation | — (native app, not affected) | ⚠️ Admin still needs an allowed production origin |

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

### 3.4 Backend capability with no mobile UI at all yet

The remaining backend-only learner capabilities are:

| Backend capability | Status | Notes |
|---|---|---|
| `/path/today`, `/lessons/*`, `/lesson-attempts/*` | ✅ Fulfilled, used | Versioned content, resume, completion and review-card production are wired to the mobile player. |
| `POST /exercises/generate`, `POST /exercises/{id}/submit` | ⚠️ Partial mobile use | Lesson-bound submit/feedback is wired; standalone AI-generated exercise creation still has no mobile entry point. |
| `POST /writing/evaluate` | ✅ Fulfilled, unused | Automated writing evaluation (AWE); no writing-practice screen exists. |
| `POST /speaking/attempts`, `GET /speaking/attempts` | ✅ Fulfilled, unused | Speech scoring (accuracy/completeness/fluency) from an uploaded audio recording; mobile only has audio *playback* (`placement_audio_player.dart`, listening items), no recording UI. |
| `POST /path/advisor` | ✅ Fulfilled, unused | RAG-grounded Q&A advisor over the learner's path; no chat/advisor screen exists. |

Advisor, Writing and Speaking still need frontend flows; Speaking also needs
server-side upload safety and raw-audio deletion before it can be accepted.

## 4. Admin (React) gap analysis

`src/admin` has no real pages yet (default Vite/React scaffold). Its need
is read from `MVP_architecture.md` §4.4/§5.2/§8.4/§10.9 (Admin CMS +
Analytics).

| Feature (from MVP spec) | Status | Notes |
|---|---|---|
| Admin login / role separation | ⚠️ Backend-ready | `User.Role`, JWT role claim, Admin policy and secret-driven bootstrap exist; Admin React login/guard and Admin CRUD authorization are still missing. The legacy import route remains development-only until Phase 4 replaces it. |
| Skill management (create/edit/delete, assign prerequisites) | ⚠️ Partial | `GET /skills`, `GET /skills/graph` exist (read-only). No create/update/delete route exists for skills at all. |
| Lesson management | ⚠️ Partial | `Lesson`, `LessonItem`, content version/checksum and learner attempt APIs exist. Draft/publish CRUD, validation preview/import and Admin UI remain Phase 4 work. |
| Question management (create/edit/delete, assign answer/difficulty/CEFR) | ⚠️ Partial | `POST /admin/items/import` (bulk create, dev-gated) and `GET /items` (read, filterable by skill/CEFR) exist. No single-item create, no update, no delete. |
| User / skill / question analytics | ❌ Missing | No `/admin/analytics/*` (or equivalent) route exists anywhere in the API — no user counts, no weak-skill aggregation, no question error-rate. |

Net: essentially the entire admin surface is either missing or
read-only-at-best. Before any admin page can go live, it needs its own
foundational work (see Integration Options below), not just "point the UI
at existing endpoints" like most of mobile's gaps.

## 5. Cross-cutting gaps

- **CORS and role foundations are complete**, but Phase 4 must apply the Admin
  policy to every new CRUD/import/analytics mutation and add browser route guards.
- **Lesson domain is complete on the learner API and wired on mobile**, including
  versioned content, attempts, feedback and completion. Admin draft/publish
  tooling and device E2E remain.
- **Idempotency is enforced server-side** for start/answer/completion, review
  grading and rewards; the lesson/review clients retain operation UUIDs across
  uncertain retries and block duplicate taps.

## 6. Integration options

Concrete next steps, ordered by dependency:

1. **Run the full learner loop on MuMu/device**, including offline retry,
   application restart and temporary ML unavailability.
2. **Build Admin Skills/Lessons/Items CRUD and two-step import** using the
   existing Admin role policy, then replace the Vite scaffold with guarded pages.
3. **Wire Advisor, Writing and Speaking mobile flows**; Speaking still requires
   MIME/size/duration validation and guaranteed raw-audio deletion first.
4. **Add learning analytics/event APIs** now that lesson traffic and the reward
   ledger exist, so
   completion, correctness and item-difficulty reports have real inputs.
5. **Consider client codegen from OpenAPI for Admin** once CRUD contracts stop
   changing; Flutter can keep its existing hand-written repository pattern.
