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

The `.NET` API exposes 23 routes across 10 feature groups: Health, Auth,
Skills, Items, Placement, Mastery, Reviews (spaced repetition
*(lặp lại ngắt quãng)*), Path (learning-path recommendation + advisor),
Exercises (incl. writing evaluation), and Speaking. This summary does not
duplicate every route's verb, auth requirement and request/response shape.

As of this report, browsing `http://localhost:5000/scalar/v1` (dev only)
gives an interactive view of the same surface, generated from the
`Microsoft.AspNetCore.OpenApi` document already wired up in `Program.cs`.

## 2. Feature availability matrix

A quick-scan overview of every feature domain across all three surfaces,
before the detailed per-client breakdowns in §3/§4. `—` means the domain
doesn't apply to that surface (e.g. Admin has no placement-test UI).

| Feature domain | Backend (`.NET`) | Mobile (Flutter) | Admin (React) |
|---|---|---|---|
| Auth (register/login) | ✅ `/auth/register`, `/auth/login` | ✅ Wired (`ApiAuthRepository`) | ❌ No role-aware login — same endpoint as learners, no role check |
| Onboarding (goal, daily study minutes) | ❌ No endpoint (`User.TargetCefr` column exists but nothing reads/writes it over HTTP) | ❌ No onboarding screen | — |
| Skill graph (read) | ✅ `/skills`, `/skills/graph` | ⚠️ Not consumed at all — Progress screen uses a static 6-skill list, no call to `/skills` anywhere in the app | ⚠️ Read-only if wired; no create/update/delete |
| Skill/Item management (write) | ⚠️ Bulk import only (`/admin/items/import`, dev-gated); no single create/update/delete | — | ❌ No CRUD UI exists |
| Lesson management | ❌ No `Lessons` entity — collapsed into `Items` | — | ❌ Missing (MVP spec expected this) |
| Placement test | ✅ Full adaptive-test flow (start/answer/result) | ✅ Wired (`ApiPlacementRepository`) | — |
| Learning path (recommendation) | ✅ `/path` (`PathBuilder`) | ✅ Wired (`ApiLearningPathRepository`) | — |
| Learning-path advisor (Q&A) | ✅ `/path/advisor` (RAG) | ❌ No chat/advisor screen | — |
| Mastery tracking | ✅ `/mastery` | ⚠️ Mocked — Progress screen's static skill list, not driven by real data | ❌ No aggregate/per-user view |
| Spaced-repetition reviews (SRS) | ✅ Full FSRS flow (`/reviews/*`) | ⚠️ Mock-backed — four grade controls exist, but cards are static and no `/reviews/*` endpoint is called | — |
| Exercises (MCQ + grading) | ✅ `/exercises/generate`, `/exercises/{id}/submit` | ❌ No exercise screen | — |
| Writing evaluation (AWE) | ✅ `/writing/evaluate` | ❌ No writing screen | — |
| Speaking assessment | ✅ `/speaking/attempts` (upload, score, history) | ❌ No recording UI (audio *playback* only) | — |
| User profile (read/update) | ⚠️ `GET /auth/me` exists; no authenticated update endpoint | ⚠️ Read is wired via `ApiAuthRepository.getProfile`; target/preferences/password updates are missing and toggles remain local state | — |
| Dashboard / gamification (XP, streak, badges) | ❌ No concept anywhere in the domain model | ❌ Hardcoded (Home's quests, Progress's streak/XP/badges) | ❌ Missing (MVP spec expected a stats view) |
| Admin auth / roles | ❌ No `Role`/`IsAdmin` field on `User` | — | ❌ Missing — blocks any real admin-gated route |
| Analytics (user/skill/question) | ❌ No `/admin/analytics/*` routes | — | ❌ Missing |
| Cross-origin access (CORS) | ❌ No CORS policy configured | — (native app, not affected) | ❌ Blocks every browser call, regardless of endpoint |

## 3. Mobile (Flutter) gap analysis

The tables below derive the mobile mock-vs-live split from the current client
code and reframe it against backend capability.

### 3.1 Already wired to the real API

