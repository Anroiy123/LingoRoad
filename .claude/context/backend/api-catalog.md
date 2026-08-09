# API Catalog — LingoRoad `.NET` API

Base URL (dev): `http://localhost:5000`. Auth: JWT Bearer (`Authorization:
Bearer <token>`), see `auth-and-integrations.md`. "JWT" in the Auth column
means the route (or its group) has `.RequireAuthorization()` and reads the
caller's identity via `ClaimsPrincipal.UserId()`.

## Health
| Verb | Route | Auth | Notes |
|---|---|---|---|
| GET | `/health` | none | Returns plain text `"ok"`, defined inline in `Program.cs` |
| GET | `/ready` | none | 200 `{status:"ready", database:"ready"}` / 503 `{status:"not_ready", database:"unavailable"}` (same shape on exception), defined inline in `Program.cs`; checks `db.Database.CanConnectAsync()` |

## Auth — `Endpoints/AuthEndpoints.cs`, group `/auth`
`/auth` has no group-level `.RequireAuthorization()` — auth is set per-route below.

| Verb | Route | Auth | Request | Response | Notes |
|---|---|---|---|---|---|
| POST | `/auth/register` | none | `{email, password, name?}` | 201 `{token, accessToken, refreshToken}` | 400 `invalid_email`\|`password_too_short` (`<8` or null)\|`password_too_long` (`>128`)\|`name_too_long` (`>100`); 409 `email_taken`; BCrypt-hashes password; issues a `RefreshSession` (30-day expiry, new `FamilyId`); `token`/`accessToken` are the same value; rate-limited `auth-write` |
| POST | `/auth/login` | none | `{email, password}` | 200 `{token, accessToken, refreshToken}` | 401 if user not found or `BCrypt.Verify` fails; logs a `SecurityAuditEvent` (`login_failed`/`login_succeeded`); rate-limited `auth-write` |
| POST | `/auth/refresh` | none | `{refreshToken}` | 200 `{token, accessToken, refreshToken}` / 401 | rotates the refresh token within its family (`RefreshSession.FamilyId`/`ReplacedById` chain); **reuse of an already-revoked token** revokes every active session in that family and logs `refresh_reuse_detected` (theft-detection); also 401 if token unknown/expired or user missing; a `DbUpdateConcurrencyException` (two concurrent refreshes racing on the same token) is treated the same as reuse; rate-limited `refresh` |
| POST | `/auth/logout` | none | `{refreshToken}` | 204 | revokes the given session if found and not already revoked; always 204 (no error if token missing/unknown — logout is best-effort); rate-limited `refresh` |
| POST | `/auth/change-password` | JWT | `{currentPassword, newPassword}` | 204 / 400 `password_too_short`\|`password_too_long` / 400 `current_password_invalid` / 404 | revokes **all** of the caller's active refresh sessions (forces re-login on other devices); logs `SecurityAuditEvent` `password_changed` |
| PATCH | `/auth/me` | JWT | `UpdateProfileRequest`: `{targetCefr?, dailyGoalMinutes?, learningPurpose?, focusSkillIds?, studyReminderEnabled?, reminderTime?, timeZone?, emailNotifications?, appUpdates?}` (all optional — partial update) | 200 = same shape as GET `/auth/me` / 404 | 400 `invalid_target_cefr` (not in `A1`\|`A2`\|`B1`\|`B2`)\|`invalid_daily_goal` (outside 10–120)\|`learning_purpose_too_long` (`>100`)\|`timezone_too_long` (`>100`)\|`invalid_reminder_time` (not `HH:mm`)\|`invalid_focus_skill` (unknown skill id); setting `targetCefr` also sets `TargetCefrConfirmed=true` (`AddTargetCefrConfirmation`); `focusSkillIds` replaces the caller's `UserFocusSkill` rows wholesale when provided |
| GET | `/auth/me` | JWT | — | 200 `{id, email, name, targetCefr, targetCefrConfirmed, cefrLevel, level, badgesCount, dailyGoalMinutes, learningPurpose, focusSkillIds, studyReminderEnabled, reminderTime, timeZone, emailNotifications, appUpdates, role}` / 404 | `name` falls back to the email's local-part; `cefrLevel` = last completed placement session's result (default `"A1"`); `level` = `masteryCount/3 + 1`; `badgesCount` tiered on `masteryCount` (≥5→3, ≥2→2, else 1) |
| DELETE | `/auth/me` | JWT | — | see **Privacy** section below | account-deletion request; handler actually lives in `Endpoints/PrivacyEndpoints.cs` (`RequestDeletionAsync`), mapped onto the bare `/auth/me` route from that file |

