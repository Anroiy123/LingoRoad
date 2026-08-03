# API Catalog — LingoRoad `.NET` API

Base URL (dev): `http://localhost:5000`. Auth: JWT Bearer (`Authorization:
Bearer <token>`), see `auth-and-integrations.md`. "JWT" in the Auth column
means the route (or its group) has `.RequireAuthorization()` and reads the
caller's identity via `ClaimsPrincipal.UserId()`.

## Health
| Verb | Route | Auth | Notes |
|---|---|---|---|
| GET | `/health` | none | Returns plain text `"ok"`, defined inline in `Program.cs` |

## Auth — `Endpoints/AuthEndpoints.cs`, group `/auth`
| Verb | Route | Auth | Request | Response | Notes |
|---|---|---|---|---|---|
| POST | `/auth/register` | none | `{email, password, name?}` | 201 `{token}` | 400 `password_too_short` if `< 8` chars; 409 `email_taken`; BCrypt-hashes password |
| POST | `/auth/login` | none | `{email, password}` | 200 `{token}` | 401 if user not found or `BCrypt.Verify` fails |

## Skills — `Endpoints/SkillEndpoints.cs`, mapped on bare `app`
| Verb | Route | Auth | Response |
|---|---|---|---|
| GET | `/skills` | none | `[{id, code, name, nameVi, category, parentId?, cefrLevel}]` |
| GET | `/skills/graph` | none | `{nodes: [Skill...], edges: [{from, to}]}` (edges = prerequisite→skill) |

## Items — `Endpoints/ItemEndpoints.cs`, mapped on bare `app`
| Verb | Route | Auth | Request | Response | Notes |
|---|---|---|---|---|---|
| GET | `/items` | none | query `?skill=&cefr=` (optional) | `[{id, skillCode, cefrLevel, type, stem, options[], correctAnswer, a, b, c, audioUrl?}]` | joins Items→Skills |
| POST | `/admin/items/import` | **none** — gated by `IsDevelopment()` at registration time, not auth | `[{skillCode, cefrLevel, type, stem, options[], correctAnswer, source, a?, b?, c?, audioUrl?}]` | 200 `{imported: count}` | 400 `unknown_skill`; missing IRT params default: `a=1.0`, `b` from a per-CEFR table (A1=-2.0 … C2=2.2), `c=1/options.Length` |

## Placement — `Endpoints/PlacementEndpoints.cs`, group `/placement`, JWT on group
Stop rule constants: `MinItems=8`, `MaxItems=30`, `SeThreshold=0.35`.

| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/placement/status` | — | `{completed: bool}` | true if any `TestSession` with `Status=="completed"` for caller |
| POST | `/placement/start` | — | 200 `{sessionId, item}` / 409 `empty_item_bank` / 503 | creates `TestSession`, calls ML `POST /cat/select` |
| POST | `/placement/{sessionId}/answer` | `{itemId, answer}` | 200 `{done:false, item}` or `{done:true, theta, se, cefr}` / 404 / 409 `session_completed` / 400 `unknown_item` / 503 | grades (case-insensitive trim match), writes `Response`, calls `MasteryService`, re-queries ML for next item; stops at `count≥30 \|\| (count≥8 && se<0.35) \|\| ML returns no next item` |
| GET | `/placement/{sessionId}/result` | — | `{theta, se, cefr, itemsAnswered, status}` / 404 |

`PlacementItemDto` never includes `correctAnswer`.

## Mastery — `Endpoints/MasteryEndpoints.cs`, mapped on bare `app`, JWT per-route
| Verb | Route | Response |
|---|---|---|
| GET | `/mastery` | `[{skillCode, skillName, pCorrect, updatedAt}]` for the caller |

## Reviews (spaced repetition) — `Endpoints/ReviewEndpoints.cs`, group `/reviews`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/reviews/cards` | `{skillCode, front, back}` | 201 `{id, front, back, due, state}` | 400 unknown skill |
| GET | `/reviews/due` | — | `[{id, front, back, due, state}]` | filters `Due ≤ UtcNow`, ordered by `Due` |
| POST | `/reviews/{cardId}/grade` | `{rating: 1-4}` | 200 `{id, due, state, stability, difficulty}` | 400 if rating outside 1–4; 404; runs `Fsrs.Review` |

## Path — `Endpoints/PathEndpoints.cs`, group `/path`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/path` | query `?limit=N` (default 10) | `[{code, name, nameVi, cefr, mastery, reason}]` | `PathBuilder.Build` — see `domain-model.md` |
| POST | `/path/advisor` | `{question}` | 200 `{answer}` / 503 | builds path context (limit 10), calls ML `POST /llm/advisor` |

## Exercises — `Endpoints/ExerciseEndpoints.cs`, group `/exercises` + one bare route, JWT
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/exercises/generate` | `{skillCode, type?}` | 200 `[{id, stem, options}]` / 400 `unknown_skill` / 503 | never returns the answer; calls ML `/llm/exercises`; `type` defaults `"mcq"`; count fixed at 3 |
| POST | `/exercises/{id}/submit` | `{answer}` | 200 `{correct, correctAnswer, explanationVi}` / 404 | idempotent — mastery only updated on first submit (`AnsweredAt is null` check) |
| POST | `/writing/evaluate` | `{taskPrompt, essay}` | 200 = ML `AweResponse` / 503 | proxies straight to ML `/llm/awe`, no persistence |

## Speaking — `Endpoints/SpeakingEndpoints.cs`, group `/speaking`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/speaking/attempts` | multipart: `audio` file + `promptText` form field | 200 `{attemptId, transcript, accuracy, completeness, fluency, total, feedbackVi}` / 503 | `.DisableAntiforgery()` (multipart bypasses antiforgery pairing); saves to `wwwroot/uploads/{guid}{ext}` (whitelist `.webm .mp3 .wav .m4a .ogg`, else `.bin`); streams to ML `/speech/score`; **deletes the uploaded file on ML failure** (best-effort) before returning 503 |
| GET | `/speaking/attempts` | — | `[{id, promptText, transcript, total, createdAt}]` desc by `createdAt` |

