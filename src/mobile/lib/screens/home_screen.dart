import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/screens/home/home_sections.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<DashboardViewModel?>();
    if (!_scheduled && viewModel?.state == DashboardState.initial) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) viewModel?.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final viewModel = context.watch<DashboardViewModel?>();

    if (viewModel == null) {
      return const AppPage(
        children: [
          LingoHeader(streak: null),
          SizedBox(key: Key('home_unconfigured')),
        ],
      );
    }

    if (viewModel.state == DashboardState.initial ||
        viewModel.state == DashboardState.loading) {
      return AppPage(
        children: [const LingoHeader(streak: null), loadingView()],
      );
    }

    if (viewModel.state == DashboardState.error) {
      return AppPage(
        children: [
          const LingoHeader(streak: null),
          AppCard(
            key: const Key('home_error'),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.translate('home.error')),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const Key('home_retry'),
                  onPressed: viewModel.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.translate('common.retry')),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final dashboard = viewModel.dashboard!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerShadow = isDark
        ? AppColorsDark.shadow
        : AppColors.shadow;
    final content = [
      HomeGreeting(dashboard: dashboard),
      HomeDailyPlan(dashboard: dashboard, quests: viewModel.quests),
      HomeLearningCarousel(dashboard: dashboard),
      HomeRecentActivity(dashboard: dashboard),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            key: const Key('home_sticky_header'),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin.w,
              AppSpacing.xs.h,
              AppSpacing.margin.w,
              AppSpacing.sm.h,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: headerShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: HomeHeader(dashboard: dashboard),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                key: const Key('home_content_scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.margin.w,
                  AppSpacing.md.h,
                  AppSpacing.margin.w,
                  112.h,
                ),
                children: _withSpacing(content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) => [
    for (var index = 0; index < children.length; index++) ...[
      children[index],
      if (index != children.length - 1) SizedBox(height: AppSpacing.lg.h),
    ],
  ];
}
