import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({this.active = true, super.key});
  final bool active;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _scheduled = false;
      _schedule();
    }
  }

  void _schedule() {
    if (!widget.active || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<ReviewViewModel>();
      final questionVm = context.read<QuestionReviewViewModel?>();
      if (vm.state == ReviewState.initial ||
          vm.state == ReviewState.complete ||
          vm.state == ReviewState.empty) {
        vm.load();
      }
      if (questionVm != null &&
          (questionVm.state == QuestionReviewState.initial ||
              questionVm.state == QuestionReviewState.empty ||
              questionVm.state == QuestionReviewState.complete)) {
        questionVm.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final vm = context.watch<ReviewViewModel>();
    final l = context.watch<AppLanguageProvider>();

    final questionVm = context.watch<QuestionReviewViewModel?>();
    final vocabCountText = vm.state == ReviewState.loading
        ? '...'
        : l.translate('review.selection.vocab_due_badge', [vm.remaining]);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        title: Text(
          l.translate('review.selection.title'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.margin.w,
                AppSpacing.lg.h,
                AppSpacing.margin.w,
                112.h,
              ),
              children: [
                _ReviewSelectionCard(
                  key: const Key('question_review_card'),
                  icon: Icons.quiz_outlined,
                  badgeText: questionVm?.state == QuestionReviewState.loading
                      ? '...'
                      : l.translate('review.selection.question_due_badge', [questionVm?.dueCount ?? 0]),
                  badgeIcon: Icons.schedule_rounded,
                  badgeTextColor: AppColors.primary,
                  badgeBgColor: AppColors.primaryFixed,
                  title: l.translate('review.selection.question_title'),
                  description: l.translate('review.selection.question_desc'),
                  onTap: () async {
                    final routerContext = context;
                    await routerContext.push('/question-review');
                    if (!routerContext.mounted) return;
                    final freshQuestionVm = routerContext.read<QuestionReviewViewModel?>();
                    if (freshQuestionVm != null) await freshQuestionVm.load();
                  },
                ),
                SizedBox(height: AppSpacing.lg.h),
                _ReviewSelectionCard(
                  key: const Key('vocabulary_review_card'),
                  icon: Icons.menu_book_outlined,
                  badgeText: vocabCountText,
                  badgeIcon: Icons.schedule_rounded,
                  badgeTextColor: AppColors.primary,
                  badgeBgColor: AppColors.primaryFixed,
                  title: l.translate('review.selection.vocab_title'),
                  description: l.translate('review.selection.vocab_desc'),
                  onTap: () {
                    context.push('/vocabulary-review');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSelectionCard extends StatelessWidget {
  const _ReviewSelectionCard({
    required this.icon,
    required this.badgeText,
    required this.badgeIcon,
    required this.badgeTextColor,
    required this.badgeBgColor,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String badgeText;
  final IconData badgeIcon;
  final Color badgeTextColor;
  final Color badgeBgColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.scaffoldBackgroundColor;
    final cardBorderColor = theme.colorScheme.primary;
    final shadowColor = isDark ? AppColorsDark.shadow : AppColors.shadow;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: cardBorderColor, width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: 32.sp,
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: AppSpacing.xxs.h,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badgeIcon,
                              color: badgeTextColor,
                              size: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                badgeText,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: badgeTextColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: AppSpacing.xxs.h),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
