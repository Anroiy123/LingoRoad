import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/session/secure_session_store.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_session_provider.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/features/practice/data/practice_repository.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/features/dictionary/data/dictionary_repository.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final session = SessionController(const SecureSessionStore());
  final apiClient = ApiClient(
    config: AppConfig(),
    session: session,
  );
  final authRepository = ApiAuthRepository(apiClient);
  final placementRepository = ApiPlacementRepository(apiClient);
  final placementViewModel = PlacementViewModel(placementRepository);
  final learningPathRepository = ApiLearningPathRepository(apiClient);
  final learningPathViewModel = LearningPathViewModel(learningPathRepository);
  final reviewRepository = ApiReviewRepository(apiClient);
  final progressRepository = ApiProgressRepository(apiClient);
  final lessonRepository = ApiLessonRepository(apiClient);
  final dashboardRepository = ApiDashboardRepository(apiClient);
  final aiPracticeRepository = ApiAiPracticeRepository(apiClient);
  final dictionaryRepository = ApiDictionaryRepository(apiClient);

  final viJson = await rootBundle.loadString('assets/translations/vi.json');
  final enJson = await rootBundle.loadString('assets/translations/en.json');

  final translations = {
    AppLanguage.vi: json.decode(viJson) as Map<String, dynamic>,
    AppLanguage.en: json.decode(enJson) as Map<String, dynamic>,
  };

  session.configurePlacementStatusLoader(placementRepository.isCompleted);

  final router = createAppRouter(
    session: session,
    placementViewModel: placementViewModel,
  );

  final languageProvider = AppLanguageProvider(
    sharedPreferences: sharedPreferences,
    translations: translations,
  );

  runApp(
    LingoRoadApp(
      routerConfig: router,
      sessionController: session,
      authRepository: authRepository,
      placementRepository: placementRepository,
      placementViewModel: placementViewModel,
      learningPathRepository: learningPathRepository,
      learningPathViewModel: learningPathViewModel,
      reviewRepository: reviewRepository,
      progressRepository: progressRepository,
      lessonRepository: lessonRepository,
      dashboardRepository: dashboardRepository,
      aiPracticeRepository: aiPracticeRepository,
      dictionaryRepository: dictionaryRepository,
      languageProvider: languageProvider,
    ),
  );
  unawaited(session.restore());
}

class LingoRoadApp extends StatelessWidget {
  const LingoRoadApp({
    required this.routerConfig,
    required this.languageProvider,
    this.sessionController,
    this.authRepository,
    this.placementRepository,
    this.placementViewModel,
    this.learningPathRepository,
    this.learningPathViewModel,
    this.reviewRepository,
    this.progressRepository,
    this.lessonRepository,
    this.dashboardRepository,
    this.aiPracticeRepository,
    this.dictionaryRepository,
    super.key,
  });

  final GoRouter routerConfig;
  final SessionController? sessionController;
  final AuthRepository? authRepository;
  final PlacementRepository? placementRepository;
  final PlacementViewModel? placementViewModel;
  final LearningPathRepository? learningPathRepository;
  final LearningPathViewModel? learningPathViewModel;
  final ReviewRepository? reviewRepository;
  final ProgressRepository? progressRepository;
  final LessonRepository? lessonRepository;
  final DashboardRepository? dashboardRepository;
  final AiPracticeRepository? aiPracticeRepository;
  final DictionaryRepository? dictionaryRepository;
  final AppLanguageProvider languageProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLanguageProvider>.value(
          value: languageProvider,
        ),
        if (sessionController != null)
          ChangeNotifierProvider<SessionController>.value(
            value: sessionController!,
          )
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
          ChangeNotifierProvider<PlacementViewModel>.value(
            value: placementViewModel!,
          )
        else
          ChangeNotifierProvider<PlacementViewModel>(
            create: (context) => PlacementViewModel(
              context.read<PlacementRepository>(),
            ),
          ),
        if (learningPathRepository != null)
          Provider<LearningPathRepository>.value(value: learningPathRepository!)
        else
          Provider<LearningPathRepository>(
            create: (context) => ApiLearningPathRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        if (learningPathViewModel != null)
          ChangeNotifierProvider<LearningPathViewModel>.value(
            value: learningPathViewModel!,
          )
        else
          ChangeNotifierProvider<LearningPathViewModel>(
            create: (context) => LearningPathViewModel(
              context.read<LearningPathRepository>(),
            ),
          ),
        if (reviewRepository != null)
          Provider<ReviewRepository>.value(value: reviewRepository!)
        else
          Provider<ReviewRepository>(
              create: (context) => ApiReviewRepository(ApiClient(
                  config: AppConfig(),
                  session: context.read<SessionController>()))),
        ChangeNotifierProvider<ReviewViewModel>(
          create: (context) =>
              ReviewViewModel(context.read<ReviewRepository>()),
        ),
        if (progressRepository != null)
          Provider<ProgressRepository>.value(value: progressRepository!)
        else
          Provider<ProgressRepository>(
              create: (context) => ApiProgressRepository(ApiClient(
                  config: AppConfig(),
                  session: context.read<SessionController>()))),
        ChangeNotifierProvider<ProgressViewModel>(
          create: (context) =>
              ProgressViewModel(context.read<ProgressRepository>()),
        ),
        if (lessonRepository != null)
          Provider<LessonRepository>.value(value: lessonRepository!)
        else
          Provider<LessonRepository>(
            create: (context) => ApiLessonRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        if (dashboardRepository != null)
          Provider<DashboardRepository>.value(value: dashboardRepository!)
        else
          Provider<DashboardRepository>(
            create: (context) => ApiDashboardRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        dashboardViewModelProvider(),
        if (aiPracticeRepository != null)
          Provider<AiPracticeRepository>.value(value: aiPracticeRepository!)
        else
          Provider<AiPracticeRepository>(
            create: (context) => ApiAiPracticeRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
        if (dictionaryRepository != null)
          Provider<DictionaryRepository>.value(value: dictionaryRepository!)
        else
          Provider<DictionaryRepository>(
            create: (context) => ApiDictionaryRepository(
              ApiClient(
                config: AppConfig(),
                session: context.read<SessionController>(),
              ),
            ),
          ),
      ],
      child: Builder(
        builder: (context) {
          context.read<SessionController>().configurePlacementStatusLoader(
                context.read<PlacementRepository>().isCompleted,
              );
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'lingoRoad',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                routerConfig: routerConfig,
              );
            },
          );
        },
      ),
    );
  }
}
