# Testing — lingoRoad Mobile

## Layout
`test/` mirrors `lib/`:
```
test/
├── core/config/app_config_test.dart
├── core/network/api_client_test.dart
├── core/session/session_controller_test.dart
├── features/auth/{auth_flow_test.dart, auth_repository_test.dart, auth_view_model_test.dart}
├── features/placement/{placement_flow_test.dart, placement_repository_test.dart, placement_view_model_test.dart}
└── widget_test.dart
```

## Run
```powershell
flutter analyze   # lint failures are a separate signal — run first
flutter test
```

## Conventions
- **Unit tests** (`*_repository_test.dart`, `*_view_model_test.dart`,
  `core/`) test one class against fakes — no widget pumping.
- **Flow tests** (`*_flow_test.dart`) pump the *real* `LingoRoadApp`/
  `createAppRouter` with **fake repository implementations** written inline
  in the test file (`FlowAuthRepository`, `AuthFlowPlacementRepository`,
  `FakePlacementRepository`) — these drive full navigation + redirect logic
  end-to-end, not just a single widget. When adding a new gated route,
  add/extend a flow test here rather than only unit-testing the view model.
- **HTTP layer** is tested via `package:http/testing.dart`'s `MockClient`
  against the real `ApiClient` (see `api_client_test.dart`) — assert on
  request shape (headers, body) and on `ApiException.code`/`statusCode`, not
  on internals.
- **Widget keys drive test lookups**: `find.byKey(const Key('login_submit'))`
  etc. When adding an interactive widget a test will need, give it a
  `Key('<feature>_<action>')` — see the convention list in
  `folder-structure.md`.
- Tests are in Vietnamese where they assert on UI text
  (`expect(find.text('Chào mừng trở lại'), findsOneWidget)`), matching the
  app's UI language — don't switch test strings to English.
- No golden-image tests, no coverage threshold enforced (`flutter test
  --coverage` is not wired into any script in this repo).

> ⚠️ Undocumented — no CI workflow runs any of this today (no
> `.github/workflows/` in the repo); these commands are currently
> developer-run only. Verify before assuming a merge gate exists.
