import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/data/mock_repository.dart';
import 'package:lingoroad_mobile/models/models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = const MockRepository();
  late final Future<List<DailyQuest>> _quests = _repository.quests();
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return AppPage(
      children: [
        const LingoHeader(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('home.welcome', ['Hùng']), style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.translate('home.subtitle'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              MetricRow(label: l10n.translate('home.metrics.daily_goal'), value: 60),
              const SizedBox(height: AppSpacing.sm),
              MetricRow(label: l10n.translate('home.metrics.weekly_goal'), value: 80),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.translate('home.today_lesson.tag'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.translate('home.today_lesson.title'),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.translate('home.today_lesson.description'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () => setState(() => _started = true),
                  icon: Icon(
                    _started
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(_started ? l10n.translate('home.today_lesson.ready') : l10n.translate('home.today_lesson.start')),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(l10n.translate('home.quests_title')),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<DailyQuest>>(
              future: _quests,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return loadingView();
                return Column(
                  children: [
                    for (final quest in snapshot.data!) ...[
                      _QuestTile(quest),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.translate('home.plan.title'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _PlanRow(
                icon: Icons.check_circle_outline,
                title: l10n.translate('home.plan.daily_lesson'),
                trailing: l10n.translate('home.plan.done'),
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              _PlanRow(
                icon: Icons.school_outlined,
                title: l10n.translate('home.plan.review_cards', [10]),
                trailing: '4/10',
                color: AppColors.primary,
                progress: .4,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AppCard(
                color: AppColors.errorSoft,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _QuickCard(
                  icon: Icons.school_outlined,
                  title: l10n.translate('home.quick_actions.need_review'),
                  subtitle: l10n.translate('home.quick_actions.vocab_count', [12]),
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _QuickCard(
                  icon: Icons.headphones_rounded,
                  title: l10n.translate('home.quick_actions.practice_pronunciation'),
                  subtitle: l10n.translate('home.quick_actions.practice_desc'),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(l10n.translate('home.recent.title')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.surfaceDisabled,
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('home.recent.order_food'),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          l10n.translate('home.recent.completed_yesterday'),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile(this.quest);
  final DailyQuest quest;
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final icon = switch (quest.icon) {
      'headphones' => Icons.headphones_rounded,
      'check' => Icons.check_rounded,
      _ => Icons.bolt_rounded,
    };
    return Opacity(
      opacity: quest.done ? .72 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor:
                  quest.done ? AppColors.successSoft : AppColors.primaryFixed,
              child: Icon(
                icon,
                color: quest.done ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate(quest.title, [quest.target]),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        '${quest.current}/${quest.target}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: quest.done
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppProgress(
                    value: quest.current / quest.target,
                    height: 5,
                    color: quest.done ? AppColors.success : AppColors.primary,
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

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.color,
    this.progress,
  });
  final IconData icon;
  final String title;
  final String trailing;
  final Color color;
  final double? progress;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  AppProgress(value: progress!, height: 5),
                ],
              ],
            ),
          ),
          Text(
            trailing,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ],
        ),
      );
}
