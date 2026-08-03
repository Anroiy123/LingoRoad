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
No Provider/Riverpod/Bloc/GetX. Every stateful concern is a plain
`ChangeNotifier`:
- `SessionController` — auth + placement-onboarding status, token, drives router redirects.
- `AuthViewModel` — login/register submission state (`isSubmitting`, `errorMessage`) + static validators.
- `PlacementViewModel` — CAT test progression (`sessionId`, `currentItem`, `selectedAnswer`, `result`, `questionNumber`).

Screens consume these via `AnimatedBuilder(animation: viewModel, builder:
...)`, not `context.watch`/`Consumer`. Dependencies are passed in via
constructor from `main.dart` → `app_router.dart` → screen — there is no
service locator, no `InheritedWidget`-based DI, no global singletons besides
what `main.dart` constructs once.

`screens/*.dart` (the 5 tabs, except `ProfileScreen`'s session/logout wiring)
are plain `StatefulWidget`s with **local `setState`** only — they don't use
the `ChangeNotifier` pattern because they don't talk to the backend yet (see
below).

## Mock vs. live data — read this before changing a screen
Only `auth` and `placement` are wired to the real backend. Everything
reachable from `MainShell` after placement completes is currently
**mock/demo data**:

| Screen | Data source | Notes |
|---|---|---|
| `LoginScreen`, `RegisterScreen`, `SplashScreen` | `ApiAuthRepository` → `POST /auth/login`, `POST /auth/register` | Real |
| `PlacementIntroScreen`/`Question`/`Result`/`StatusError` | `ApiPlacementRepository` → `/placement/*` | Real |
| `HomeScreen` | `MockRepository.quests()` | ⚠️ Greeting text `'Chào Hùng!'` is hardcoded, not the logged-in user's name |
| `LearningPathScreen` | `MockRepository.path()` | Hardcoded lesson list |
| `ReviewScreen` | `MockRepository.reviews()` | Hardcoded vocab cards |
| `ProgressScreen` | `MockRepository.skills` | Hardcoded skill percentages |
| `ProfileScreen` | Local `setState` only (notification/reminder toggles) | Only the **logout** button is real — it calls `sessionController.logout()`. The rest (name, level, badges, settings) is static UI; the logout confirmation dialog itself says the action is "simulated" |

When asked to make one of the mock tabs "work", the backend already has real
endpoints for the underlying domain (learning path, mastery, review queue —
see repo-root `docs/system-architecture.md`); this is a wiring gap in the
mobile app, not a missing backend feature.

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
