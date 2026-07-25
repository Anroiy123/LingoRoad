import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/login_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/register_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/splash_screen.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';

GoRouter createAppRouter({
  required SessionController session,
  required AuthRepository authRepository,
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
          return location == '/splash' || isAuthRoute ? '/home' : null;
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
        path: '/home',
        builder: (context, state) =>
            MainShell(sessionController: session),
      ),
    ],
  );
}
