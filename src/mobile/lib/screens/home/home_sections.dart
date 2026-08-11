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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _LevelBadge(level: dashboard.currentCefr, mastery: dashboard.mastery),
        SizedBox(width: AppSpacing.xxs.w),
        Semantics(
          button: true,
          label: l10n.translate('home.streak_semantics', [
            dashboard.currentStreak,
          ]),
          child: IconButton(
            key: const Key('header_streak'),
            onPressed: () => context.push('/streak-details'),
            icon: Badge(
              label: Text('${dashboard.currentStreak}'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              textColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Icon(
                Icons.local_fire_department_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
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

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.mastery});

  final String level;
  final double mastery;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 36),
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.sm.w,
      vertical: AppSpacing.xs.h,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          level,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: AppSpacing.xs.w),
        SizedBox(
          width: 42.w,
          child: AppProgress(value: mastery, height: 6),
        ),
      ],
    ),
  );
}

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Column(
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          l10n.translate('home.level_summary', [
            dashboard.currentCefr,
            dashboard.targetCefr ?? '—',
            (dashboard.mastery * 100).round(),
          ]),
          key: const Key('home_level_summary'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Wrap(
          spacing: AppSpacing.md.w,
          runSpacing: AppSpacing.xs.h,
          children: [
            _HeaderMetric(icon: Icons.bolt_rounded, value: dashboard.xp),
            _HeaderMetric(
              icon: Icons.monetization_on_outlined,
              value: dashboard.coins,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20.sp, color: Theme.of(context).colorScheme.primary),
      SizedBox(width: AppSpacing.xxs.w),
      Text('$value', style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

class HomeOverview extends StatelessWidget {
  const HomeOverview({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return AppCard(
      child: Column(
        children: [
          MetricRow(
            label: l10n.translate('home.metrics.daily_goal'),
            value: (dashboard.dailyProgress * 100).round(),
          ),
          SizedBox(height: AppSpacing.md.h),
          MetricRow(
            label: l10n.translate('home.metrics.weekly_goal'),
            value: (dashboard.weeklyProgress * 100).round(),
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

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('home_today_lesson'),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('home.today_lesson.tag'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            l10n.currentLanguage == AppLanguage.vi
                ? lesson.titleVi
                : lesson.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: scheme.onPrimary),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            l10n.translate('home.today_lesson.details', [
              lesson.cefr,
              lesson.itemCount,
              dashboard.dailyGoalMinutes,
            ]),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: .9),
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('home_start_lesson'),
              onPressed: () => context.push('/lesson/${lesson.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.translate('home.today_lesson.start')),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeQuestsSection extends StatelessWidget {
  const HomeQuestsSection({required this.quests, super.key});

  final List<QuestData> quests;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.translate('home.quests_title')),
        SizedBox(height: AppSpacing.sm.h),
        for (var index = 0; index < quests.length; index++) ...[
          _QuestCard(quest: quests[index]),
          if (index != quests.length - 1) SizedBox(height: AppSpacing.sm.h),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final QuestData quest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final titleKey = switch (quest.code) {
      'daily_lesson' => 'home.quests.daily_lesson',
      'daily_review' => 'home.quests.daily_review',
      _ => 'home.quests.daily_xp',
    };
    return Semantics(
      checked: quest.completed,
      child: AppCard(
        padding: EdgeInsets.all(AppSpacing.md.w),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: quest.completed
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                quest.completed ? Icons.check_rounded : Icons.bolt_rounded,
                color: quest.completed
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(l10n.translate(titleKey))),
                      Text('${quest.current}/${quest.target}'),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  AppProgress(
                    value: quest.target == 0 ? 0 : quest.current / quest.target,
                    height: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePlanSection extends StatelessWidget {
  const HomePlanSection({
    required this.quests,
    required this.dueReviews,
    super.key,
  });

  final List<QuestData> quests;
  final int dueReviews;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final lessonDone = quests
        .where((quest) => quest.code == 'daily_lesson')
        .any((quest) => quest.completed);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(
                  l10n.translate('home.plan.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          _PlanRow(
            icon: lessonDone ? Icons.check_circle : Icons.circle_outlined,
            label: l10n.translate('home.plan.daily_lesson'),
            trailing: lessonDone ? l10n.translate('home.plan.done') : null,
          ),
          _PlanRow(
            icon: Icons.style_outlined,
            label: l10n.translate('home.plan.review_cards', [dueReviews]),
            trailing: '$dueReviews',
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(child: Text(label)),
        if (trailing != null) Text(trailing!),
      ],
    ),
  );
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _QuickActionCard(
          key: const Key('home_review_action'),
          icon: Icons.school_outlined,
          title: context.watch<AppLanguageProvider>().translate(
            'home.quick_actions.need_review',
          ),
          subtitle: context.watch<AppLanguageProvider>().translate(
            'home.quick_actions.vocab_count',
            [dashboard.dueReviews],
          ),
          onTap: () => context.go('/review'),
        ),
        _QuickActionCard(
          key: const Key('home_ai_practice'),
          icon: Icons.record_voice_over_outlined,
          title: context.watch<AppLanguageProvider>().translate(
            'home.quick_actions.practice_pronunciation',
          ),
          subtitle: context.watch<AppLanguageProvider>().translate(
            'home.quick_actions.practice_desc',
          ),
          onTap: () => context.push('/practice'),
        ),
      ];
      if (constraints.maxWidth < 340) {
        return Column(
          children: [
            cards.first,
            SizedBox(height: AppSpacing.sm.h),
            cards.last,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards.first),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(child: cards.last),
        ],
      );
    },
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
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl.r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 152),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              SizedBox(height: AppSpacing.md.h),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({required this.dashboard, super.key});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.translate('home.recent.title')),
        SizedBox(height: AppSpacing.sm.h),
        if (dashboard.recentActivity.isEmpty)
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(l10n.translate('home.recent.empty')),
            ),
          )
        else
          for (
            var index = 0;
            index < dashboard.recentActivity.length;
            index++
          ) ...[
            _ActivityRow(activity: dashboard.recentActivity[index]),
            if (index != dashboard.recentActivity.length - 1)
              SizedBox(height: AppSpacing.sm.h),
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
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.menu_book_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
          Icon(
            Icons.check_circle_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
