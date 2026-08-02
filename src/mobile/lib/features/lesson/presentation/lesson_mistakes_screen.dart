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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
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

  Widget _buildSummaryHeader(BuildContext context, AppLanguageProvider l10n, int mistakeCount) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.errorSoft,
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                ),
                Text(
                  l10n.translate('lesson.mistakes.summary', [mistakeCount]),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicMistakeCard(BuildContext context, MistakeRecord mistake, AppLanguageProvider l10n) {
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
    this.imagePlaceholder = false,
  });

  final String tag;
  final bool hasAudio;
  final String title;
  final bool imagePlaceholder;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
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
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xl.r),
                ),
                child: Text(
                  tag,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              if (hasAudio)
                InkWell(
                  onTap: () {},
                  child: const Icon(Icons.volume_up_rounded, color: AppColors.textSecondary),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          if (imagePlaceholder) ...[
            Row(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    image: const DecorationImage(
                      image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuA387M_70gv3CRGZxCR8-m-5mOVCk76kX75S7sRamYhMu2Rukkf_g0r9TPsglpxi_3mBAKzT98__v3dzxaIGZIOH3C9ys9gd48a_jVTAMQjKoSU65dLsD15Pyuct7LIxm4XfVevHQ_osRF-bpiww9zcWuuvkzhIdQGIS6Ii4TeH4WMn7sRnq2wkl8jkucaeNOzSwUgWm9rixtIp4zEPynEGo91DuUr2PphVIJ085UGIJ3UMpPhCC0eT'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.text,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md.h),
          ] else ...[
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: AppSpacing.md.h),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _IncorrectAnswer extends StatelessWidget {
  const _IncorrectAnswer({required this.label, required this.text, this.isBold = false});
  final String label;
  final String text;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close_rounded, color: AppColors.error, size: 20.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.error),
                ),
                SizedBox(height: 2.h),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
  const _CorrectAnswer({required this.label, required this.text, this.isBold = false});
  final String label;
  final String text;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.success),
                ),
                SizedBox(height: 2.h),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
    return Container(
      padding: EdgeInsets.only(top: AppSpacing.md.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.margin.w, vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.border)),
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
                  shadowColor: AppColors.primaryContainer.withValues(alpha: 0.4),
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
                l10n.currentLanguage == AppLanguage.vi ? 'Bỏ qua lúc này' : 'Skip for now',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
