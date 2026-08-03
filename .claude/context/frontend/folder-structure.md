# Folder Structure — lingoRoad Mobile

## Top level (`src/mobile/`)
| Path | Purpose |
|---|---|
| `lib/` | App source |
| `test/` | Unit + widget tests, mirrors `lib/` |
| `assets/images/`, `assets/fonts/` | `logo.png`, `logo_black.png`, HankenGrotesk variable font |
| `android/`, `web/` | Platform shells (no `ios/` checked in yet) |
| `pubspec.yaml` | Dependencies, asset/font declarations, `flutter_launcher_icons` config |
| `analysis_options.yaml` | Lint rules |
| `README.md` | Setup + run commands (Vietnamese) |

## `lib/` layout
| Path | Contents | When to add here |
|---|---|---|
| `main.dart` | Composition root | Only when wiring a new top-level dependency (new repository, new controller) |
| `app_router.dart` | The one `GoRouter`, all `GoRoute`s + `redirect` | New top-level route/screen |
| `core/config/` | `AppConfig` (`API_BASE_URL` handling) | Rarely — one file |
| `core/network/` | `ApiClient`, `ApiException` | New cross-cutting HTTP concern (new header, new error mapping) |
| `core/session/` | `SessionController`, `SessionStore` (interface), `SecureSessionStore`, `MemorySessionStore` | Session/auth state changes |
| `data/mock_repository.dart` | Hardcoded demo data for non-wired tabs | New mock content for `screens/` |
| `models/models.dart` | Plain classes for mock data (`DailyQuest`, `PathNode`, `ReviewCardData`, `SkillProgress`) | New mock-data shape |
| `features/<name>/data/` | Repository interface + `Api<Name>Repository` implementation | New feature that talks to the backend |
| `features/<name>/domain/` | Hand-written JSON (de)serialization models with manual validation (`fromJson` throwing `ApiException(code: 'malformed_response')`) | New feature with a non-trivial API payload |
| `features/<name>/presentation/` | `ChangeNotifier` view model + `StatelessWidget`/`StatefulWidget` screens | New feature UI |
| `screens/` | Flat: the 5 bottom-nav tabs (`home_screen.dart`, `learning_path_screen.dart`, `review_screen.dart`, `progress_screen.dart`, `profile_screen.dart`) + `main_shell.dart` (the `NavigationBar` shell) | New tab or shell change only |
| `theme/app_theme.dart` | `AppColors`, `AppSpacing`, `AppRadius`, `AppTheme.light` | Token changes — keep in sync with repo-root `DESIGN.md` |
| `widgets/` | Shared cross-feature widgets: `brand_logo.dart`, `common.dart` (`AppPage`, `AppCard`, `AppProgress`, `LingoHeader`, `SectionTitle`, `MetricRow`, `loadingView()`) | New widget used by 2+ screens |

## Naming conventions
- Files: `snake_case.dart`. Classes: `PascalCase`. Private widgets/classes: leading underscore (`_QuestTile`, `_AnswerOption`).
- One file per public widget/class in `features/`; `screens/` files may hold several private helper widgets alongside the public screen.
- Testable widgets get an explicit `Key('feature_action')`, e.g. `login_email`, `login_submit`, `placement_answer_submit`, `placement_option_$index`, `placement_status_retry`. Follow this pattern — `snake_case` key strings, feature-prefixed — for anything a flow test will target.

## Adding a new API-backed feature
Follow the `auth`/`placement` shape:
1. `features/<name>/domain/` — request/response model(s) with a `fromJson` factory that throws `ApiException(code: 'malformed_response', ...)` on bad shape (see `placement_models.dart`).
2. `features/<name>/data/` — an `abstract interface class <Name>Repository` + `Api<Name>Repository` implementing it via `ApiClient`.
3. `features/<name>/presentation/` — a `ChangeNotifier` view model taking the repository via constructor, plus screen(s) built with `AnimatedBuilder(animation: viewModel, ...)`.
4. Wire the repository in `main.dart` and add route(s) in `app_router.dart`.
5. Add a fake repository implementation in `test/features/<name>/` for widget/flow tests (see `FakePlacementRepository`, `FlowAuthRepository`).

## Adding a new mock-data tab
Add the data shape to `models/models.dart`, a fetch method to
`MockRepository`, and consume it from the relevant `screens/*.dart` file with
`FutureBuilder` (see `home_screen.dart`'s `_quests` pattern).

> ⚠️ Undocumented — there is no ticket/plan in this codebase for wiring these
> screens to the real backend; treat the mock/live split (see
> `component-architecture.md`) as the current state, not a TODO to silently
> "fix" as a side effect of an unrelated change.
