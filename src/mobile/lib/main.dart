import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/session/secure_session_store.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController(const SecureSessionStore());
  final apiClient = ApiClient(
    config: AppConfig(),
    session: session,
  );
  final authRepository = ApiAuthRepository(apiClient);
  final placementRepository = ApiPlacementRepository(apiClient);
  final placementViewModel = PlacementViewModel(placementRepository);
  
  session.configurePlacementStatusLoader(placementRepository.isCompleted);
  
  final router = createAppRouter(
    session: session,
    placementViewModel: placementViewModel,
  );

  runApp(
    LingoRoadApp(
      routerConfig: router,
      sessionController: session,
      authRepository: authRepository,
      placementRepository: placementRepository,
      placementViewModel: placementViewModel,
    ),
  );
  unawaited(session.restore());
}

class LingoRoadApp extends StatelessWidget {
  const LingoRoadApp({
    required this.routerConfig,
    this.sessionController,
    this.authRepository,
    this.placementRepository,
    this.placementViewModel,
    super.key,
  });

  final GoRouter routerConfig;
  final SessionController? sessionController;
  final AuthRepository? authRepository;
  final PlacementRepository? placementRepository;
  final PlacementViewModel? placementViewModel;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (sessionController != null)
          ChangeNotifierProvider<SessionController>.value(value: sessionController!)
        else
          ChangeNotifierProvider<SessionController>(
            create: (_) => SessionController(const SecureSessionStore()),
          ),
        if (authRepository != null)
          Provider<AuthRepository>.value(value: authRepository!)
        else
          Provider<AuthRepository>(
            create: (context) => ApiAuthRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        if (placementRepository != null)
          Provider<PlacementRepository>.value(value: placementRepository!)
        else
          Provider<PlacementRepository>(
            create: (context) => ApiPlacementRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        if (placementViewModel != null)
          ChangeNotifierProvider<PlacementViewModel>.value(value: placementViewModel!)
        else
          ChangeNotifierProvider<PlacementViewModel>(
            create: (context) => PlacementViewModel(
              context.read<PlacementRepository>(),
            ),
          ),
      ],
      child: Builder(
        builder: (context) {
          // Ensure placement status loader is configured using the provided dependencies
          context.read<SessionController>().configurePlacementStatusLoader(
            context.read<PlacementRepository>().isCompleted,
          );
          return MaterialApp.router(
            title: 'lingoRoad',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: routerConfig,
          );
        },
      ),
    );
  }
}

