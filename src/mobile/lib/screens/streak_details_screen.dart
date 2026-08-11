import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class StreakDetailsScreen extends StatefulWidget {
  const StreakDetailsScreen({super.key});

  @override
  State<StreakDetailsScreen> createState() => _StreakDetailsScreenState();
}

class _StreakDetailsScreenState extends State<StreakDetailsScreen> {
  late DateTime _currentMonth;
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<DashboardViewModel>();
    if (!_loadScheduled && viewModel.state == DashboardState.initial) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) viewModel.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final viewModel = context.watch<DashboardViewModel>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(l10n.translate('streak.title')),
      ),
      body: switch (viewModel.state) {
        DashboardState.initial || DashboardState.loading => Center(
          key: const Key('streak_loading'),
          child: loadingView(),
        ),
        DashboardState.error => Center(
          child: AppCard(
            key: const Key('streak_error'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.error),
                SizedBox(height: AppSpacing.sm.h),
                Text(l10n.translate('home.error')),
                SizedBox(height: AppSpacing.md.h),
                FilledButton.icon(
                  key: const Key('streak_retry'),
                  onPressed: viewModel.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.translate('common.retry')),
                ),
              ],
            ),
          ),
        ),
        DashboardState.ready => _content(l10n, viewModel.dashboard!),
      },
    );
  }

  Widget _content(AppLanguageProvider l10n, DashboardData dashboard) {
    return RefreshIndicator(
      onRefresh: context.read<DashboardViewModel>().load,
      child: AppPage(
        children: [
          AppCard(
            child: Column(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 64.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  l10n.translate('streak.days_count', [
                    dashboard.currentStreak,
                  ]),
                  key: const Key('streak_current'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(l10n.translate('streak.current_streak')),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  label: l10n.translate('streak.record_title'),
                  value: l10n.translate('streak.record_value', [
                    dashboard.longestStreak,
                  ]),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _StatCard(
                  icon: Icons.bolt_rounded,
                  label: 'XP',
                  value: '${dashboard.xp}',
                ),
              ),
            ],
          ),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                        );
                      }),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _monthName(l10n),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                        );
                      }),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md.h),
                _Calendar(
                  month: _currentMonth,
                  activeDates: dashboard.activeDates,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(AppLanguageProvider l10n) {
    const keys = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return '${l10n.translate('streak.months.${keys[_currentMonth.month - 1]}')} '
        '${_currentMonth.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        SizedBox(height: AppSpacing.sm.h),
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.activeDates});

  final DateTime month;
  final List<DateTime> activeDates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final active = activeDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    final days = <int?>[
      ...List<int?>.filled(
        DateTime(month.year, month.month, 1).weekday - 1,
        null,
      ),
      ...List<int>.generate(
        DateTime(month.year, month.month + 1, 0).day,
        (index) => index + 1,
      ),
    ];
    while (days.length % 7 != 0) {
      days.add(null);
    }
    final weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return Column(
      children: [
        Row(
          children: weekdayKeys
              .map(
                (key) => Expanded(
                  child: Text(
                    l10n.translate('streak.weekdays.$key'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(growable: false),
        ),
        SizedBox(height: AppSpacing.sm.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            if (day == null) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final isActive = active.contains(date);
            return Semantics(
              label: '$day/${month.month}/${month.year}',
              value: isActive ? l10n.translate('streak.legend.learned') : null,
              child: Container(
                margin: EdgeInsets.all(3.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.primaryFixed : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