`AddIdentityProfileSecurity` migration = the refresh-token/family/reuse-detection machinery above; `AddTargetCefrConfirmation` = the `TargetCefrConfirmed` flag.

## Skills — `Endpoints/SkillEndpoints.cs`, mapped on bare `app`
| Verb | Route | Auth | Response |
|---|---|---|---|
| GET | `/skills` | none | `[{id, code, name, nameVi, category, parentId?, cefrLevel}]` |
| GET | `/skills/graph` | none | `{nodes: [Skill...], edges: [{from, to}]}` (edges = prerequisite→skill) |

## Items — `Endpoints/ItemEndpoints.cs`, mapped on bare `app`
| Verb | Route | Auth | Request | Response | Notes |
|---|---|---|---|---|---|
| GET | `/items` | none | query `?skill=&cefr=` (optional) | `[{id, skillCode, cefrLevel, type, stem, options[], a, b, c, audioUrl?}]` | joins Items→Skills; **`ItemDto` never includes `correctAnswer`** (a previous revision of this doc listed it — that was stale/wrong) |

⚠️ `POST /admin/items/import` (previously documented here as a dev-only,
`IsDevelopment()`-gated seed route) **no longer exists** — grepped the whole
`Endpoints/` folder, no trace of it. Item authoring today is: `POST
/admin/items` (single item, Admin-authorized), `POST /admin/imports`
(transactional bulk import), and `POST /admin/items/generate`
(AI-authored) — all three documented under **Admin** below.

## Placement — `Endpoints/PlacementEndpoints.cs`, group `/placement`, JWT on group
Stop rule constants: `MinItems=8`, `MaxItems=30`, `SeThreshold=0.35`. Only
`mcq`/`listening_mcq` items are eligible candidates (`cloze`/`reorder` stay
lesson-only — their interaction model doesn't fit the CAT client).

| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/placement/status` | — | `{completed: bool}` | true if any `TestSession` with `Status=="completed"` for caller |
| POST | `/placement/start` | — | 200 `{sessionId, item}` / 409 `empty_item_bank` / 503 | creates `TestSession`, calls ML `POST /cat/select` |
| POST | `/placement/{sessionId}/answer` | `{itemId, answer}` | 200 `{done:false, item}` or `{done:true, theta, se, cefr}` / 400 `item_id_required`\|`answer_required` / 404 / 409 `session_completed`\|`item_not_issued`\|`answer_already_recorded`\|`placement_state_invalid` / 503 | grades (case-insensitive trim match), writes `Response`, calls `MasteryService`, re-queries ML for next item; stops at `count≥30 \|\| (count≥8 && se<0.35) \|\| ML returns no next item`; **`HardenPlacementIntegrity` anti-cheat**: re-submitting the *currently issued* item's id with the *same* answer replays the already-stored result idempotently (200, not a new grade); same item id with a *different* answer → `409 answer_already_recorded`; submitting any item id other than `session.CurrentItemId` → `409 item_not_issued`; a `DbUpdateException` race (e.g. duplicate concurrent submit) also falls back to the replay check before rethrowing |
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
| GET | `/reviews/due` | — | `[{id, front, back, due, state, reps}]` | filters `Due ≤ UtcNow`, ordered by `Due` |
| GET | `/reviews/mistakes` | — | `[{id, front, back, due, state, reps}]` | caller's `ReviewCard`s where `SourceExerciseId != null` (mistake-derived only — created by `/lesson-attempts/{id}/complete` for wrong answers, see Lessons section); **not** filtered by due date, unlike `/reviews/due` |
| POST | `/reviews/{cardId}/grade` | `{rating: 1-4, operationId, expectedReps}` | 200 `{id, operationId, due, state, stability, difficulty, reps}` | **`AddReviewGradeOperations` idempotency-key pattern**: 400 `rating_1_to_4`\|`invalid_grade_request` (`operationId==Guid.Empty` or `expectedReps<0`); 404 (card not found/not owned); 409 `idempotency_conflict` (same `operationId` replayed with a different `cardId`/`rating`/`expectedReps`), `review_not_due` (`card.Due > now`), `review_already_graded` (`card.Reps != expectedReps` — stale optimistic-concurrency token, i.e. someone already graded it); replaying the exact same operation returns the original 200 snapshot rather than re-grading; runs `Fsrs.Review`; also writes a `LearningEvent` (`ReviewGraded`) and a `RewardLedgerEntry` (5 XP, 1 coin, quest `daily_review`) |

## Path — `Endpoints/PathEndpoints.cs`, group `/path`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/path` | query `?limit=N` (default 10) | `[{code, name, nameVi, cefr, mastery, reason}]` | `PathBuilder.Build` — see `domain-model.md` |
| POST | `/path/advisor` | `{question}` | 200 `{answer}` / 400 `invalid_question` / 503 `ml_service_unavailable` or `feature_disabled` | 400 if `question` blank or `>1000` chars; gated by `MlFeatureRollout.IsEnabled(config, env, "Advisor", userId)` — deterministic per-user SHA256-hash rollout, config key `MlFeatures:AdvisorRolloutPercent` (default 100% in dev, 0% in prod) → `503 feature_disabled` if the caller isn't in the rollout bucket; builds path context (limit 10), calls ML `POST /llm/advisor`; `MlInputRejectedException` → `ApiResults.MlRejected` (mirrors ML's own 400/413/415/422 status + error code); rate-limited `ml-upload` |

