import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/login_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/register_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/splash_screen.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_intro_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_question_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_result_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';

GoRouter createAppRouter({
  required SessionController session,
  required AuthRepository authRepository,
  required PlacementRepository placementRepository,
  String initialLocation = '/splash',
}) {
  final placement = PlacementViewModel(placementRepository);
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
          if (location == '/splash' || isAuthRoute) {
            return '/placement';
          }
          if (location == '/placement/question' &&
              placement.currentItem == null) {
            return '/placement';
          }
          if (location == '/placement/result' && placement.result == null) {
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
        builder: (context, state) => LoginScreen(
          authRepository: authRepository,
          sessionController: session,
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          authRepository: authRepository,
          sessionController: session,
        ),
      ),
      GoRoute(
        path: '/placement',
        builder: (context, state) => PlacementIntroScreen(viewModel: placement),
      ),
      GoRoute(
        path: '/placement/question',
        builder: (context, state) =>
            PlacementQuestionScreen(viewModel: placement),
      ),
      GoRoute(
        path: '/placement/result',
        builder: (context, state) =>
            PlacementResultScreen(viewModel: placement),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => MainShell(sessionController: session),
      ),
    ],
  );
}
