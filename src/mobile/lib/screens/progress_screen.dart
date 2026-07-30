import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/data/mock_repository.dart';
import 'package:lingoroad_mobile/models/models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _skills = const MockRepository().skills;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.margin,
              AppSpacing.md,
              AppSpacing.margin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LingoHeader(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.translate('progress.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.translate('progress.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  indicatorColor: AppColors.cta,
                  dividerColor: AppColors.surfaceHigh,
                  tabs: [
                    Tab(text: l10n.translate('progress.tabs.overview')),
                    Tab(text: l10n.translate('progress.tabs.skills')),
                    Tab(text: l10n.translate('progress.tabs.achievements')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _overview(l10n),
                _skillTab(l10n),
                _achievements(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(AppLanguageProvider l10n) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.lg,
          AppSpacing.margin,
          112,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                Text(
                  'B1',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                ),
                Text(
                  l10n.translate('progress.overview.current_level'),
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _stat(Icons.star_outline, '1.240', l10n.translate('progress.overview.total_xp'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _stat(
                  Icons.local_fire_department_outlined,
                  '12',
                  l10n.translate('progress.overview.streak'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: _stat(Icons.assignment_outlined, '2/3', l10n.translate('progress.overview.quests'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _stat(Icons.emoji_events_outlined, '12/48', l10n.translate('progress.overview.badges')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.cefr_journey')),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      ['A1', 'A2', 'B1', 'B2'].asMap().entries.map((entry) {
                    final done = entry.key <= 2;
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor:
                              done ? AppColors.primary : AppColors.surfaceHigh,
                          child: done
                              ? Text(
                                  entry.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.key == 2 ? l10n.translate('progress.overview.current') : entry.value,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.mastery')),
                const SizedBox(height: AppSpacing.md),
                const SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CustomPaint(painter: _MasteryChartPainter()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.strengths')),
                const SizedBox(height: AppSpacing.md),
                ..._skills.take(3).map((item) => _skill(item, l10n)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.improvements')),
                const SizedBox(height: AppSpacing.md),
                ..._skills.skip(3).map((item) => _skill(item, l10n)),
              ],
            ),
          ),
        ],
      );

  Widget _skillTab(AppLanguageProvider l10n) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.lg,
          AppSpacing.margin,
          112,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.skills_analysis.title')),
                const SizedBox(height: AppSpacing.lg),
                ..._skills.map((item) => _skill(item, l10n)),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.translate('progress.skills_analysis.suggestion'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _achievements(AppLanguageProvider l10n) => GridView.count(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.lg,
          AppSpacing.margin,
          112,
        ),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        children: [
          _Badge(Icons.local_fire_department_outlined, l10n.translate('progress.badges_list.streak_12')),
          _Badge(Icons.workspace_premium_outlined, l10n.translate('progress.badges_list.traveler')),
          _Badge(Icons.emoji_events_outlined, l10n.translate('progress.badges_list.xp_1000')),
          _Badge(Icons.menu_book_outlined, l10n.translate('progress.badges_list.studious')),
        ],
      );

  Widget _stat(IconData icon, String value, String label) => AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(
          height: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(
                label,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
  Widget _skill(SkillProgress item, AppLanguageProvider l10n) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: MetricRow(label: l10n.translate(item.label), value: item.value),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: AppColors.primaryFixed,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      );
}

class _MasteryChartPainter extends CustomPainter {
  const _MasteryChartPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.surfaceHigh
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final points = <Offset>[
      for (var i = 0; i < 6; i++)
        Offset(size.width * i / 5, size.height * (0.75 - i * .1)),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = AppColors.surface);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = AppColors.cta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
