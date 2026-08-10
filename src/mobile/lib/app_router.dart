import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/presentation/login_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/register_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/splash_screen.dart';
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
import 'package:lingoroad_mobile/screens/learning_goals_schedule_screen.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/screens/notification_settings_screen.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
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
      final isAuthRoute = location == '/login' || location == '/register';

      switch (session.status) {
        case SessionStatus.checking:
          return location == '/splash' ? null : '/splash';
        case SessionStatus.unauthenticated:
          return isAuthRoute ? null : '/login';
        case SessionStatus.authenticated:
          if (session.placementStatus == PlacementOnboardingStatus.unknown ||
              session.placementStatus == PlacementOnboardingStatus.checking) {
            return location == '/splash' ? null : '/splash';
          }
          if (session.placementStatus == PlacementOnboardingStatus.error) {
            return location == '/placement/status-error'
                ? null
                : '/placement/status-error';
          }
          if (session.placementStatus == PlacementOnboardingStatus.completed) {
            if (location == '/splash' ||
                isAuthRoute ||
                location == '/placement' ||
                location == '/placement/status-error') {
              return '/home';
            }
          } else if (location == '/splash' ||
              isAuthRoute ||
              location == '/home' ||
              location.startsWith('/lesson/') ||
              location == '/placement/status-error') {
            return '/placement';
          }
          if (location == '/placement/question' &&
              placementViewModel.currentItem == null) {
            return '/placement';
          }
          if (location == '/placement/result' &&
              placementViewModel.result == null) {
            return '/placement';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const Scaffold(
          body: ProfileScreen(onboarding: true),
        ),
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
    ],
  );
}
