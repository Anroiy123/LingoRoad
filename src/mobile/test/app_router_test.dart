import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';

void main() {
  test('placement allowlist admits only the onboarding flow', () {
    const allowed = ['/placement', '/placement/question', '/placement/result'];
    const protectedDeepLinks = [
      '/home',
      '/review',
      '/lesson/lesson-1',
      '/vocabulary-review',
      '/question-review',
      '/practice',
      '/learning-goals-schedule',
      '/notification-settings',
      '/streak-details',
      '/profile-setup',
      '/profile-setup/status-error',
      '/login',
      '/register',
    ];

    for (final location in allowed) {
      expect(isPlacementFlowRoute(location), isTrue, reason: location);
    }
    for (final location in protectedDeepLinks) {
      expect(isPlacementFlowRoute(location), isFalse, reason: location);
    }
  });

  test(
    'deep-link redirect matrix covers auth, placement, profile and complete states',
    () {
      const protected = [
        '/home',
        '/lesson/lesson-1',
        '/review',
        '/vocabulary-review',
      ];
      for (final location in protected) {
        expect(
          onboardingRedirect(
            location: location,
            sessionStatus: SessionStatus.unauthenticated,
            placementStatus: PlacementOnboardingStatus.unknown,
            profileSetupStatus: ProfileSetupStatus.unknown,
            hasPlacementQuestion: false,
            hasPlacementResult: false,
          ),
          '/login',
          reason: 'unauthenticated $location',
        );
        expect(
          onboardingRedirect(
            location: location,
            sessionStatus: SessionStatus.authenticated,
            placementStatus: PlacementOnboardingStatus.required,
            profileSetupStatus: ProfileSetupStatus.unknown,
            hasPlacementQuestion: false,
            hasPlacementResult: false,
          ),
          '/placement',
          reason: 'placement required $location',
        );
        expect(
          onboardingRedirect(
            location: location,
            sessionStatus: SessionStatus.authenticated,
            placementStatus: PlacementOnboardingStatus.completed,
            profileSetupStatus: ProfileSetupStatus.required,
            hasPlacementQuestion: false,
            hasPlacementResult: false,
          ),
          '/profile-setup',
          reason: 'profile setup required $location',
        );
        expect(
          onboardingRedirect(
            location: location,
            sessionStatus: SessionStatus.authenticated,
            placementStatus: PlacementOnboardingStatus.completed,
            profileSetupStatus: ProfileSetupStatus.completed,
            hasPlacementQuestion: false,
            hasPlacementResult: false,
          ),
          isNull,
          reason: 'completed $location',
        );
      }
    },
  );
}
