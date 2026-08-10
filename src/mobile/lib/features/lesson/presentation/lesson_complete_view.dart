import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_mistakes_screen.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LessonCompleteView extends StatelessWidget {
  const LessonCompleteView({required this.completion, super.key});

  final LessonCompletion completion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final accuracy = completion.totalAnswers > 0
        ? ((completion.correctAnswers / completion.totalAnswers) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          l10n.translate('lesson.complete.header'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.margin.w),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _HeroIllustration(l10n: l10n),
                        SizedBox(height: AppSpacing.xl.h),
                        _StatsGrid(
                          accuracy: accuracy,
                          reviewCards: completion.reviewCardsCreated,
                          l10n: l10n,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _BottomActionBar(l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.l10n});
  final AppLanguageProvider l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 160.w,
          height: 160.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryFixed,
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              width: 4.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.surface,
              size: 64.sp,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        Text(
          l10n.translate('lesson.complete.title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          l10n.translate('lesson.complete.subtitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.accuracy,
    required this.reviewCards,
    required this.l10n,
  });

  final int accuracy;
  final int reviewCards;
  final AppLanguageProvider l10n;

  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: _StatCard(
        icon: icon,
        iconColor: color,
        value: value,
        label: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              context,
              l10n.translate('lesson.complete.accuracy'),
              '$accuracy%',
              Icons.flag_rounded,
              AppColors.primaryContainer,
            ),
            SizedBox(width: AppSpacing.md.w),
            _buildStatCard(
              context,
              l10n.translate('lesson.complete.review_cards_label'),
              '$reviewCards',
              Icons.style_rounded,
              AppColors.primaryContainer,
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm.h),
        Container(
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColorsDark.surface
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            border: Border.all(
                color: Theme.of(context).colorScheme.primary, width: 1.5.w),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm.w),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md.r),
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('lesson.complete.excellent'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          Text(
                            l10n.translate('lesson.complete.results'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColorsDark.surface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary, width: 1.5.w),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28.sp),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.l10n});
  final AppLanguageProvider l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg.h, top: AppSpacing.md.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                    side: BorderSide(
                        color: AppColors.primaryContainer, width: 2.w),
                    foregroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg.r),
                    ),
                  ),
                  icon: const Icon(Icons.history_edu_rounded),
                  label: Text(
                    l10n.translate('lesson.complete.review_mistakes'),
                    style:
                        TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final mistakes = context.read<LessonViewModel>().mistakes;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonMistakesScreen(mistakes: mistakes),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('lesson_back_home'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg.r),
                ),
                elevation: 4,
                shadowColor: AppColors.primaryContainer.withValues(alpha: 0.4),
              ),
              onPressed: () => context.go('/home'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.translate('lesson.complete.back_home'),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  const Icon(Icons.home_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