Note: `GET /path/today` (today's recommended lessons) is also served under
the `/path` prefix, but its handler is defined in
`Endpoints/LessonEndpoints.cs`, not this file — see the Lessons section.

## Exercises — `Endpoints/ExerciseEndpoints.cs`, group `/exercises` + one bare route, JWT
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/exercises/generate` | `{skillCode, type?}` | 200 `[{id, stem, options}]` / 400 `unknown_skill`\|`unsupported_exercise_type` / 503 | never returns the answer; `type` defaults `"mcq"`, restricted to `mcq`\|`cloze`\|`reorder`; count fixed at 3; calls ML `/llm/exercises`; `MlInputRejectedException` → `ApiResults.MlRejected`; **on `MlServiceUnavailableException`, falls back to up to 3 existing `Item`s** of the same skill+type (ordered by `StableId`, `IsDeleted==false`) instead of failing outright — only returns `503 ml_service_unavailable` if no fallback items exist either; rate-limited `ml-upload` |
| POST | `/exercises/{id}/submit` | `{answer, operationId}` | 200 `{exerciseId, operationId, correct, correctAnswer, explanationVi}` / 400 `answer_and_operation_id_required` / 404 / 409 `exercise_already_answered`\|`idempotency_conflict` | idempotency-key pattern (`ExerciseAnswerOperation`): replaying the same `operationId` with the same `id`+`answer` returns the original snapshot instead of re-grading; mastery only updated on first submit; also writes a `LearningEvent` (`AnswerSubmitted`, includes `PredictedCorrectness` from the pre-answer mastery estimate and `LatencyMs`) |
| POST | `/writing/evaluate` | `{taskPrompt, essay}` | 200 = ML `AweResponse` / 400 `invalid_writing_submission` / 503 `ml_service_unavailable` or `feature_disabled` | mapped on bare `app` (not the `/exercises` group) but explicitly `.RequireAuthorization().RequireRateLimiting("ml-upload")`; 400 if `taskPrompt` blank/`>2000` chars or `essay` blank/`>10000` chars; gated by `MlFeatureRollout.IsEnabled(..., "Writing", userId)` (config key `MlFeatures:WritingRolloutPercent`) → `503 feature_disabled` outside rollout; proxies straight to ML `/llm/awe`, no persistence; `MlInputRejectedException` → `ApiResults.MlRejected` |

## Lessons — `Endpoints/LessonEndpoints.cs`, mapped on bare `app`, JWT per-route
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/path/today` | — | `[{id, slug, title, titleVi, skillCode, cefr, itemCount, completed, mastery}]` | despite the `/path` prefix this handler lives here, not in `PathEndpoints.cs`; up to 3 published lessons at/under the caller's `TargetCefr` that are either never attempted or whose skill mastery is `<0.8`, ordered by `Lesson.Order` |
| GET | `/lessons/{id}` | — | `{id, slug, title, titleVi, descriptionVi, skillCode, cefr, contentVersion, source, license, reviewer, itemCount, progress}` / 404 | `progress` = `{completionCount, correctAnswers, totalAnswers, lastCompletedAt}` or `null` if the caller has never completed it; 404 if unpublished or missing |
| POST | `/lessons/{id}/attempts` | `{operationId}` | 201 `{id, lessonId, slug, title, titleVi, skillCode, status, startedAt, completedAt, exercises:[{id, sequence, type, stem, options, answered}]}` (fresh attempt) / 200 same shape (idempotent replay, or an already-`InProgress` attempt on this lesson) / 400 `operation_id_required` / 404 / 409 `lesson_has_no_items`\|`idempotency_conflict`\|`lesson_attempt_conflict` | idempotency-key pattern (`LessonAttempt.StartOperationId`); **`EnforceSingleActiveLessonAttempt`**: if the caller already has an `InProgress` attempt on this lesson, returns that attempt's snapshot (200) instead of creating a new one/new `Exercise` rows; snapshotted `exercises` never include `correctAnswer` |
| GET | `/lesson-attempts/{id}` | — | same snapshot shape as above / 404 | |
| POST | `/lesson-attempts/{id}/complete` | `{operationId}` | 200 `{attemptId, operationId, status:"completed", correctAnswers, totalAnswers, reviewCardsCreated, completedAt}` / 400 `operation_id_required` / 404 / 409 `lesson_incomplete`\|`lesson_already_completed`\|`idempotency_conflict` | idempotency-key pattern (`LessonCompletionOperation`); 409 `lesson_incomplete` if any exercise in the attempt is still unanswered; creates a `ReviewCard` (dedup'd on `SourceItemId`/`SourceExerciseId` so re-completing never double-adds) for every wrong answer — these feed `/reviews/mistakes`; writes a `LearningEvent` (`LessonCompleted`) and a `RewardLedgerEntry` (`20 + 5×correctAnswers` XP, 2 coins, quest `daily_lesson`) |

## Dashboard — `Endpoints/DashboardEndpoints.cs`, mapped on bare `app`, JWT per-route
| Verb | Route | Response | Notes |
|---|---|---|---|
| GET | `/gamification/me` | `{xp, coins, level, currentStreak, longestStreak, todayXp, activeDates:[DateOnly...]}` | `GamificationService.GetSummaryAsync`; `level = xp/100 + 1`; streaks computed from `RewardLedgerEntry.StreakQualified` rows bucketed into the user's local timezone (`user.TimeZone`, falls back to UTC-as-local on invalid/unknown tz id); `activeDates` capped to the trailing year |
| GET | `/quests` | `[{code, current, target, completed}]` — exactly 3 fixed daily quests | `GamificationService.GetQuestsAsync`: `daily_lesson` (target 1, counts `RewardLedgerEntry` rows with that `QuestCode` today), `daily_review` (target 5), `daily_xp` (target 50, counts today's XP sum) |
| GET | `/dashboard` | `{name, currentCefr, targetCefr, dailyGoalMinutes, mastery, weakSkills[3], strongSkills[3], dailyProgress, weeklyProgress, dueReviews, completedLessons, xp, coins, currentStreak, longestStreak, activeDates, todayLesson, recentActivity[5]}` / 404 | `currentCefr` from last completed placement session (default `"A1"`); `targetCefr` is `null` unless `TargetCefrConfirmed`; `mastery` = average `PCorrect` across all the caller's skills (0 if none); `weakSkills`/`strongSkills` = 3 lowest/highest mastery rows; `dailyProgress` is binary 1.0/0.0 (any lesson completed today), **not** a fraction; `weeklyProgress` = completions in the trailing 7 days ÷ 7, clamped to `[0,1]`; `todayLesson` uses the same eligibility rule as `/path/today` but is computed independently (not guaranteed identical); `recentActivity` = 5 most-recently-completed lesson attempts, each `{id, lessonId, title, titleVi, completedAt}` |

## Speaking — `Endpoints/SpeakingEndpoints.cs`, group `/speaking`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/speaking/attempts` | multipart: `audio` file + `promptText` form field | 200 `{attemptId, transcript, accuracy, completeness, fluency, total, durationSeconds, modelVersion, feedbackVi}` / 400 `invalid_prompt`\|`audio_empty`\|`audio_duration_invalid` / 413 `audio_too_large`\|`audio_too_long` / 415 `unsupported_audio_type`\|`audio_signature_mismatch` / 503 `ml_service_unavailable` or `feature_disabled` | `.DisableAntiforgery()` (multipart bypasses antiforgery pairing); hard size cap 10 MB (`MaxAudioBytes`, enforced via `RequestSizeLimitAttribute`/`RequestFormLimitsAttribute`), hard duration cap 120s (checked post-transcription from ML's reported `DurationSeconds`); gated by `MlFeatureRollout.IsEnabled(..., "Speaking", userId)` → `503 feature_disabled` outside rollout; **`HardenSpeakingAudioRetention`**: saves to a *non-web-served* temp directory (`Storage:TempPath` config, default `temp/speaking`; app throws at startup if this would resolve inside `wwwroot`) — **not** `wwwroot/uploads` as an earlier revision of this doc said; magic-byte sniff (`DetectMime`, checks RIFF/WEBM/OggS/ftyp/ID3/MP3-frame headers) must match the declared `Content-Type` or `415 audio_signature_mismatch`; the temp file is opened with `FileOptions.DeleteOnClose` and *also* explicitly deleted in a `finally` block — deleted in every outcome (success, ML rejection, ML unavailable, any exception), never left on disk past the request; streams to ML `/speech/score`; `MlInputRejectedException` → `ApiResults.MlRejected`; rate-limited `ml-upload` |
| GET | `/speaking/attempts` | — | `[{id, promptText, transcript, total, durationSeconds, modelVersion, feedbackVi, createdAt}]` | desc by `createdAt` |

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

## Privacy — `Endpoints/PrivacyEndpoints.cs`, group `/privacy` + one route mapped onto `/auth`, JWT on all
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| GET | `/privacy/consents` | — | `[{id, consentType, granted, policyVersion, source, recordedAt}]` | caller's own `ConsentRecord`s, desc by `recordedAt` |
| POST | `/privacy/consents` | `{consentType, granted, policyVersion}` | 201 `{id, consentType, granted, policyVersion, recordedAt}` | 400 `invalid_consent_type` (must be one of `privacy_policy`\|`analytics`\|`ai_processing`\|`speaking_processing`) or `invalid_policy_version` (1–100 chars); `source` is always recorded as `"authenticated_api"`; append-only ledger — no PATCH/DELETE, this is a consent *history*, not current-state |
| GET | `/privacy/export` | — | `application/zip` file download (`lingoroad-export-{yyyyMMdd}.zip`, single entry `lingoroad-data.json`) / 404 | full data export: profile, consents, placement sessions + answers, mastery, lesson progress, submitted exercises, review cards, speaking attempts, reward ledger, learning events; `schemaVersion: 1` |
| DELETE | `/auth/me` | — | 202 `{id, status, requestedAt, scheduledFor, completionDeadline}` / 404 / 409 `admin_deletion_requires_role_transfer` | route path is `/auth/me` (mapped via `app.MapDelete`, not the `/privacy` group) but the handler lives in this file; creates an `AccountDeletionRequest` with a configurable grace period (`Privacy:DeletionGraceDays`, default 7, clamped 0–30) before background purge; `completionDeadline` = `requestedAt + 30 days` (hard cap, independent of the grace period); immediately revokes all the caller's refresh sessions; re-requesting while a deletion is already pending just replays the same 202 snapshot; `Role=Admin` users must transfer their role first; **once pending, the JWT `OnTokenValidated` handler in `Program.cs` fails auth on every route except this same `DELETE /auth/me`** — a mid-deletion user can't call anything else until the request resolves |

Actual purge is carried out by `PrivacyDeletionService`/`DataRetentionService`,
invoked from the background `PrivacyMaintenanceWorker` hosted service
(registered in `Program.cs`, disabled under the `Testing` environment).

## Dictionary — `Endpoints/DictionaryEndpoints.cs`, group `/dictionary`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/dictionary/lookup` | `{word}` | 200 `{definition}` / 400 `invalid_word` / 503 `ml_service_unavailable`, or `ApiResults.MlRejected`'s dynamic status/code (400/413/415/422, ML-defined) | 400 if `word` blank or `>100` chars; **no `MlFeatureRollout` gate** (unlike Advisor/Writing/Speaking — always on); builds a fixed Vietnamese prompt (`"Định nghĩa ngắn gọn và 1 ví dụ của từ: {word}"`) and calls the same ML `POST /llm/advisor` endpoint `/path/advisor` uses, with an empty skill-context list; not persisted anywhere (no dictionary-history table); rate-limited `ml-upload` |

## Saved Words — `Endpoints/SavedWordEndpoints.cs`, group `/words`, JWT on group
| Verb | Route | Request | Response | Notes |
|---|---|---|---|---|
| POST | `/words` | `{skillCode, word, definition}` | 201 `{id, word, definition, note, createdAt, updatedAt, reviewStage, nextReviewAt}` | 400 `unknown_skill`; `reviewStage` starts at 1, `nextReviewAt` = createdAt + 1 day |
| GET | `/words` | query `?due=true` (optional) | `[{id, word, definition, note, createdAt, updatedAt, reviewStage, nextReviewAt, isDue}]` | caller's words, newest-first; `due=true` filters to `nextReviewAt <= now` server-side; `isDue` always present regardless of filter |
| PATCH | `/words/{id}` | `{note}` | 200 = same shape as POST response | sets `note` + `updatedAt`; 404 if not found/not owned; doesn't touch review-schedule fields |
| DELETE | `/words/{id}` | — | 204 / 404 | |
| POST | `/words/{id}/review` | — (no body) | 200 = same shape as POST response (stage advanced) / 204 (final stage reviewed, row deleted) | 404 if not found/not owned; fixed-interval schedule (day 1/3/7/14 since creation, gaps `[1,2,4,7]` days from the actual review time, not FSRS — no grading input); see `SavedWordSchedule.cs` in `domain-model.md` |

## Shared error shape
Every route that calls `IMlClient` returns `503
{"error":"ml_service_unavailable"}` via `ApiResults.MlUnavailable()` when
the ML service is unreachable or times out — see
`auth-and-integrations.md` for the exact mechanism.

Two related shared shapes, both in `Endpoints/ApiResults.cs` and used across
Path/Exercises/Speaking/Dictionary/Admin item-generation (anywhere that
calls `IMlClient` with user-supplied content):
- `ApiResults.MlRejected(MlInputRejectedException)` → `{"error": <ml's own
  error code>}` at whatever status ML responded with (400/413/415/422) —
  distinct from the 503 case above; means ML validated the request and
  rejected the *content* (e.g. unsafe input), not a connectivity failure.
- `ApiResults.FeatureDisabled()` → `503 {"error":"feature_disabled"}` when
  `MlFeatureRollout.IsEnabled(...)` excludes the caller from a
  percentage-based rollout (`MlFeatures:{Feature}RolloutPercent` config,
  currently gates `Advisor`/`Writing`/`Speaking`) — same status code as
  `ml_service_unavailable` but a different error string, so clients must
  check the `error` field, not just the status code, to tell them apart.
