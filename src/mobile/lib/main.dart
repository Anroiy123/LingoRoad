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
import 'package:lingoroad_mobile/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController(const SecureSessionStore());
  final apiClient = ApiClient(
    config: AppConfig(),
    session: session,
  );
  final authRepository = ApiAuthRepository(apiClient);
  final placementRepository = ApiPlacementRepository(apiClient);
  final router = createAppRouter(
    session: session,
    authRepository: authRepository,
    placementRepository: placementRepository,
  );

  runApp(LingoRoadApp(routerConfig: router));
  unawaited(session.restore());
}

class LingoRoadApp extends StatelessWidget {
  const LingoRoadApp({required this.routerConfig, super.key});

  final GoRouter routerConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'lingoRoad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: routerConfig,
    );
  }
}
