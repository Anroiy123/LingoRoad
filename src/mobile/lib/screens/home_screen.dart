import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
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
          children: [const LingoHeader(streak: null), loadingView()]);
    }
    if (viewModel.state == DashboardState.error) {
      return AppPage(
        children: [
          const LingoHeader(streak: null),
          AppCard(
            key: const Key('home_error'),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.error),
                SizedBox(height: AppSpacing.sm.h),
                Text(l10n.translate('home.error')),
                SizedBox(height: AppSpacing.md.h),
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
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: AppPage(
        children: [
          LingoHeader(streak: dashboard.currentStreak),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('home.welcome', [dashboard.name]),
                key: const Key('home_welcome'),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontSize: 32.sp),
              ),
              Text(
                l10n.translate('home.subtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(
                l10n.translate('home.level_summary', [
                  dashboard.currentCefr,
                  dashboard.targetCefr ?? '—',
                  (dashboard.mastery * 100).round(),
                ]),
                key: const Key('home_level_summary'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          AppCard(
            child: Column(
              children: [
                MetricRow(
                  label: l10n.translate('home.metrics.daily_goal'),
                  value: (dashboard.dailyProgress * 100).round(),
                ),
                SizedBox(height: AppSpacing.sm.h),
                MetricRow(
                  label: l10n.translate('home.metrics.weekly_goal'),
                  value: (dashboard.weeklyProgress * 100).round(),
                ),
              ],
            ),
          ),
          _TodayLessonCard(dashboard: dashboard),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.bolt_rounded,
                  label: 'XP',
                  value: '${dashboard.xp}',
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _MetricCard(
                  icon: Icons.monetization_on_outlined,
                  label: l10n.translate('home.stats.coins'),
                  value: '${dashboard.coins}',
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _MetricCard(
                  icon: Icons.menu_book_rounded,
                  label: l10n.translate('home.stats.due'),
                  value: '${dashboard.dueReviews}',
                ),
              ),
            ],
          ),
          AppCard(
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: const Key('home_ai_practice'),
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryFixed,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(l10n.currentLanguage == AppLanguage.vi
                    ? 'Luyện tập AI'
                    : 'AI Practice'),
                subtitle: Text(l10n.currentLanguage == AppLanguage.vi
                    ? 'Cố vấn lộ trình · Viết · Phát âm'
                    : 'Path advisor · Writing · Speaking'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/practice'),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(l10n.translate('home.quests_title')),
              SizedBox(height: AppSpacing.sm.h),
              for (final quest in viewModel.quests) ...[
                _QuestTile(quest: quest),
                SizedBox(height: AppSpacing.sm.h),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(l10n.translate('home.recent.title')),
              SizedBox(height: AppSpacing.sm.h),
              if (dashboard.recentActivity.isEmpty)
                AppCard(child: Text(l10n.translate('home.recent.empty')))
              else
                for (final activity in dashboard.recentActivity) ...[
                  _RecentTile(activity: activity),
                  SizedBox(height: AppSpacing.sm.h),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayLessonCard extends StatelessWidget {
  const _TodayLessonCard({required this.dashboard});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final lesson = dashboard.todayLesson;
    return Container(
      key: const Key('home_today_lesson'),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('home.today_lesson.tag'),
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            lesson == null
                ? l10n.translate('home.today_lesson.empty')
                : (l10n.currentLanguage == AppLanguage.vi
                    ? lesson.titleVi
                    : lesson.title),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          if (lesson != null) ...[
            SizedBox(height: AppSpacing.xs.h),
            Text(
              l10n.translate('home.today_lesson.details', [
                lesson.cefr,
                lesson.itemCount,
                dashboard.dailyGoalMinutes,
              ]),
              style: const TextStyle(color: Colors.white),
            ),
            SizedBox(height: AppSpacing.md.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('home_start_lesson'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => context.push('/lesson/${lesson.id}'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(l10n.translate('home.today_lesson.start')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.all(AppSpacing.sm.w),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});

  final QuestData quest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final titleKey = switch (quest.code) {
      'daily_lesson' => 'home.quests.daily_lesson',
      'daily_review' => 'home.quests.daily_review',
      _ => 'home.quests.daily_xp',
    };
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Row(
        children: [
          Icon(
            quest.completed ? Icons.check_circle_rounded : Icons.flag_rounded,
            color: quest.completed ? AppColors.success : AppColors.primary,
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate(titleKey)),
                SizedBox(height: AppSpacing.xs.h),
                AppProgress(
                    value:
                        quest.target == 0 ? 0 : quest.current / quest.target),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Text('${quest.current}/${quest.target}'),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.activity});

  final RecentLessonActivity activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final title = l10n.currentLanguage == AppLanguage.vi
        ? activity.titleVi
        : activity.title;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(child: Text(title)),
          Text('${activity.completedAt.day}/${activity.completedAt.month}'),
        ],
      ),
    );
  }
}