| Feature | Status | Notes |
|---|---|---|
| Auth (login/register) | ✅ Fulfilled | `ApiAuthRepository` → `/auth/register`, `/auth/login`. |
| Profile (read) | ✅ Fulfilled | `ApiAuthRepository.getProfile` → `GET /auth/me`. `ProfileScreen` handles loading/error/retry and renders the name plus current level/CEFR and badge/profile statistics from the response; email is only used as a fallback to derive the display name. Although `targetCefr` is parsed, the target tile remains localized hardcoded UI and does not render it. Profile/onboarding updates are not covered by this read path. |
| Placement test | ✅ Fulfilled | `ApiPlacementRepository` → `/placement/status`, `/placement/start`, `/placement/{sessionId}/answer`, `/placement/{sessionId}/result`. |
| Learning Path | ✅ Fulfilled | `ApiLearningPathRepository` → `GET /path?limit=N`, parsed into `LearningPathStep(code, name, nameVi, cefr, mastery, reason)` — matches the endpoint's actual shape exactly. Wired since this report was first drafted (`mock_repository.dart`'s old `path()`/`PathNode` mock was removed); the screen was redesigned around what `/path` returns rather than the old lesson-tree/XP mock — see §6 item 3 (resolved). |

### 3.2 Review and Progress integration update (2026-08-01)

Review now consumes authenticated `GET /reviews/due` and posts explicit ratings to
`POST /reviews/{cardId}/grade`. The grade request carries an operation UUID and
expected repetition count, so manual retry after an uncertain outcome is
idempotent. `POST /reviews/cards` remains a future Lesson/Exercise producer API,
therefore an empty Review state is valid.

Progress now joins public `GET /skills` with authenticated `GET /mastery` and
shows aggregated leaf-skill categories. XP, streaks, CEFR, achievements and
dashboard summaries remain unavailable because no backing API exists.

### 3.3 Historical mock gap snapshot

| Screen | Mock data shape | Closest backend endpoint | Status | Recommendation |
|---|---|---|---|---|
| Progress | `SkillProgress(skillKey, percent, icon)` — 6 hardcoded skills | `GET /mastery` → `[{skillCode, skillName, pCorrect, updatedAt}]` | ⚠️ Partial | The endpoint returns the right kind of data (`pCorrect` → `percent`), but mobile's 6 skills are a static localization-key list, not driven by the real skill graph (`GET /skills`, 156 leaf skills) or the caller's actual mastery rows. Needs a mapping from returned `skillCode`s to display/i18n keys and icons, and handling for skills the endpoint hasn't returned yet (unpracticed skills). |
| Review | `ReviewCardData(wordKey, meaningKey, exampleKey, categoryKey)` — 3 static flashcards with Forgot/Hard/Good/Easy controls | `GET /reviews/due`, `POST /reviews/cards`, `POST /reviews/{cardId}/grade` | ⚠️ Partial | The four grade controls are present, but the screen still loads `const MockRepository().reviews()`. It has no due-date/API loading/error/empty states, no double-submit guard, and neither fetches due cards nor posts a grade. Nothing currently calls `POST /reviews/cards` to create a card in the first place — that has to happen somewhere (e.g. after a wrong exercise answer) before there's anything to review. |
| Home | `DailyQuest(key, current, target, icon)` — daily quests | none | ❌ Missing | No daily-quest/goal concept (or XP/streak/badge tracking) exists anywhere in the `.NET` domain model. Note: `progress_screen.dart` also hardcodes streak ('12'-day), XP ('1.240'), badge counts ('12/48'), and quest progress ('2/3') inline, with no backend equivalent — this is a net-new feature, not a wiring task. |

### 3.3 Backend capability with no mobile UI at all yet

These are fully built and tested on the backend (per
`src/backend/.superpowers/sdd/progress.md`, tasks 13/14), but no mobile
screen calls them:

| Backend capability | Status | Notes |
|---|---|---|
| `POST /exercises/generate`, `POST /exercises/{id}/submit` | ✅ Fulfilled, unused | AI-generated MCQ exercises with grading + explanation; no lesson/exercise screen exists in `lib/screens/`. |
| `POST /writing/evaluate` | ✅ Fulfilled, unused | Automated writing evaluation (AWE); no writing-practice screen exists. |
| `POST /speaking/attempts`, `GET /speaking/attempts` | ✅ Fulfilled, unused | Speech scoring (accuracy/completeness/fluency) from an uploaded audio recording; mobile only has audio *playback* (`placement_audio_player.dart`, listening items), no recording UI. |
| `POST /path/advisor` | ✅ Fulfilled, unused | RAG-grounded Q&A advisor over the learner's path; no chat/advisor screen exists. |

These four are the cheapest wins in the whole report: no backend work
needed, only frontend screens plus wiring.

## 4. Admin (React) gap analysis

`src/admin` has no real pages yet (default Vite/React scaffold). Its need
is read from `MVP_architecture.md` §4.4/§5.2/§8.4/§10.9 (Admin CMS +
Analytics).

