import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';

const _protectedDeepLinks = [
  '/home',
  '/review',
  '/lesson/lesson-1',
  '/question-review',
  '/practice',
  '/notification-settings',
  '/streak-details',
  '/vocabulary-review',
  '/learning-goals-schedule',
];

String? _redirect({
  required String location,
  SessionStatus session = SessionStatus.authenticated,
  PlacementOnboardingStatus placement = PlacementOnboardingStatus.completed,
  ProfileSetupStatus profile = ProfileSetupStatus.completed,
  bool hasQuestion = false,
  bool hasResult = false,
}) => onboardingRedirect(
  location: location,
  sessionStatus: session,
  placementStatus: placement,
  profileSetupStatus: profile,
  hasPlacementQuestion: hasQuestion,
  hasPlacementResult: hasResult,
);

void main() {
  test(
    'unauthenticated and checking sessions gate every protected deep link',
    () {
      for (final location in _protectedDeepLinks) {
        expect(
          _redirect(location: location, session: SessionStatus.checking),
          '/splash',
          reason: 'checking $location',
        );
        expect(
          _redirect(location: location, session: SessionStatus.unauthenticated),
          '/login',
          reason: 'unauthenticated $location',
        );
      }

      expect(
        _redirect(location: '/splash', session: SessionStatus.checking),
        isNull,
      );
      expect(
        _redirect(location: '/login', session: SessionStatus.unauthenticated),
        isNull,
      );
      expect(
        _redirect(
          location: '/register',
          session: SessionStatus.unauthenticated,
        ),
        isNull,
      );
    },
  );

  test('placement status matrix gates every protected deep link', () {
    const cases = {
      PlacementOnboardingStatus.unknown: '/splash',
      PlacementOnboardingStatus.checking: '/splash',
      PlacementOnboardingStatus.error: '/placement/status-error',
      PlacementOnboardingStatus.required: '/placement',
    };

    for (final entry in cases.entries) {
      for (final location in _protectedDeepLinks) {
        expect(
          _redirect(location: location, placement: entry.key),
          entry.value,
          reason: '${entry.key.name} $location',
        );
      }
    }

    expect(
      _redirect(
        location: '/placement/status-error',
        placement: PlacementOnboardingStatus.error,
      ),
      isNull,
    );
  });

  test('placement required admits only valid onboarding state', () {
    expect(
      _redirect(
        location: '/placement',
        placement: PlacementOnboardingStatus.required,
      ),
      isNull,
    );
    expect(
      _redirect(
        location: '/placement/question',
        placement: PlacementOnboardingStatus.required,
        hasQuestion: false,
      ),
      '/placement',
    );
    expect(
      _redirect(
        location: '/placement/question',
        placement: PlacementOnboardingStatus.required,
        hasQuestion: true,
      ),
      isNull,
    );
    expect(
      _redirect(
        location: '/placement/result',
        placement: PlacementOnboardingStatus.required,
        hasResult: false,
      ),
      '/placement',
    );
    expect(
      _redirect(
        location: '/placement/result',
        placement: PlacementOnboardingStatus.required,
        hasResult: true,
      ),
      isNull,
    );
  });

  test('profile setup status matrix gates every protected deep link', () {
    const cases = {
      ProfileSetupStatus.unknown: '/splash',
      ProfileSetupStatus.checking: '/splash',
      ProfileSetupStatus.error: '/profile-setup/status-error',
      ProfileSetupStatus.required: '/profile-setup',
    };

    for (final entry in cases.entries) {
      for (final location in _protectedDeepLinks) {
        expect(
          _redirect(location: location, profile: entry.key),
          entry.value,
          reason: '${entry.key.name} $location',
        );
      }
    }

    expect(
      _redirect(
        location: '/profile-setup/status-error',
        profile: ProfileSetupStatus.error,
      ),
      isNull,
    );
    expect(
      _redirect(
        location: '/profile-setup',
        profile: ProfileSetupStatus.required,
      ),
      isNull,
    );
  });

  test('completed onboarding protects no application deep link', () {
    for (final location in _protectedDeepLinks) {
      expect(_redirect(location: location), isNull, reason: location);
    }
  });

  test('completed onboarding redirects every onboarding route home', () {
    const onboardingRoutes = [
      '/splash',
      '/login',
      '/register',
      '/placement',
      '/placement/question',
      '/placement/result',
      '/placement/status-error',
      '/profile-setup',
      '/profile-setup/status-error',
    ];

    for (final location in onboardingRoutes) {
      expect(
        _redirect(location: location, hasQuestion: true, hasResult: true),
        '/home',
        reason: location,
      );
    }
  });
}
