import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/presentation/login_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/register_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/splash_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/profile_setup_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_intro_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_question_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_result_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_status_error_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/features/practice/data/practice_repository.dart';
import 'package:lingoroad_mobile/features/practice/data/speaking_recorder.dart';
import 'package:lingoroad_mobile/features/practice/presentation/practice_screen.dart';
import 'package:lingoroad_mobile/features/practice/presentation/practice_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_screen.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_screen.dart';
import 'package:lingoroad_mobile/screens/learning_goals_schedule_screen.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/screens/notification_settings_screen.dart';
import 'package:lingoroad_mobile/screens/streak_details_screen.dart';
import 'package:lingoroad_mobile/screens/vocabulary_review_screen.dart';
import 'package:provider/provider.dart';

GoRouter createAppRouter({
  required SessionController session,
  required PlacementViewModel placementViewModel,
  String initialLocation = '/splash',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      return onboardingRedirect(
        location: location,
        sessionStatus: session.status,
        placementStatus: session.placementStatus,
        profileSetupStatus: session.profileSetupStatus,
        hasPlacementQuestion: placementViewModel.currentItem != null,
        hasPlacementResult: placementViewModel.result != null,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/placement',
        builder: (context, state) => const PlacementIntroScreen(),
      ),
      GoRoute(
        path: '/placement/status-error',
        builder: (context, state) => const PlacementStatusErrorScreen(),
      ),
      GoRoute(
        path: '/placement/question',
        builder: (context, state) => const PlacementQuestionScreen(),
      ),
      GoRoute(
        path: '/placement/result',
        builder: (context, state) => const PlacementResultScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/review',
        builder: (context, state) => const MainShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/profile-setup/status-error',
        builder: (context, state) => const ProfileSetupStatusErrorScreen(),
      ),
      GoRoute(
        path: '/learning-goals-schedule',
        builder: (context, state) => const LearningGoalsScheduleScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/streak-details',
        builder: (context, state) => const StreakDetailsScreen(),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => LessonViewModel(context.read<LessonRepository>()),
          child: LessonScreen(lessonId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/practice',
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => AiPracticeViewModel(
            context.read<AiPracticeRepository>(),
            DeviceSpeakingRecorder(),
          ),
          child: const AiPracticeScreen(),
        ),
      ),
      GoRoute(
        path: '/vocabulary-review',
        builder: (context, state) => const VocabularyReviewScreen(),
      ),
      GoRoute(
        path: '/question-review',
        builder: (context, state) => const QuestionReviewScreen(),
      ),
    ],
  );
}

/// The only locations an authenticated learner may enter before placement.
///
/// Keeping this allowlist explicit prevents protected deep links from becoming
/// reachable when new routes are added.
bool isPlacementFlowRoute(String location) =>
    location == '/placement' ||
    location == '/placement/question' ||
    location == '/placement/result';

/// Pure redirect policy so all deep-link gates are table-testable.
String? onboardingRedirect({
  required String location,
  required SessionStatus sessionStatus,
  required PlacementOnboardingStatus placementStatus,
  required ProfileSetupStatus profileSetupStatus,
  required bool hasPlacementQuestion,
  required bool hasPlacementResult,
}) {
  final isAuthRoute = location == '/login' || location == '/register';
  switch (sessionStatus) {
    case SessionStatus.checking:
      return location == '/splash' ? null : '/splash';
    case SessionStatus.unauthenticated:
      return isAuthRoute ? null : '/login';
    case SessionStatus.authenticated:
      if (placementStatus == PlacementOnboardingStatus.unknown ||
          placementStatus == PlacementOnboardingStatus.checking) {
        return location == '/splash' ? null : '/splash';
      }
      if (placementStatus == PlacementOnboardingStatus.error) {
        return location == '/placement/status-error'
            ? null
            : '/placement/status-error';
      }
      if (placementStatus == PlacementOnboardingStatus.completed) {
        if (profileSetupStatus == ProfileSetupStatus.unknown ||
            profileSetupStatus == ProfileSetupStatus.checking) {
          return location == '/splash' ? null : '/splash';
        }
        if (profileSetupStatus == ProfileSetupStatus.error) {
          return location == '/profile-setup/status-error'
              ? null
              : '/profile-setup/status-error';
        }
        if (profileSetupStatus == ProfileSetupStatus.required) {
          return location == '/profile-setup' ? null : '/profile-setup';
        }
        if (location == '/splash' ||
            isAuthRoute ||
            isPlacementFlowRoute(location) ||
            location == '/placement/status-error' ||
            location == '/profile-setup' ||
            location == '/profile-setup/status-error') {
          return '/home';
        }
      } else if (location == '/splash' ||
          isAuthRoute ||
          !isPlacementFlowRoute(location)) {
        return '/placement';
      }
      if (location == '/placement/question' && !hasPlacementQuestion) {
        return '/placement';
      }
      if (location == '/placement/result' && !hasPlacementResult) {
        return '/placement';
      }
      return null;
  }
}
