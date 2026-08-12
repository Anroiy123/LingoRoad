import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  bool _profileLookupScheduled = false;
  String? _email;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileLookupScheduled || widget.dashboard.name.trim().isNotEmpty) {
      return;
    }
    final repository = context.read<AuthRepository?>();
    if (repository == null) return;
    _profileLookupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEmail(repository));
  }

  Future<void> _loadEmail(AuthRepository repository) async {
    try {
      final profile = await repository.getProfile();
      if (mounted) setState(() => _email = profile.email);
    } catch (_) {
      // The dashboard remains usable when an optional profile refresh fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final dashboard = widget.dashboard;
    return Row(
      children: [
        _InitialsAvatar(name: dashboard.name, email: _email, l10n: l10n),
        SizedBox(width: AppSpacing.xs.w),
        Expanded(
          child: Text(
            'LingoRoad',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _HeaderRewardMetric(
          key: const Key('header_xp'),
          icon: Icons.bolt_rounded,
          value: dashboard.xp,
          color: Theme.of(context).colorScheme.primary,
          semanticsLabel: l10n.translate('home.xp_semantics', [dashboard.xp]),
        ),
        SizedBox(width: AppSpacing.xxs.w),
        _HeaderRewardMetric(
          key: const Key('header_coins'),
          icon: Icons.toll_rounded,
          value: dashboard.coins,
          color: Theme.of(context).colorScheme.tertiary,
          semanticsLabel: l10n.translate('home.coins_semantics', [
            dashboard.coins,
          ]),
        ),
        SizedBox(width: AppSpacing.xxs.w),
        _StreakPill(value: dashboard.currentStreak, l10n: l10n),
      ],
    );
  }
}

class _HeaderRewardMetric extends StatelessWidget {
  const _HeaderRewardMetric({
    required this.icon,
    required this.value,
    required this.color,
    required this.semanticsLabel,
    super.key,
  });

  final IconData icon;
  final int value;
  final Color color;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 3.w),
              Text(
                '$value',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.value, required this.l10n});

  final int value;
  final AppLanguageProvider l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: l10n.translate('home.streak_semantics', [value]),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999.r),
        child: InkWell(
          key: const Key('header_streak'),
          onTap: () => context.push('/streak-details'),
          borderRadius: BorderRadius.circular(999.r),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 20.sp,
                    color: scheme.primary,
                  ),
                  SizedBox(width: AppSpacing.xxs.w),
                  Text(
                    l10n.translate('home.streak_compact', [value]),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.name,
    required this.email,
    required this.l10n,
  });

  final String name;
  final String? email;
  final AppLanguageProvider l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final identity = name.trim().isNotEmpty ? name.trim() : email?.trim() ?? '';
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.surfaceContainerHighest,
    ];
    final index = _stableIndex(identity, palette.length);
    final background = palette[index];
    final foreground = switch (index) {
      0 => scheme.onPrimaryContainer,
      1 => scheme.onSecondaryContainer,
      2 => scheme.onTertiaryContainer,
      _ => scheme.onSurfaceVariant,
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      image: true,
      label: l10n.translate('home.avatar_semantics', [identity]),
      child: ExcludeSemantics(
        child: CircleAvatar(
          key: const Key('home_avatar'),
          radius: 20.r,
          backgroundColor: background,
          foregroundColor: foreground,
          child: Text(
            _initials(identity),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '?';
  final emailLocal = normalized.contains('@')
      ? normalized.substring(0, normalized.indexOf('@'))
      : null;
  if (emailLocal != null) return _firstRune(emailLocal);
  final parts = normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length == 1) return _firstRune(parts.first);
  return '${_firstRune(parts.first)}${_firstRune(parts.last)}';
}

String _firstRune(String value) =>
    String.fromCharCode(value.runes.first).toUpperCase();

int _stableIndex(String value, int length) {
  var hash = 0x811C9DC5;
  for (final rune in value.trim().toLowerCase().runes) {
    hash = ((hash ^ rune) * 0x01000193) & 0x7FFFFFFF;
  }
  return hash % length;
}

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('home_summary_hero'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('home.welcome', [dashboard.name]),
            key: const Key('home_welcome'),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppSpacing.xxs.h),
          Text(
            l10n.translate('home.subtitle'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayLessonCard extends StatelessWidget {
  const TodayLessonCard({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final lesson = dashboard.todayLesson;
    if (lesson == null) {
      return AppCard(
        key: const Key('home_today_lesson'),
        variant: AppCardVariant.tonal,
        child: Text(l10n.translate('home.today_lesson.empty')),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = isDark ? scheme.primaryContainer : scheme.primary;
    final cardForeground = isDark
        ? scheme.onPrimaryContainer
        : scheme.onPrimary;
    return Container(
      key: const Key('home_today_lesson'),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 112.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: cardForeground.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                color: cardForeground,
                size: 21.sp,
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('home.today_lesson.tag').toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cardForeground.withValues(alpha: .86),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    l10n.currentLanguage == AppLanguage.vi
                        ? lesson.titleVi
                        : lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cardForeground,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    l10n.translate('home.today_lesson.details', [
                      lesson.cefr,
                      lesson.itemCount,
                      dashboard.dailyGoalMinutes,
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cardForeground.withValues(alpha: .9),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Semantics(
              button: true,
              label: l10n.translate('home.today_lesson.start'),
              child: Tooltip(
                message: l10n.translate('home.today_lesson.start'),
                child: SizedBox(
                  key: const Key('home_start_lesson'),
                  width: 48.w,
                  height: 48.h,
                  child: FilledButton(
                    onPressed: () => context.push('/lesson/${lesson.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.primary,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 22.sp),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrollable learning rail keeps the main lesson prominent
/// while making a secondary practice action readily discoverable.
class HomeLearningCarousel extends StatelessWidget {
  const HomeLearningCarousel({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = (constraints.maxWidth * .86)
            .clamp(280.w, 320.w)
            .toDouble();
        final secondaryWidth = (constraints.maxWidth * .72)
            .clamp(220.w, 264.w)
            .toDouble();

        return Semantics(
          label: 'Hoạt động học tập, vuốt ngang để xem thêm',
          child: SingleChildScrollView(
            key: const Key('home_learning_carousel'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: heroWidth,
                  height: 132.h,
                  child: TodayLessonCard(dashboard: dashboard),
                ),
                SizedBox(width: AppSpacing.sm.w),
                SizedBox(
                  width: secondaryWidth,
                  height: 132.h,
                  child: HomeQuickActions(dashboard: dashboard),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeDailyPlan extends StatelessWidget {
  const HomeDailyPlan({
    required this.dashboard,
    required this.quests,
    super.key,
  });

  final DashboardData dashboard;
  final List<QuestData> quests;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final scheme = Theme.of(context).colorScheme;
    final dailyXp = quests
        .where((quest) => quest.code == 'daily_xp')
        .firstOrNull;
    final dailyReview = quests
        .where((quest) => quest.code == 'daily_review')
        .firstOrNull;
    final masteryPercent = (dashboard.mastery * 100).round();
    final learnedMinutes =
        (dashboard.dailyProgress * dashboard.dailyGoalMinutes).round();
    final dailyGoalCompleted = dashboard.dailyProgress >= 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyProgressColor = dailyGoalCompleted
        ? (isDark ? AppColorsDark.success : AppColors.success)
        : scheme.primary.withValues(alpha: .72);
    final xpRemaining = dailyXp == null ? 0 : dailyXp.target - dailyXp.current;
    final xpNearlyCompleted =
        dailyXp != null &&
        !dailyXp.completed &&
        dailyXp.target > 0 &&
        xpRemaining > 0 &&
        dailyXp.current / dailyXp.target >= .8;
    final target = dashboard.targetCefr;
    final journey = target == null || target == dashboard.currentCefr
        ? l10n.translate('home.level_current', [dashboard.currentCefr])
        : l10n.translate('home.level_journey', [dashboard.currentCefr, target]);
    final levelSummary =
        '$journey · ${l10n.translate("home.mastery_percent", [masteryPercent])}';
    return AppCard(
      key: const Key('home_daily_plan'),
      borderWidth: 1,
      borderRadius: 20,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate('home.plan.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: l10n.translate('home.mastery_semantics', [
                    dashboard.currentCefr,
                    target ?? dashboard.currentCefr,
                    masteryPercent,
                  ]),
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            levelSummary,
                            key: const Key('home_level_summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        AppProgress(
                          key: const Key('home_mastery_progress'),
                          value: dashboard.mastery,
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                _DailyPlanRow(
                  cardKey: const Key('home_daily_goal_row'),
                  icon: Icons.timer_outlined,
                  label: l10n.translate('home.plan.goal_minutes', [
                    dashboard.dailyGoalMinutes,
                  ]),
                  current: learnedMinutes,
                  target: dashboard.dailyGoalMinutes,
                  completed: dailyGoalCompleted,
                  progressKey: const Key('home_daily_progress'),
                  progressColorOverride: dailyProgressColor,
                  showProgressWhenCompleted: true,
                  keepTaskIconWhenCompleted: true,
                ),
                SizedBox(height: AppSpacing.xs.h),
                _DailyPlanRow(
                  cardKey: const Key('home_daily_review_card'),
                  icon: Icons.style_outlined,
                  label: l10n.translate('home.plan.review_cards', [
                    dashboard.dueReviews,
                  ]),
                  current: dailyReview?.current,
                  target: dailyReview?.target,
                  completed:
                      dailyReview?.completed ?? dashboard.dueReviews == 0,
                  onTap: () => context.go('/review'),
                ),
                if (dailyXp != null) ...[
                  SizedBox(height: AppSpacing.xs.h),
                  _DailyPlanRow(
                    cardKey: const Key('home_daily_xp_card'),
                    icon: Icons.bolt_rounded,
                    label: l10n.translate('home.plan.xp_target', [
                      dailyXp.target,
                    ]),
                    current: dailyXp.current,
                    target: dailyXp.target,
                    completed: dailyXp.completed,
                    nearCompletionLabel: xpNearlyCompleted
                        ? l10n.translate('home.plan.remaining_xp', [
                            xpRemaining,
                          ])
                        : null,
                    progressKey: const Key('home_daily_xp_progress'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPlanRow extends StatelessWidget {
  const _DailyPlanRow({
    this.cardKey,
    required this.icon,
    required this.label,
    required this.completed,
    this.current,
    this.target,
    this.onTap,
    this.progressKey,
    this.nearCompletionLabel,
    this.progressColorOverride,
    this.showProgressWhenCompleted = false,
    this.keepTaskIconWhenCompleted = false,
  });

  final IconData icon;
  final Key? cardKey;
  final String label;
  final bool completed;
  final int? current;
  final int? target;
  final VoidCallback? onTap;
  final Key? progressKey;
  final String? nearCompletionLabel;
  final Color? progressColorOverride;
  final bool showProgressWhenCompleted;
  final bool keepTaskIconWhenCompleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successForeground = isDark
        ? AppColorsDark.successForeground
        : AppColors.successForeground;
    final foreground = completed ? successForeground : scheme.onSurface;
    final targetValue = target ?? 0;
    final progress = targetValue == 0 ? null : (current ?? 0) / targetValue;
    final progressColor =
        progressColorOverride ??
        (progress != null && progress >= .8
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: .5));
    final content = Container(
      key: cardKey,
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: completed
                  ? successForeground.withValues(alpha: .12)
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Icon(
              completed && !keepTaskIconWhenCompleted
                  ? Icons.check_rounded
                  : icon,
              color: completed ? successForeground : scheme.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (progress != null &&
                    (!completed || showProgressWhenCompleted)) ...[
                  SizedBox(height: AppSpacing.xs.h),
                  AppProgress(
                    key: progressKey,
                    value: progress,
                    height: 4,
                    color: progressColor,
                  ),
                ],
              ],
            ),
          ),
          if (completed) ...[
            SizedBox(width: AppSpacing.sm.w),
            Text(
              context.watch<AppLanguageProvider>().translate(
                'home.plan.completed',
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: successForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (nearCompletionLabel != null) ...[
            SizedBox(width: AppSpacing.sm.w),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: AppSpacing.xxs.h,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                nearCompletionLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ] else if (current != null && target != null) ...[
            SizedBox(width: AppSpacing.sm.w),
            Text(
              completed ? '✓' : '$current/$target',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      checked: completed,
      label: label,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
              child: content,
            ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) => _QuickActionCard(
    key: const Key('home_ai_practice'),
    icon: Icons.record_voice_over_outlined,
    title: context.watch<AppLanguageProvider>().translate(
      'home.quick_actions.practice_pronunciation',
    ),
    subtitle: context.watch<AppLanguageProvider>().translate(
      'home.quick_actions.practice_desc',
    ),
    onTap: () => context.push('/practice'),
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      color: scheme.surface,
      borderColor: isDark ? AppColorsDark.cardBorder : AppColors.cardBorder,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 132.h),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.xs.h,
            ),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg.r),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: AppSpacing.xxs.h),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Icon(Icons.arrow_forward_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    if (dashboard.recentActivity.isEmpty) return const SizedBox.shrink();
    final l10n = context.watch<AppLanguageProvider>();
    final activities = dashboard.recentActivity.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.translate('home.recent.title')),
        SizedBox(height: AppSpacing.sm.h),
        for (var index = 0; index < activities.length; index++) ...[
          _ActivityRow(activity: activities[index]),
          if (index != activities.length - 1) SizedBox(height: AppSpacing.sm.h),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final RecentLessonActivity activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successSurface = isDark
        ? AppColorsDark.successSurface
        : AppColors.successSurface;
    final successForeground = isDark
        ? AppColorsDark.successForeground
        : AppColors.successForeground;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: successSurface,
            child: Icon(Icons.menu_book_outlined, color: successForeground),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              l10n.currentLanguage == AppLanguage.vi
                  ? activity.titleVi
                  : activity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.check_circle_rounded, color: successForeground),
        ],
      ),
    );
  }
}
