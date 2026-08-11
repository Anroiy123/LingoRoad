import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({this.active = true, this.initialTab = 0, super.key})
    : assert(initialTab >= 0 && initialTab < 3);
  final bool active;
  final int initialTab;
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      initialIndex: widget.initialTab,
      vsync: this,
    );
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ProgressScreen old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      _scheduled = false;
      _schedule();
    }
  }

  void _schedule() {
    if (!widget.active || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProgressViewModel>().load();
      context.read<DashboardViewModel?>()?.load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final l = context.watch<AppLanguageProvider>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.margin.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LingoHeader(streak: null),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  l.translate('progress.title'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 28.sp),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  l.translate('progress.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(text: l.translate('progress.tabs.overview')),
                    Tab(text: l.translate('progress.tabs.skills')),
                    Tab(text: l.translate('progress.tabs.achievements')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _live(context, l, false),
                _live(context, l, true),
                _achievements(context, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _live(BuildContext context, AppLanguageProvider l, bool skills) {
    final vm = context.watch<ProgressViewModel>();
    if (vm.state == ProgressState.initial ||
        vm.state == ProgressState.loading) {
      return loadingView(
        key: const Key('progress_loading'),
        label: l.translate('progress.loading'),
      );
    }
    if (vm.state == ProgressState.error) return _retry(l, vm);
    if (vm.state == ProgressState.empty) {
      return _text(l.translate('progress.empty'));
    }
    final categories = vm.categories;
    return ListView(
      padding: EdgeInsets.all(AppSpacing.margin.w),
      children: [
        if (!skills) ...[
          _dashboardSummary(context, l),
          SizedBox(height: AppSpacing.lg.h),
          SectionTitle(l.translate('progress.overview.strengths')),
          SizedBox(height: AppSpacing.sm.h),
          if (vm.strengths.isEmpty)
            _categoryEmpty(
              key: const Key('progress_strengths_empty'),
              icon: Icons.auto_graph_rounded,
              text: l.translate('progress.strengths_empty'),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (var index = 0; index < vm.strengths.length; index++) ...[
                    _metric(vm.strengths[index], l),
                    if (index != vm.strengths.length - 1)
                      SizedBox(height: AppSpacing.md.h),
                  ],
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md.h),
          SectionTitle(l.translate('progress.overview.improvements')),
          SizedBox(height: AppSpacing.sm.h),
          if (vm.improvements.isEmpty)
            _categoryEmpty(
              key: const Key('progress_improvements_empty'),
              icon: Icons.insights_outlined,
              text: l.translate('progress.improvements_empty'),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < vm.improvements.length;
                    index++
                  ) ...[
                    _metric(vm.improvements[index], l),
                    if (index != vm.improvements.length - 1)
                      SizedBox(height: AppSpacing.md.h),
                  ],
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md.h),
          AppCard(
            variant: AppCardVariant.tonal,
            child: Text(
              vm.weakest == null
                  ? l.translate('progress.suggestion.start')
                  : l.translate('progress.suggestion.weakest', [vm.weakest!]),
            ),
          ),
        ] else ...[
          SectionTitle(l.translate('progress.skills_analysis.title')),
          SizedBox(height: AppSpacing.sm.h),
          if (categories.isEmpty)
            _categoryEmpty(
              key: const Key('progress_skills_empty'),
              icon: Icons.bar_chart_outlined,
              text: l.translate('progress.empty'),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (var index = 0; index < categories.length; index++) ...[
                    _metric(categories[index], l),
                    if (index != categories.length - 1)
                      SizedBox(height: AppSpacing.md.h),
                  ],
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md.h),
          AppCard(
            variant: AppCardVariant.tonal,
            child: Text(
              vm.weakest == null
                  ? l.translate('progress.suggestion.start')
                  : l.translate('progress.suggestion.weakest', [vm.weakest!]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metric(CategoryProgress e, AppLanguageProvider l) =>
      MetricRow(label: e.category, value: e.percent);

  Widget _categoryEmpty({
    required Key key,
    required IconData icon,
    required String text,
  }) => AppCard(
    key: key,
    variant: AppCardVariant.outlined,
    child: Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ),
  );
  Widget _retry(AppLanguageProvider l, ProgressViewModel vm) => Center(
    child: Semantics(
      key: const Key('progress_error'),
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: l.translate('progress.error_load_failed'),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Text(l.translate('progress.error_load_failed')),
            ),
            SizedBox(height: AppSpacing.md.h),
            Semantics(
              label: l.translate('progress.retry_load'),
              button: true,
              onTap: vm.load,
              child: ExcludeSemantics(
                child: FilledButton(
                  key: const Key('progress_retry'),
                  onPressed: vm.load,
                  child: Text(l.translate('common.retry')),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dashboardSummary(BuildContext context, AppLanguageProvider l) {
    final vm = context.watch<DashboardViewModel?>();
    if (vm == null || vm.state == DashboardState.initial) {
      return const SizedBox.shrink();
    }
    if (vm.state == DashboardState.loading) {
      return loadingView(label: l.translate('progress.loading'));
    }
    if (vm.state == DashboardState.error || vm.dashboard == null) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        label: l.translate('progress.summary_error'),
        child: AppCard(
          child: Column(
            children: [
              ExcludeSemantics(
                child: Text(l.translate('progress.summary_error')),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Semantics(
                label: l.translate('progress.retry_load'),
                button: true,
                onTap: vm.retry,
                child: ExcludeSemantics(
                  child: FilledButton(
                    onPressed: vm.retry,
                    child: Text(l.translate('common.retry')),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final dashboard = vm.dashboard!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.translate('progress.overview.cefr_journey')),
        AppCard(
          child: Column(
            children: [
              _summaryRow(
                l.translate('progress.overview.current_level'),
                dashboard.currentCefr,
              ),
              _summaryRow(
                l.translate('progress.overview.target_level'),
                dashboard.targetCefr ?? '—',
              ),
              MetricRow(
                label: l.translate('progress.overview.mastery'),
                value: (dashboard.mastery * 100).round(),
              ),
              SizedBox(height: AppSpacing.sm.h),
              _summaryRow(
                l.translate('progress.overview.total_xp'),
                '${dashboard.xp}',
              ),
              _summaryRow(
                l.translate('progress.overview.coins'),
                '${dashboard.coins}',
              ),
              _summaryRow(
                l.translate('progress.overview.streak'),
                '${dashboard.currentStreak}',
              ),
              _summaryRow(
                l.translate('progress.overview.completed_lessons'),
                '${dashboard.completedLessons}',
              ),
              _summaryRow(
                l.translate('progress.overview.due_reviews'),
                '${dashboard.dueReviews}',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _achievements(BuildContext context, AppLanguageProvider l) {
    final vm = context.watch<DashboardViewModel?>();
    if (vm == null ||
        vm.state == DashboardState.initial ||
        vm.state == DashboardState.loading) {
      return loadingView(label: l.translate('progress.loading'));
    }
    if (vm.state == DashboardState.error || vm.dashboard == null) {
      return Center(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: l.translate('progress.summary_error'),
          child: Semantics(
            label: l.translate('progress.retry_load'),
            button: true,
            onTap: vm.retry,
            child: ExcludeSemantics(
              child: FilledButton(
                onPressed: vm.retry,
                child: Text(l.translate('common.retry')),
              ),
            ),
          ),
        ),
      );
    }
    final dashboard = vm.dashboard!;
    return ListView(
      padding: EdgeInsets.all(AppSpacing.margin.w),
      children: [
        AppCard(
          child: Column(
            children: [
              _summaryRow(
                l.translate('progress.overview.total_xp'),
                '${dashboard.xp}',
              ),
              _summaryRow(
                l.translate('progress.overview.coins'),
                '${dashboard.coins}',
              ),
              _summaryRow(
                l.translate('progress.overview.streak'),
                '${dashboard.currentStreak}',
              ),
              _summaryRow(
                l.translate('progress.overview.longest_streak'),
                '${dashboard.longestStreak}',
                last: true,
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        SectionTitle(l.translate('progress.overview.quests')),
        if (vm.quests.isEmpty)
          AppCard(child: Text(l.translate('progress.quests_empty')))
        else
          for (final quest in vm.quests) ...[
            _questCard(quest, l),
            SizedBox(height: AppSpacing.sm.h),
          ],
      ],
    );
  }

  Widget _questCard(QuestData quest, AppLanguageProvider l) => AppCard(
    child: Semantics(
      label:
          '${l.translate(_questKey(quest.code))}, ${quest.current}/${quest.target}',
      child: Row(
        children: [
          Icon(
            quest.completed ? Icons.check_circle : Icons.flag_outlined,
            color: quest.completed
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(child: Text(l.translate(_questKey(quest.code)))),
          Text('${quest.current}/${quest.target}'),
        ],
      ),
    ),
  );

  String _questKey(String code) => switch (code) {
    'daily_lesson' => 'home.quests.daily_lesson',
    'daily_review' => 'home.quests.daily_review',
    _ => 'home.quests.daily_xp',
  };

  Widget _summaryRow(String label, String value, {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.sm.h),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _text(String text) => Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
