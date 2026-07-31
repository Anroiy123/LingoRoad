import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/data/mock_repository.dart';
import 'package:lingoroad_mobile/models/models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin.w,
              AppSpacing.md.h,
              AppSpacing.margin.w,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LingoHeader(),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate('progress.title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28.sp),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  l10n.translate('progress.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
                SizedBox(height: AppSpacing.md.h),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  indicatorColor: AppColors.cta,
                  dividerColor: AppColors.surfaceHigh,
                  labelStyle: TextStyle(fontSize: 14.sp),
                  unselectedLabelStyle: TextStyle(fontSize: 14.sp),
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.margin.w,
          AppSpacing.lg.h,
          AppSpacing.margin.w,
          112.h,
        ),
        children: [
          AppCard(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
            child: Column(
              children: [
                Icon(Icons.school_outlined, color: AppColors.primary, size: 24.sp),
                Text(
                  'B1',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontSize: 22.sp,
                      ),
                ),
                Text(
                  l10n.translate('progress.overview.current_level'),
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: [
              Expanded(child: _stat(Icons.star_outline, '1.240', l10n.translate('progress.overview.total_xp'))),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _stat(
                  Icons.local_fire_department_outlined,
                  '12',
                  l10n.translate('progress.overview.streak'),
                  onTap: () => context.push('/streak-details'),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: [
              Expanded(
                  child: _stat(Icons.assignment_outlined, '2/3', l10n.translate('progress.overview.quests'))),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _stat(Icons.emoji_events_outlined, '12/48', l10n.translate('progress.overview.badges')),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.cefr_journey')),
                SizedBox(height: AppSpacing.lg.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      ['A1', 'A2', 'B1', 'B2'].asMap().entries.map((entry) {
                    final done = entry.key <= 2;
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 13.r,
                          backgroundColor:
                              done ? AppColors.primary : AppColors.surfaceHigh,
                          child: done
                              ? Text(
                                  entry.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                      ),
                                )
                              : null,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          entry.key == 2 ? l10n.translate('progress.overview.current') : entry.value,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.sp),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.mastery')),
                SizedBox(height: AppSpacing.md.h),
                SizedBox(
                  height: 190.h,
                  width: double.infinity,
                  child: const CustomPaint(painter: _MasteryChartPainter()),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.strengths')),
                SizedBox(height: AppSpacing.md.h),
                ..._skills.take(3).map((item) => _skill(item, l10n)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.overview.improvements')),
                SizedBox(height: AppSpacing.md.h),
                ..._skills.skip(3).map((item) => _skill(item, l10n)),
              ],
            ),
          ),
        ],
      );

  Widget _skillTab(AppLanguageProvider l10n) => ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.margin.w,
          AppSpacing.lg.h,
          AppSpacing.margin.w,
          112.h,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(l10n.translate('progress.skills_analysis.title')),
                SizedBox(height: AppSpacing.lg.h),
                ..._skills.map((item) => _skill(item, l10n)),
                SizedBox(height: AppSpacing.md.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.lg.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primary, size: 24.sp),
                      SizedBox(width: AppSpacing.sm.w),
                      Expanded(
                        child: Text(
                          l10n.translate('progress.skills_analysis.suggestion'),
                          style: TextStyle(fontSize: 14.sp),
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.margin.w,
          AppSpacing.lg.h,
          AppSpacing.margin.w,
          112.h,
        ),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md.h,
        crossAxisSpacing: AppSpacing.md.w,
        children: [
          _Badge(Icons.local_fire_department_outlined, l10n.translate('progress.badges_list.streak_12')),
          _Badge(Icons.workspace_premium_outlined, l10n.translate('progress.badges_list.traveler')),
          _Badge(Icons.emoji_events_outlined, l10n.translate('progress.badges_list.xp_1000')),
          _Badge(Icons.menu_book_outlined, l10n.translate('progress.badges_list.studious')),
        ],
      );

  Widget _stat(IconData icon, String value, String label, {VoidCallback? onTap}) {
    final card = AppCard(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: AppSpacing.sm.h),
      child: SizedBox(
        height: 78.h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19.sp, color: AppColors.primary),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20.sp)),
            Text(
              label,
              style: Theme.of(
                context,
              )
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
            ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
  Widget _skill(SkillProgress item, AppLanguageProvider l10n) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md.h),
        child: MetricRow(label: l10n.translate(item.label), value: item.value),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 29.r,
              backgroundColor: AppColors.primaryFixed,
              child: Icon(icon, color: AppColors.primary, size: 28.sp),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14.sp),
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
      ..strokeWidth = 1.w;
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
        ..strokeWidth = 2.5.w,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4.r, Paint()..color = AppColors.surface);
      canvas.drawCircle(
        point,
        4.r,
        Paint()
          ..color = AppColors.cta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.w,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
