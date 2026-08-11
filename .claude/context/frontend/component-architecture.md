# Component Architecture — lingoRoad Mobile

## Route tree (`app_router.dart`)
Single `GoRouter`, `refreshListenable: session` (a `SessionController`,
`ChangeNotifier`). All navigation gating happens in one `redirect` callback
keyed on `session.status` (`checking` / `unauthenticated` / `authenticated`)
crossed with `session.placementStatus` (`unknown` / `checking` / `required` /
`completed` / `error`).

| Path | Screen | Guard |
|---|---|---|
| `/splash` | `SplashScreen` | shown while `status == checking` or placement status is `unknown`/`checking` |
| `/login`, `/register` | `LoginScreen`, `RegisterScreen` | only reachable when `unauthenticated` |
| `/placement` | `PlacementIntroScreen` | `authenticated` + placement `required`/recovered-from-`error` |
| `/placement/status-error` | `PlacementStatusErrorScreen` | `authenticated` + placement `error` (status lookup failed) |
| `/placement/question` | `PlacementQuestionScreen` | redirects back to `/placement` if `placement.currentItem == null` |
| `/placement/result` | `PlacementResultScreen` | redirects back to `/placement` if `placement.result == null` |
| `/home` | `MainShell` | `authenticated` + placement `completed` |
| `/review` | `MainShell(initialIndex: 2)` | authenticated + placement completed; deep-links to the Review tab |
| `/question-review` | `QuestionReviewScreen` | authenticated + placement completed |

`PlacementViewModel` is constructed once in `createAppRouter` (not per-route),
so placement progress survives navigation within the flow.
`session.configurePlacementStatusLoader(placementRepository.isCompleted)`
wires the status check used by the redirect.

## `MainShell` (the 5 tabs)
`lib/screens/main_shell.dart` is a `StatefulWidget` holding an `IndexedStack`
of 5 screens, switched by a Material 3 `NavigationBar`. Tab order/labels: Học
(`HomeScreen`), Lộ trình (`LearningPathScreen`), Ôn tập (`ReviewScreen`),
Tiến độ (`ProgressScreen`), Hồ sơ (`ProfileScreen`). Screens are built once in
`initState`, not rebuilt on tab switch.

## State management pattern
Repositories and `ChangeNotifier` view models are wired with Provider at the
composition root. Session-bound models use `ChangeNotifierProxyProvider` and
`SessionController.sessionGeneration` so an old account response cannot update
the new account state. Core concerns include:
- `SessionController` — auth + placement-onboarding status, token, drives router redirects.
- `AuthViewModel` — login/register submission state (`isSubmitting`, `errorMessage`) + static validators.
- `PlacementViewModel` — CAT test progression (`sessionId`, `currentItem`, `selectedAnswer`, `result`, `questionNumber`).
- `ReviewViewModel` — saved-word FSRS cards from `/words/*`.
- `QuestionReviewViewModel` — wrong-question queue from `/reviews/questions/*`, answer feedback, rating and session rewards; independent from saved-word state.

Screens consume the supplied dependencies through `context.watch`,
`context.read` or `Consumer`. Repositories use the authenticated `ApiClient`;
feature state is not shared through a mock repository.

## Live learner data
The learner shell uses real authenticated repositories:

| Screen | Data source | Notes |
|---|---|---|
| `LoginScreen`, `RegisterScreen`, `SplashScreen` | `ApiAuthRepository` → `POST /auth/login`, `POST /auth/register` | Real |
| `PlacementIntroScreen`/`Question`/`Result`/`StatusError` | `ApiPlacementRepository` → `/placement/*` | Real |
| `HomeScreen` | `ApiDashboardRepository` + quests | Real dashboard, rewards and activity |
| `LearningPathScreen` | `ApiLearningPathRepository` | Real personalized path and lesson status |
| `ReviewScreen` | `ReviewViewModel` + `QuestionReviewViewModel` | Real, separate saved-word and wrong-question queues; `/question-review` supports MCQ/cloze/reorder, feedback, grade retry and a 10-question session |
| `ProgressScreen` | `ApiProgressRepository` + dashboard | Real mastery, review and lesson progress |
| `ProfileScreen` | Authenticated profile/preferences APIs | Real profile, onboarding preferences, password/logout and reminder settings |

## Shared UI primitives (`widgets/common.dart`)
- `AppPage` — the standard scaffold body: `SafeArea` + `ListView` with fixed
  spacing between children and 112px bottom padding (clears the
  `NavigationBar`).
- `AppCard` — rounded, bordered, shadowed container used for every card-like block.
- `AppProgress` — `LinearProgressIndicator` wrapper with a `Semantics` label
  (always use this instead of a bare `LinearProgressIndicator` for a11y).
- `LingoHeader`, `SectionTitle`, `MetricRow`, `loadingView()` — smaller reusable pieces.

Use these instead of ad hoc `Container`/`Padding` scaffolding when building
new screen content — every existing screen composes from them.
