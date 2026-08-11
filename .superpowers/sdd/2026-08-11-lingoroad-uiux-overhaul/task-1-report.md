# Task 1 report — foundation and mandatory profile setup

## Delivered files and behavior

- Backend: `Domain/User.cs`, `Endpoints/AuthEndpoints.cs`, and EF migration `20260811103214_AddProfileSetupCompletion` add `ProfileSetupCompletedAt`, expose `profileSetupCompleted`, and provide authenticated `POST /auth/me/complete-profile-setup`.
- Endpoint trims and validates name (1–100), accepts only canonical `A1/A2/B1/B2`, validates a 10–120 minute goal, updates the submitted fields on repeat calls, and preserves the first completion timestamp.
- Mobile: `UserProfile` treats a missing `profileSetupCompleted` as `true`; `AuthRepository` supports completion; `SessionController` now manages profile setup loading/required/error/completed states after placement; router protects deep links and sends status failures to retry/logout views.
- New `ProfileSetupScreen` has no skip/back action, preserves input on submit error, is restart-resumable via server completion state, and uses Provider/ChangeNotifier, GoRouter, ScreenUtil, Hanken Grotesk theme, vi/en copy, semantic colors, 48px FilledButton minimum, responsive max width, and `AppCardVariant`.

## Migrations and API

- Migration is nullable and runs `UPDATE "Users" SET "ProfileSetupCompletedAt" = "CreatedAt"` for pre-existing users. New registrations retain `null` and are required to finish setup.
- `GET /auth/me` now includes `profileSetupCompleted`.
- `POST /auth/me/complete-profile-setup` returns the normal profile DTO and is idempotent for completion time.

## Figma evidence

- Loaded `figma-design-to-code` before invoking `get_design_context` for colors `2030:392`, typography `2030:473`, and components `2030:592`.
- Exported Figma-owned PNG references to `docs/design/figma-reference/mobile/`: `system-color-palette-2030-392.png`, `system-typography-2030-473.png`, and `system-components-2030-592.png`; `manifest.json` maps nodes to foundation routes/golden identifiers.
- Tokens used: primary `#B22300`, background `#FBF9F9`, on-surface `#1B1C1C`, on-surface-variant `#5C403A`, outline `#907068`, outline-variant `#E5BEB5`, Hanken Grotesk.

## Tests

- `dotnet restore .\\LingoRoad.sln` — passed.
- `dotnet build .\\LingoRoad.sln --no-restore` — passed, 0 warnings/errors.
- `dotnet test .\\LingoRoad.Tests\\LingoRoad.Tests.csproj --no-restore --filter "FullyQualifiedName~AuthTests"` — passed, 13/13.
- `flutter test test/core/session/session_controller_test.dart test/features/auth/auth_repository_test.dart test/features/auth/auth_flow_test.dart test/features/placement/placement_flow_test.dart` — passed, 27/27.
- `flutter analyze` — passed, no issues.
- `git diff --check` — passed.

## Commit

- `a4f1dc3 feat(onboarding): require learner profile setup`.

## Concerns

- Figma MCP page discovery in this session initially exposed only the System Desgin page. Direct page-frame downloads were begun but not completed before handoff; therefore the 35-frame reference set and corresponding goldens remain incomplete. The manifest accurately records only exported foundation nodes.
- Golden-test infrastructure and 35-screen assets need completion in the visual-regression follow-up; core API/session/profile setup is independently verified.