## Admin — `Endpoints/AdminEndpoints.cs`, group `/admin`, `.RequireAuthorization("Admin")`
Cheat code for a local admin account: set `BootstrapAdmin:Email` /
`BootstrapAdmin:Password` (password ≥12 chars, valid email) in
`appsettings.Development.json` — already set in this repo to
`admin@lingoroad.dev` / `LingoRoadAdmin123!`. `AdminBootstrapper` (called
from `Program.cs` on every Development-environment startup) creates or
promotes that user to `Role=Admin`; log in via `POST /auth/login` with those
credentials. `TestAppFactory` blanks both keys so tests never touch a
real/broken DB at startup.

| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/admin/skills` | — | `[{id, code, name, nameVi, category, parentId?, cefrLevel}]` | |
| POST | `/admin/skills` | `AdminSkillRequest` | 201 `{id}` / 400 `validation_failed` / 409 `skill_code_taken` | |
| PUT | `/admin/skills/{id}` | `AdminSkillRequest` | 204 / 400 `parent_cycle`\|`unknown_parent` / 404 / 409 | |
| DELETE | `/admin/skills/{id}` | — | 204 / 404 / 409 `skill_in_use` | soft delete (`IsDeleted=true`) |
| GET | `/admin/items` | — | `[{id, stableId?, skillId, skillCode, cefrLevel, type, stem, options[], correctAnswer, explanationVi?, source, license?, reviewer?, contentVersion?, a, b, c, audioUrl?}]` | |
| POST | `/admin/items` | `AdminItemRequest` | 201 `{id}` / 400 / 409 `item_stable_id_taken` | |
| PUT | `/admin/items/{id}` | `AdminItemRequest` | 204 / 400 / 404 / 409 | |
| DELETE | `/admin/items/{id}` | — | 204 / 404 / 409 `item_in_use` | soft delete |
| POST | `/admin/items/generate` | `{skillCode, cefrLevel, type, count}` | 201 `{generated, items:[...]}` / 400 `unknown_skill`\|`invalid_cefr`\|`unsupported_item_type` / 503 | AI-generates items straight into the Item bank via ML `/llm/exercises` (same `IMlClient.GenerateExercisesAsync` call as `/exercises/generate`); `type` restricted to `mcq`\|`cloze` (no `reorder`/`listening_mcq` — text generation can't produce audio); `count` clamped 1–20; rate-limited `ml-upload`; one batch `Audit(..., "generate", "item", skillCode)` entry; IRT seeded the same way as content import (`a=1`, `b=CefrDifficulty(cefr)`, `c=1/options.Length`); no draft/approval status — admin reviews/edits/deletes via the existing item CRUD routes above |
| GET | `/admin/lessons` | — | `[{id, stableId, slug, title, titleVi, descriptionVi?, skillId, skillCode, cefrLevel, order, isPublished, itemIds[], ...}]` | |
| POST | `/admin/lessons` | `AdminLessonRequest` | 201 `{id}` / 400 / 409 | |
| PUT | `/admin/lessons/{id}` | `AdminLessonRequest` | 204 / 400 / 404 / 409 | |
| DELETE | `/admin/lessons/{id}` | — | 204 / 404 | soft delete + unpublish |
| POST | `/admin/imports/validate` | `AdminImportRequest` | 200 `{valid, checksum, counts, errors[]}` | dry-run, no writes |
| POST | `/admin/imports` | `AdminImportRequest` | 200 `{replay, version, checksum}` / 400 / 409 `import_version_changed` | transactional, checksum-idempotent (`ContentBundleImport`); replay-safe on identical resubmit |
| GET | `/admin/analytics/overview` | — | learners/active-learners/completions/answers/mastery-by-category/item-usage/content-counts | |
| GET | `/admin/analytics/learning-quality` | — | calibration/drift/fairness report, each `insufficient_sample` under `minimumSampleSize=30` | via `LearningQualityService` |
| GET | `/admin/audit` | `?limit=` (default 50, clamp 1–200) | `[AdminAuditEvent]` desc by `CreatedAt` | |
| GET | `/admin/users` | `?search=&role=&limit=&offset=` | `{total, users:[{id, email, name, role, targetCefr, createdAt}]}` | `search` = case-insensitive substring on email/name; `role` = exact match; `limit` default 50 clamp 1–200; never returns `passwordHash` |
| GET | `/admin/users/{id}` | — | profile fields + `mastery:[{skillCode, skillName, pCorrect, updatedAt}]` + `activity:{lessonsCompleted, exercisesAnswered, exercisesCorrect, dueReviews, lastActiveAt}` / 404 | read-only, no `Audit(...)` entry (consistent with every other GET under `/admin`) |

Mutations write an `AdminAuditEvent` via the `Audit(...)` helper; GET routes
never do.

## Shared error shape
Every route that calls `IMlClient` returns `503
{"error":"ml_service_unavailable"}` via `ApiResults.MlUnavailable()` when
the ML service is unreachable or times out — see
`auth-and-integrations.md` for the exact mechanism.
