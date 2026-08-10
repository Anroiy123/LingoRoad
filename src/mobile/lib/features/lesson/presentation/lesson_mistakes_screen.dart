import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LessonMistakesScreen extends StatelessWidget {
  const LessonMistakesScreen({required this.mistakes, super.key});

  final List<MistakeRecord> mistakes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('lesson.mistakes.title'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin.w,
              AppSpacing.lg.h,
              AppSpacing.margin.w,
              180.h, // Space for bottom action bar
            ),
            children: [
              _buildSummaryHeader(context, l10n, mistakes.length),
              SizedBox(height: AppSpacing.md.h),
              if (mistakes.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl.w),
                    child: Text(
                      l10n.translate('lesson.mistakes.empty'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                )
              else
                ...mistakes.map((mistake) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                    child: _buildDynamicMistakeCard(context, mistake, l10n),
                  );
                }),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomActionBar(l10n: l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(
      BuildContext context, AppLanguageProvider l10n, int mistakeCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5.w),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColorsDark.errorSoft : AppColors.errorSoft,
            ),
            child: const Icon(
              Icons.error_rounded,
              color: AppColors.error,
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('lesson.mistakes.completed'),
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                ),
                Text(
                  l10n.translate('lesson.mistakes.summary', [mistakeCount]),
                  style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicMistakeCard(
      BuildContext context, MistakeRecord mistake, AppLanguageProvider l10n) {
    String tag = 'Ôn tập';
    if (mistake.exercise.type == 'mcq') {
      tag = l10n.translate('lesson.mistakes.tag_mcq');
    } else if (mistake.exercise.type == 'reorder') {
      tag = l10n.translate('lesson.mistakes.tag_reorder');
    } else {
      tag = l10n.translate('lesson.mistakes.tag_text');
    }

    return _MistakeCardLayout(
      tag: tag,
      hasAudio: false,
      title: mistake.exercise.stem,
      children: [
        _IncorrectAnswer(
          label: l10n.translate('lesson.mistakes.your_answer'),
          text: mistake.userAnswer.isEmpty ? '(Trống)' : mistake.userAnswer,
        ),
        SizedBox(height: AppSpacing.sm.h),
        _CorrectAnswer(
          label: l10n.translate('lesson.mistakes.correct_answer'),
          text: mistake.feedback.correctAnswer,
        ),
        if (mistake.feedback.explanationVi?.isNotEmpty == true) ...[
          SizedBox(height: AppSpacing.md.h),
          _Explanation(
            label: l10n.translate('lesson.mistakes.explanation'),
            text: mistake.feedback.explanationVi!,
          ),
        ]
      ],
    );
  }
}

class _MistakeCardLayout extends StatelessWidget {
  const _MistakeCardLayout({
    required this.tag,
    required this.hasAudio,
    required this.title,
    required this.children,
  });

  final String tag;
  final bool hasAudio;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColorsDark.shadow : AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.surfaceHigh : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xl.r),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (hasAudio)
                InkWell(
                  onTap: () {},
                  child: Icon(Icons.volume_up_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: AppSpacing.md.h),
          ...children,
        ],
      ),
    );
  }
}

class _IncorrectAnswer extends StatelessWidget {
  const _IncorrectAnswer({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColorsDark.errorSoft : AppColors.errorSoft;
    final titleColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D);
    final textColor = isDark ? Colors.white : const Color(0xFF7F1D1D);

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close_rounded, color: titleColor, size: 20.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: titleColor, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectAnswer extends StatelessWidget {
  const _CorrectAnswer({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColorsDark.successSoft : AppColors.successSoft;
    final titleColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF14532D);
    final textColor = isDark ? Colors.white : const Color(0xFF14532D);

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded,
              color: titleColor, size: 20.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: titleColor, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(top: AppSpacing.md.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: isDark
                    ? AppColorsDark.surfaceHigh
                    : AppColors.surfaceHigh)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.normal,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.margin.w, vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: (isDark ? AppColorsDark.surface : AppColors.surface)
            .withValues(alpha: 0.9),
        border: Border(
            top: BorderSide(
                color: isDark
                    ? AppColorsDark.surfaceHigh
                    : AppColors.surfaceHigh)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg.r),
                  ),
                  elevation: 4,
                  shadowColor:
                      AppColors.primaryContainer.withValues(alpha: 0.4),
                ),
                onPressed: () => context.go('/home'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.translate('lesson.mistakes.back_home'),
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
            SizedBox(height: AppSpacing.sm.h),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(
                l10n.currentLanguage == AppLanguage.vi
                    ? 'Bỏ qua lúc này'
                    : 'Skip for now',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