| Feature (from MVP spec) | Status | Notes |
|---|---|---|
| Admin login / role separation | ❌ Missing | `Domain/User.cs` has no role/`IsAdmin` field at all; `/auth/login` is the same endpoint for every caller. The one admin-flavored route (`POST /admin/items/import`) is gated by `IsDevelopment()`, not by identity or role. |
| Skill management (create/edit/delete, assign prerequisites) | ⚠️ Partial | `GET /skills`, `GET /skills/graph` exist (read-only). No create/update/delete route exists for skills at all. |
| Lesson management | ❌ Missing | The MVP spec's separate `Lessons` entity (grouping questions, `LESSON_QUESTIONS` join) was never built — the actual schema only has `Items` (skill+CEFR-tagged questions), with no lesson grouping concept. This reads as a product decision to revisit (does LingoRoad still want a "lesson" as a unit, or has it settled on skill-tagged items directly?), not just a missing CRUD screen. |
| Question management (create/edit/delete, assign answer/difficulty/CEFR) | ⚠️ Partial | `POST /admin/items/import` (bulk create, dev-gated) and `GET /items` (read, filterable by skill/CEFR) exist. No single-item create, no update, no delete. |
| User / skill / question analytics | ❌ Missing | No `/admin/analytics/*` (or equivalent) route exists anywhere in the API — no user counts, no weak-skill aggregation, no question error-rate. |

Net: essentially the entire admin surface is either missing or
read-only-at-best. Before any admin page can go live, it needs its own
foundational work (see Integration Options below), not just "point the UI
at existing endpoints" like most of mobile's gaps.

## 5. Cross-cutting gaps

- **No CORS policy** on the `.NET` API (already flagged in
  `src/backend/CLAUDE.md`). This blocks *any* browser-based client —
  including `admin` — from calling the API at all, regardless of which
  endpoints exist. This has to be solved before `admin` can call anything,
  even `GET /skills`.
- **No admin role/authorization concept** in the data model (see above) —
  a prerequisite for gating any real admin route behind authentication
  rather than `IsDevelopment()`.
- **The `Lessons` entity was never built.** Flagged once here as a
  cross-cutting note because it affects both the Admin table (lesson
  management) and, implicitly, mobile's learning-path/exercise screens
  (which page of content does a "lesson" correspond to, if there is no
  lesson?).

## 6. Integration options

Concrete, scoped next steps — not full API designs. Roughly ordered by
leverage (cheapest wins first):

1. **Wire mobile's four fully-built-but-unused backend features**
   (exercises, writing evaluation, speaking, advisor) to new screens. Zero
   backend work; this is the single highest-leverage gap in the report.
2. **Rewire the Progress and Review tab screens** to `GET /mastery` and the
   `/reviews/*` trio respectively, replacing `MockRepository` calls one at
   a time — both endpoints already return data close to what's needed,
   following the existing `ApiPlacementRepository`/`ApiAuthRepository`
   pattern (abstract interface + `Api*` implementation).
3. ~~Decide the Learning Path / gamification question before building
   it~~ — **Resolved.** The screen has since been redesigned around what
   `/path` actually returns (an ordered, reasoned skill recommendation
   list: `code/name/nameVi/cefr/mastery/reason`) rather than the old
   lesson-tree-with-XP mock; see §3.1.
4. **Add a CORS policy** to the `.NET` API — required before `admin` can
   call anything at all. Scope it to the admin dev origin(s) only.
5. **Add an admin role.** Minimally, a `Role` (or `IsAdmin`) field on
   `User`, checked via a JWT claim, replacing the `IsDevelopment()` gate on
   `/admin/items/import` and gating any future admin-only route the same
   way.
6. **Build real Skills/Items CRUD** (single create, update, delete) once
   the role exists — bulk import already covers create-at-scale, but an
   admin UI needs single-record operations.
7. **Resolve the Lessons-entity question** with the product owner before
   building lesson management — either build the entity, or drop "lesson
   management" from the admin scope in favor of "question/skill
   management" as already implemented.
8. **Add an authenticated profile/onboarding update API alongside
   `GET /auth/me`** (for example `PUT` or `PATCH /auth/me`) for target CEFR,
   daily goal, purpose/focus skills and preferences. Profile read already
   exists and is wired on mobile. If `/users/me` is preferred as the public
   convention, standardize the existing read and the new write route together
   instead of treating read as missing.
9. **Client codegen from OpenAPI, optionally.** Now that the `.NET` API has
   a machine-readable OpenAPI document (surfaced via Scalar at
   `/scalar/v1`), `admin` could generate a typed TS client (e.g.
   `openapi-typescript`) instead of hand-writing fetch calls — worth it
   once admin has enough endpoints to justify it. Mobile's existing
   hand-written `ApiClient` pattern is deliberate and doesn't need to
   change.
10. **Analytics endpoints are the least urgent** — they depend on having
    real usage data (users, attempts) to aggregate, which is thin in
    dev/seed data anyway.
