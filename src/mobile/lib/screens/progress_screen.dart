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
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  l.translate('progress.title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  l.translate('progress.subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Container(
                  height: 48.h,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg.r),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    labelStyle: Theme.of(context).textTheme.labelLarge,
                    unselectedLabelStyle: Theme.of(
                      context,
                    ).textTheme.labelLarge,
                    tabs: [
                      Tab(text: l.translate('progress.tabs.overview')),
                      Tab(text: l.translate('progress.tabs.skills')),
                      Tab(text: l.translate('progress.tabs.achievements')),
                    ],
                  ),
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
      key: PageStorageKey(skills ? 'progress-skills' : 'progress-overview'),
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
            for (final category in vm.strengths.take(2)) ...[
              _overviewSkillCard(category, l, positive: true),
              if (category != vm.strengths.take(2).last)
                SizedBox(height: AppSpacing.sm.h),
            ],
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
            for (final category in vm.improvements.take(2)) ...[
              _overviewSkillCard(category, l, positive: false),
              if (category != vm.improvements.take(2).last)
                SizedBox(height: AppSpacing.sm.h),
            ],
          SizedBox(height: AppSpacing.md.h),
          _focusInsight(vm.weakest, l),
        ] else ...[
          SectionTitle(l.translate('progress.skills_analysis.title')),
          SizedBox(height: AppSpacing.xxs.h),
          Text(
            l.translate('progress.subtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          if (categories.isEmpty)
            _categoryEmpty(
              key: const Key('progress_skills_empty'),
              icon: Icons.bar_chart_outlined,
              text: l.translate('progress.empty'),
            )
          else
            _skillsGroup(categories, l),
          SizedBox(height: AppSpacing.md.h),
          _focusInsight(vm.weakest, l, key: const Key('progress_skills_focus')),
        ],
      ],
    );
  }

  Widget _overviewSkillCard(
    CategoryProgress category,
    AppLanguageProvider l, {
    required bool positive,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: _outlinedSurface(
        context,
        radius: AppRadius.lg,
      ),
      child: _skillContent(category, l, compact: true),
    );
  }

  Widget _skillsGroup(
    List<CategoryProgress> categories,
    AppLanguageProvider l,
  ) => Container(
    key: const Key('progress_skills_group'),
    padding: EdgeInsets.all(AppSpacing.md.w),
    decoration: _outlinedSurface(context),
    child: Column(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          KeyedSubtree(
            key: Key('progress_skill_${categories[index].category}'),
            child: _skillContent(categories[index], l),
          ),
          if (index != categories.length - 1)
            SizedBox(height: AppSpacing.md.h),
        ],
      ],
    ),
  );

  Widget _skillContent(
    CategoryProgress category,
    AppLanguageProvider l, {
    bool compact = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final categoryLabel = _categoryLabel(category.category, l);
    final value = category.practiced
        ? '${category.percent}%'
        : l.translate('progress.skill_unpracticed');
    return Semantics(
      label: '$categoryLabel, $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 28.w : 32.w,
                  height: compact ? 28.w : 32.w,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                  child: Icon(
                    _categoryIcon(category.category),
                    color: scheme.primary,
                    size: compact ? 16.sp : 18.sp,
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Text(
                    categoryLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: category.practiced
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs.h),
            AppProgress(
              value: category.practiced ? category.percent / 100 : 0,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _focusInsight(String? weakest, AppLanguageProvider l, {Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: key ?? const Key('progress_focus_insight'),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: _outlinedSurface(context, radius: AppRadius.lg),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              weakest == null
                  ? l.translate('progress.suggestion.start')
                  : l.translate('progress.suggestion.weakest', [
                      _categoryLabel(weakest, l),
                    ]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactStat(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String value,
    required String detail,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: key,
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: _outlinedSurface(context, radius: AppRadius.lg),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20.sp),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementStat(
    BuildContext context, {
    required String value,
    required String label,
  }) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: AppSpacing.xxs.h),
      Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10.sp,
        ),
      ),
    ],
  );

  String _categoryLabel(String category, AppLanguageProvider l) =>
      l.translate('progress.skills_list.$category');

  IconData _categoryIcon(String category) => switch (category) {
    'grammar' => Icons.menu_book_outlined,
    'vocabulary' => Icons.translate_rounded,
    'listening' => Icons.headphones_rounded,
    'speaking' => Icons.record_voice_over_outlined,
    'pronunciation' => Icons.graphic_eq_rounded,
    'writing' => Icons.edit_note_rounded,
    _ => Icons.auto_graph_rounded,
  };

  Widget _categoryEmpty({
    required Key key,
    required IconData icon,
    required String text,
  }) => AppCard(
    key: key,
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
    final targetCefr = dashboard.targetCefr;
    final cefrStatus = targetCefr == null || targetCefr.isEmpty
        ? dashboard.currentCefr
        : targetCefr == dashboard.currentCefr
        ? '${dashboard.currentCefr} · ${l.translate('progress.overview.maintaining')}'
        : '${dashboard.currentCefr} → $targetCefr';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('progress_cefr_hero'),
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: _outlinedSurface(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.translate('progress.overview.cefr_journey'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    cefrStatus,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.translate('progress.overview.mastery'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${(dashboard.mastery * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: LinearProgressIndicator(
                  value: dashboard.mastery.clamp(0, 1),
                  minHeight: 8.h,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                '${dashboard.completedLessons} ${l.translate('progress.overview.completed_lessons').toLowerCase()} · ${dashboard.dueReviews} ${l.translate('progress.overview.due_reviews').toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Row(
          key: const Key('progress_compact_stats'),
          children: [
            Expanded(
              child: _compactStat(
                context,
                key: const Key('progress_xp_stat'),
                icon: Icons.workspace_premium_outlined,
                value: '${dashboard.xp} XP',
                detail:
                    '${dashboard.coins} ${l.translate('progress.overview.coins').toLowerCase()}',
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: _compactStat(
                context,
                key: const Key('progress_streak_stat'),
                icon: Icons.local_fire_department_rounded,
                value: '${dashboard.currentStreak}',
                detail: l.translate('progress.overview.streak').toLowerCase(),
              ),
            ),
          ],
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
    final completedQuests = vm.quests.where((quest) => quest.completed).length;
    return ListView(
      key: const PageStorageKey('progress-achievements'),
      padding: EdgeInsets.all(AppSpacing.margin.w),
      children: [
        Container(
          key: const Key('progress_achievement_stats'),
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: _outlinedSurface(context),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _achievementStat(
                      context,
                      value: '${dashboard.xp}',
                      label: l.translate('progress.overview.total_xp'),
                    ),
                  ),
                  Expanded(
                    child: _achievementStat(
                      context,
                      value: '${dashboard.currentStreak}',
                      label: l.translate('progress.overview.streak'),
                    ),
                  ),
                  Expanded(
                    child: _achievementStat(
                      context,
                      value: '${dashboard.longestStreak}',
                      label: l.translate('progress.overview.longest_streak'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs.h),
              Text(
                '${dashboard.coins} ${l.translate('progress.overview.coins').toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        Row(
          children: [
            Expanded(
              child: SectionTitle(l.translate('progress.overview.quests')),
            ),
            Text(
              '$completedQuests/${vm.quests.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm.h),
        if (vm.quests.isEmpty)
          AppCard(child: Text(l.translate('progress.quests_empty')))
        else
          Container(
            key: const Key('progress_quests_group'),
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: _outlinedSurface(context),
            child: Column(
              children: [
                for (var index = 0; index < vm.quests.length; index++) ...[
                  _questCard(vm.quests[index], l),
                  if (index != vm.quests.length - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                      child: Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _questCard(QuestData quest, AppLanguageProvider l) {
    final scheme = Theme.of(context).colorScheme;
    final progress = quest.target == 0
        ? 0.0
        : (quest.current / quest.target).clamp(0, 1).toDouble();
    return Semantics(
      label:
          '${l.translate(_questKey(quest.code))}, ${quest.current}/${quest.target}, ${(progress * 100).round()}%',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quest.completed
                      ? Icons.check_circle_rounded
                      : Icons.flag_outlined,
                  color: quest.completed
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Text(
                    l.translate(_questKey(quest.code)),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${quest.current}/${quest.target}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs.h),
            AppProgress(value: progress, height: 6),
          ],
        ),
      ),
    );
  }

  String _questKey(String code) => switch (code) {
    'daily_lesson' => 'home.quests.daily_lesson',
    'daily_review' => 'home.quests.daily_review',
    _ => 'home.quests.daily_xp',
  };

  BoxDecoration _outlinedSurface(
    BuildContext context, {
    double radius = AppRadius.xl,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius.r),
      border: Border.all(color: scheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(
            alpha: theme.brightness == Brightness.dark ? .14 : .06,
          ),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _text(String text) => Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
