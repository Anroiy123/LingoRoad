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
  int? _questionSessionGeneration;

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
    if (questionVm != null &&
        _questionSessionGeneration != questionVm.sessionGeneration) {
      _questionSessionGeneration = questionVm.sessionGeneration;
      _scheduled = false;
      _schedule();
    }
    final vocabStatus = switch (vm.state) {
      ReviewState.initial || ReviewState.loading => _ReviewCardStatus.loading,
      ReviewState.error => _ReviewCardStatus.error,
      ReviewState.empty || ReviewState.complete when vm.remaining == 0 =>
        _ReviewCardStatus.completed,
      _ => _ReviewCardStatus.active,
    };
    final questionStatus = switch (questionVm?.state) {
      null ||
      QuestionReviewState.initial ||
      QuestionReviewState.loading => _ReviewCardStatus.loading,
      QuestionReviewState.error => _ReviewCardStatus.error,
      QuestionReviewState.empty || QuestionReviewState.complete
          when (questionVm?.dueCount ?? 0) == 0 =>
        _ReviewCardStatus.completed,
      _ => _ReviewCardStatus.active,
    };
    final vocabCountText = _statusText(
      l,
      vocabStatus,
      dueKey: 'review.selection.vocab_due_badge',
      remaining: vm.remaining,
    );
    final questionCountText = _statusText(
      l,
      questionStatus,
      dueKey: 'review.selection.question_due_badge',
      remaining: questionVm?.dueCount ?? 0,
    );
    final scheme = Theme.of(context).colorScheme;

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
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          l.translate('review.selection.title'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
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
                  badgeText: questionCountText,
                  status: questionStatus,
                  title: l.translate('review.selection.question_title'),
                  description: l.translate('review.selection.question_desc'),
                  onTap: questionStatus == _ReviewCardStatus.error
                      ? questionVm!.retry
                      : () async {
                          final routerContext = context;
                          await routerContext.push('/question-review');
                          if (!routerContext.mounted) return;
                          final freshQuestionVm = routerContext
                              .read<QuestionReviewViewModel?>();
                          if (freshQuestionVm != null) {
                            await freshQuestionVm.load();
                          }
                        },
                ),
                SizedBox(height: AppSpacing.lg.h),
                _ReviewSelectionCard(
                  key: const Key('vocabulary_review_card'),
                  icon: Icons.menu_book_outlined,
                  badgeText: vocabCountText,
                  status: vocabStatus,
                  title: l.translate('review.selection.vocab_title'),
                  description: l.translate('review.selection.vocab_desc'),
                  onTap: vocabStatus == _ReviewCardStatus.error
                      ? vm.load
                      : () => context.push('/vocabulary-review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReviewCardStatus { loading, error, active, completed }

String _statusText(
  AppLanguageProvider language,
  _ReviewCardStatus status, {
  required String dueKey,
  required int remaining,
}) => switch (status) {
  _ReviewCardStatus.loading => language.translate(
    'review.selection.loading_badge',
  ),
  _ReviewCardStatus.error => language.translate(
    'review.selection.unavailable_badge',
  ),
  _ReviewCardStatus.completed => language.translate(
    'review.selection.completed_badge',
  ),
  _ReviewCardStatus.active => language.translate(dueKey, [remaining]),
};

class _ReviewSelectionCard extends StatelessWidget {
  const _ReviewSelectionCard({
    required this.icon,
    required this.badgeText,
    required this.status,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String badgeText;
  final _ReviewCardStatus status;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final completed = status == _ReviewCardStatus.completed;
    final hasError = status == _ReviewCardStatus.error;
    final statusColor = completed
        ? (isDark
              ? AppColorsDark.successForeground
              : AppColors.successForeground)
        : hasError
        ? scheme.error
        : status == _ReviewCardStatus.loading
        ? scheme.onSurfaceVariant
        : scheme.primary;
    final statusBackground = completed
        ? (isDark ? AppColorsDark.successSoft : AppColors.successSoft)
        : hasError
        ? scheme.errorContainer
        : status == _ReviewCardStatus.loading
        ? scheme.surfaceContainerHigh
        : scheme.primaryContainer;
    final cardColor = completed
        ? (isDark ? AppColorsDark.successSurface : AppColors.successSurface)
        : scheme.surface;
    final cardBorderColor = completed
        ? (isDark ? AppColorsDark.success : AppColors.success)
        : scheme.outlineVariant;
    final shadowColor = isDark ? AppColorsDark.shadow : AppColors.shadow;
    final statusIcon = switch (status) {
      _ReviewCardStatus.completed => Icons.check_circle_rounded,
      _ReviewCardStatus.error => Icons.error_outline_rounded,
      _ReviewCardStatus.loading => Icons.sync_rounded,
      _ReviewCardStatus.active => Icons.schedule_rounded,
    };

    return Semantics(
      button: true,
      liveRegion: true,
      label: '$title, $badgeText',
      onTap: onTap,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.xl.r),
            border: Border.all(color: cardBorderColor, width: 1.w),
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
              borderRadius: BorderRadius.circular(AppRadius.xl.r),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 144),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.margin.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius: BorderRadius.circular(
                                AppRadius.lg.r,
                              ),
                            ),
                            child: Icon(icon, color: statusColor, size: 28.sp),
                          ),
                          SizedBox(width: AppSpacing.md.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 20.sp,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.xxs.h),
                                Text(
                                  description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14.sp,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Icon(
                            status == _ReviewCardStatus.error
                                ? Icons.refresh_rounded
                                : Icons.chevron_right_rounded,
                            color: statusColor,
                            size: 24.sp,
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: AppSpacing.xxs.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackground,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 16.sp),
                            SizedBox(width: AppSpacing.xxs.w),
                            Flexible(
                              child: Text(
                                badgeText,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
