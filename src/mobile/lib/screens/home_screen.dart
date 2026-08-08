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
        children: [
          const LingoHeader(streak: null),
          loadingView(),
        ],
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
    final quests = viewModel.quests;
    final completedQuests = quests.where((q) => q.completed).length;
    final totalQuests = quests.length;

    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: AppPage(
        children: [
          // 1. Custom Header Row
          _buildHeaderRow(context, dashboard),

          // 2. Greeting Section with dynamic metrics
          _buildGreetingSection(context, l10n, dashboard),

          // 3. Activity Overview Card
          _buildActivityOverviewCard(context, l10n, dashboard),

          // 4. Hero Action Card (Next Lesson)
          _buildHeroActionCard(context, l10n, dashboard),

          // 5. Missions Grid
          _buildMissionsGrid(
              context, l10n, quests, completedQuests, totalQuests),

          // 6. Quick Access Bento Grid
          _buildBentoGrid(context, l10n, dashboard),

          // 7. Recent Activity (Horizontal Scroll)
          _buildRecentActivity(context, l10n, dashboard),
        ],
      ),
    );
  }

  // 1. Custom Header Row
  Widget _buildHeaderRow(BuildContext context, DashboardData dashboard) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999.r),
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAAHCAfZ8cDnJ6LemoKZG946vU9X-2YZRGH3RczRavY2fPknjHJiyD0JgJanvGWGx2uPsDq0x3a2dqVF86z77FF_pvBlI53L5Co1jP1BP3qVNpy5owL_VNvEL6mC2_sv4gP71D13KMVuCrMEBYpMKAo61oh88R2Tsxb--Vi7A9JTym33doYKVA5He_aIqqW7n80eNXjW-89mqggBmpLmaCzV3kte78DdG5WrY6qpTmRkI96XgjmL2o5',
            width: 36.w,
            height: 36.w,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.surfaceLow,
              child: Icon(
                Icons.person_outline_rounded,
                size: 20.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm.w),
        Flexible(
          child: Text(
            'lingRoad',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 24.sp,
                  letterSpacing: -0.5,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        // CEFR badge
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: AppColors.surfaceHigh),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
          child: Text(
            dashboard.currentCefr,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
          ),
        ),
        SizedBox(width: AppSpacing.xs.w),
        // Streak count
        InkWell(
          key: const Key('header_streak'),
          borderRadius: BorderRadius.circular(999.r),
          onTap: () => context.push('/streak-details'),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999.r),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 20.sp,
                  color: AppColors.cta,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${dashboard.currentStreak}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.cta,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Greeting Section
  Widget _buildGreetingSection(
      BuildContext context, AppLanguageProvider l10n, DashboardData dashboard) {
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
        SizedBox(height: 4.h),
        Text(
          l10n.translate('home.subtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 8.h,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.translate('home.level_summary', [
                dashboard.currentCefr,
                dashboard.targetCefr ?? '—',
                (dashboard.mastery * 100).round(),
              ]),
              key: const Key('home_level_summary'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 16.sp, color: AppColors.warning),
                SizedBox(width: 2.w),
                Text(
                  '${dashboard.xp}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                ),
                SizedBox(width: 12.w),
                Icon(Icons.monetization_on_rounded,
                    size: 16.sp, color: Colors.amber),
                SizedBox(width: 2.w),
                Text(
                  '${dashboard.coins}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // 3. Activity Overview Card
  Widget _buildActivityOverviewCard(
      BuildContext context, AppLanguageProvider l10n, DashboardData dashboard) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: AppColors.primaryContainer,
                size: 20.sp,
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(
                  l10n.currentLanguage == AppLanguage.vi
                      ? 'TỔNG QUAN HOẠT ĐỘNG'
                      : 'ACTIVITY OVERVIEW',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Row(
            children: [
              // Daily goal progress radial
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl.r),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 6.r,
                              color: AppColors.surfaceHigh,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: CircularProgressIndicator(
                              value: dashboard.dailyProgress.clamp(0.0, 1.0),
                              strokeWidth: 6.r,
                              color: AppColors.primaryContainer,
                              backgroundColor: Colors.transparent,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${(dashboard.dailyProgress * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Text(
                        l10n.translate('home.metrics.daily_goal'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              // Weekly goal progress radial
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl.r),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 6.r,
                              color: AppColors.surfaceHigh,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: CircularProgressIndicator(
                              value: dashboard.weeklyProgress.clamp(0.0, 1.0),
                              strokeWidth: 6.r,
                              color: AppColors.success,
                              backgroundColor: Colors.transparent,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${(dashboard.weeklyProgress * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Text(
                        l10n.translate('home.metrics.weekly_goal'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Hero Action Card (Next Lesson)
  Widget _buildHeroActionCard(
      BuildContext context, AppLanguageProvider l10n, DashboardData dashboard) {
    final lesson = dashboard.todayLesson;
    if (lesson == null) {
      return Container(
        key: const Key('home_today_lesson'),
        padding: EdgeInsets.all(AppSpacing.lg.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(AppRadius.xl.r),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            l10n.translate('home.today_lesson.empty'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      key: const Key('home_today_lesson'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.cta,
            AppColors.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
            child: Text(
              l10n.translate('home.today_lesson.tag').toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          // Title
          Text(
            l10n.currentLanguage == AppLanguage.vi
                ? lesson.titleVi
                : lesson.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22.sp,
                ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          // Subtitle
          Text(
            l10n.translate('home.today_lesson.details', [
              lesson.cefr,
              lesson.itemCount,
              dashboard.dailyGoalMinutes,
            ]),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('home_start_lesson'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                elevation: 2,
              ),
              onPressed: () => context.push('/lesson/${lesson.id}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                l10n.translate('home.today_lesson.start'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Missions Grid
  Widget _buildMissionsGrid(BuildContext context, AppLanguageProvider l10n,
      List<QuestData> quests, int completedQuests, int totalQuests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.translate('home.quests_title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Text(
              l10n.translate(
                  'home.quests_completed', [completedQuests, totalQuests]),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm.h),
        Column(
          children: [
            // Draw pairs
            for (int i = 0;
                i < quests.length - (quests.length % 2);
                i += 2) ...[
              Row(
                children: [
                  Expanded(child: _buildQuestCard(context, l10n, quests[i])),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                      child: _buildQuestCard(context, l10n, quests[i + 1])),
                ],
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
            // Draw the odd item if any
            if (quests.length % 2 != 0)
              _buildQuestCard(context, l10n, quests.last, fullWidth: true),
          ],
        )
      ],
    );
  }

  Widget _buildQuestCard(
      BuildContext context, AppLanguageProvider l10n, QuestData quest,
      {bool fullWidth = false}) {
    final titleKey = switch (quest.code) {
      'daily_lesson' => 'home.quests.daily_lesson',
      'daily_review' => 'home.quests.daily_review',
      _ => 'home.quests.daily_xp',
    };
    final IconData icon = switch (quest.code) {
      'daily_lesson' => Icons.bolt_rounded,
      'daily_review' => Icons.headphones_rounded,
      _ => Icons.check_rounded,
    };

    return Opacity(
      opacity: quest.completed ? 0.6 : 1.0,
      child: AppCard(
        padding: EdgeInsets.all(AppSpacing.md.w),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: quest.completed
                          ? AppColors.primaryContainer.withValues(alpha: 0.2)
                          : AppColors.surfaceLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: quest.completed
                            ? AppColors.primaryContainer.withValues(alpha: 0.3)
                            : AppColors.surfaceHigh,
                      ),
                    ),
                    child: Icon(
                      quest.completed ? Icons.check_rounded : icon,
                      size: 20.sp,
                      color: quest.completed
                          ? AppColors.primaryContainer
                          : AppColors.text,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                l10n.translate(titleKey),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: quest.completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ),
                            Text(
                              '${quest.current}/${quest.target}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        AppProgress(
                          value: quest.target == 0
                              ? 0.0
                              : quest.current / quest.target,
                          height: 4,
                          color: AppColors.primaryContainer,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: quest.completed
                              ? AppColors.primaryContainer
                                  .withValues(alpha: 0.2)
                              : AppColors.surfaceLow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: quest.completed
                                ? AppColors.primaryContainer
                                    .withValues(alpha: 0.3)
                                : AppColors.surfaceHigh,
                          ),
                        ),
                        child: Icon(
                          quest.completed ? Icons.check_rounded : icon,
                          size: 20.sp,
                          color: quest.completed
                              ? AppColors.primaryContainer
                              : AppColors.text,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs.w,
                            vertical: AppSpacing.xxs.h),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryContainer.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md.r),
                        ),
                        child: Text(
                          '${quest.current}/${quest.target}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.sp,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Text(
                    l10n.translate(titleKey),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  AppProgress(
                    value:
                        quest.target == 0 ? 0.0 : quest.current / quest.target,
                    height: 4,
                    color: AppColors.primaryContainer,
                  ),
                ],
              ),
      ),
    );
  }

  // 6. Quick Access Bento Grid
  Widget _buildBentoGrid(
      BuildContext context, AppLanguageProvider l10n, DashboardData dashboard) {
    return Row(
      children: [
        // Review Card
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.xl.r),
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                ),
              ),
              padding: EdgeInsets.all(AppSpacing.lg.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: AppColors.primaryContainer,
                          size: 24.sp,
                        ),
                      ),
                      if (dashboard.dueReviews > 0)
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${dashboard.dueReviews}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('home.quick_actions.need_review'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        l10n.translate('home.quick_actions.vocab_count', [
                          dashboard.dueReviews,
                        ]),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        // Pronunciation Card (AI Practice)
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: InkWell(
              key: const Key('home_ai_practice'),
              onTap: () => context.push('/practice'),
              borderRadius: BorderRadius.circular(AppRadius.xl.r),
              child: AppCard(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        color: AppColors.text,
                        size: 24.sp,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate(
                              'home.quick_actions.practice_pronunciation'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          l10n.translate('home.quick_actions.practice_desc'),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 7. Recent Activity (Horizontal Scroll)
  Widget _buildRecentActivity(
      BuildContext context, AppLanguageProvider l10n, DashboardData dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('home.recent.title'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        if (dashboard.recentActivity.isEmpty)
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(
                l10n.translate('home.recent.empty'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final activity in dashboard.recentActivity) ...[
                  Container(
                    width: 280.w,
                    margin: EdgeInsets.only(right: AppSpacing.md.w),
                    child: AppCard(
                      padding: EdgeInsets.all(AppSpacing.md.w),
                      child: Row(
                        children: [
                          Container(
                            width: 44.w,
                            height: 44.w,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceLow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.textSecondary,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.currentLanguage == AppLanguage.vi
                                      ? activity.titleVi
                                      : activity.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _formatActivityDate(
                                      context, activity.completedAt, l10n),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 10.sp,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 22.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _formatActivityDate(
      BuildContext context, DateTime date, AppLanguageProvider l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compare = DateTime(date.year, date.month, date.day);

    final isVi = l10n.currentLanguage == AppLanguage.vi;

    if (compare == today) {
      return isVi ? 'Hoàn thành • Hôm nay' : 'Completed • Today';
    } else if (compare == yesterday) {
      return isVi ? 'Hoàn thành • Hôm qua' : 'Completed • Yesterday';
    } else {
      final daysDiff = today.difference(compare).inDays;
      if (daysDiff > 0 && daysDiff < 7) {
        return isVi
            ? 'Hoàn thành • $daysDiff ngày trước'
            : 'Completed • $daysDiff days ago';
      }
      return isVi
          ? 'Hoàn thành • ${date.day}/${date.month}'
          : 'Completed • ${date.day}/${date.month}';
    }
  }
}
