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

  runApp(
    LingoRoadApp(
      sessionController: session,
      authRepository: authRepository,
      placementRepository: placementRepository,
      placementViewModel: placementViewModel,
    ),
  );
  unawaited(session.restore());
}

class LingoRoadApp extends StatefulWidget {
  LingoRoadApp({
    required this.sessionController,
    required this.authRepository,
    required this.placementRepository,
    required this.placementViewModel,
    this.initialLocation = '/splash',
    super.key,
  }) {
    sessionController.configurePlacementStatusLoader(
      placementRepository.isCompleted,
    );
  }

  final SessionController sessionController;
  final AuthRepository authRepository;
  final PlacementRepository placementRepository;
  final PlacementViewModel placementViewModel;
  final String initialLocation;

  @override
  State<LingoRoadApp> createState() => _LingoRoadAppState();
}

class _LingoRoadAppState extends State<LingoRoadApp> {
  late GoRouter _routerConfig;

  @override
  void initState() {
    super.initState();
    _routerConfig = _createRouter();
  }

  @override
  void didUpdateWidget(LingoRoadApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController ||
        oldWidget.placementViewModel != widget.placementViewModel ||
        oldWidget.initialLocation != widget.initialLocation) {
      _routerConfig.dispose();
      _routerConfig = _createRouter();
    }
  }

  GoRouter _createRouter() => createAppRouter(
        session: widget.sessionController,
        placementViewModel: widget.placementViewModel,
        initialLocation: widget.initialLocation,
      );

  @override
  void dispose() {
    _routerConfig.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(
          value: widget.sessionController,
        ),
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<PlacementRepository>.value(value: widget.placementRepository),
        ChangeNotifierProvider<PlacementViewModel>.value(
          value: widget.placementViewModel,
        ),
      ],
      child: MaterialApp.router(
        title: 'lingoRoad',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _routerConfig,
      ),
    );
  }
}
