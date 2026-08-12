import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:lingoroad_mobile/widgets/exercise_answer_input.dart';
import 'package:provider/provider.dart';

/// Learner-facing flow for questions that are due for review.
///
/// The state and data all come from [QuestionReviewViewModel], which keeps the
/// existing API retry and idempotency rules intact. This widget deliberately
/// only owns presentation and focus management.
class QuestionReviewScreen extends StatefulWidget {
  const QuestionReviewScreen({super.key});

  @override
  State<QuestionReviewScreen> createState() => _QuestionReviewScreenState();
}

class _QuestionReviewScreenState extends State<QuestionReviewScreen> {
  final FocusNode _feedbackFocus = FocusNode(debugLabel: 'review feedback');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuestionReviewViewModel>().load();
    });
  }

  @override
  void dispose() {
    _feedbackFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<QuestionReviewViewModel>();
    final l10n = context.watch<AppLanguageProvider>();
    if (viewModel.state == QuestionReviewState.feedback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _feedbackFocus.requestFocus();
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.translate('common.back'),
          onPressed: _backToReview,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(l10n.translate('question_review.title')),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.margin.w,
                AppSpacing.md.h,
                AppSpacing.margin.w,
                AppSpacing.lg.h,
              ),
              child: _content(context, viewModel, l10n),
            ),
          ),
        ),
      ),
    );
  }

  void _backToReview() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/review');
    }
  }

  Widget _content(
    BuildContext context,
    QuestionReviewViewModel viewModel,
    AppLanguageProvider l10n,
  ) {
    switch (viewModel.state) {
      case QuestionReviewState.initial:
      case QuestionReviewState.loading:
        return const Center(
          key: Key('question_review_loading'),
          child: CircularProgressIndicator(),
        );
      case QuestionReviewState.empty:
        return _ReviewStateCard(
          key: const Key('question_review_empty'),
          icon: Icons.inbox_outlined,
          title: l10n.translate('question_review.empty.title'),
          message: l10n.translate('question_review.empty.message'),
          action: _returnAction(l10n),
        );
      case QuestionReviewState.complete:
        return _ReviewStateCard(
          key: const Key('question_review_complete'),
          icon: Icons.celebration_rounded,
          title: l10n.translate('question_review.complete.title'),
          message: l10n.translate('question_review.complete.summary', [
            viewModel.correctCount,
            viewModel.incorrectCount,
            viewModel.xp,
            viewModel.coins,
          ]),
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewModel.hasMoreDue)
                FilledButton(
                  key: const Key('question_review_more'),
                  onPressed: viewModel.load,
                  child: Text(l10n.translate('question_review.complete.more')),
                ),
              if (viewModel.hasMoreDue) SizedBox(height: AppSpacing.sm.h),
              _returnAction(l10n),
            ],
          ),
        );
      case QuestionReviewState.error:
        return _ReviewStateCard(
          key: const Key('question_review_error'),
          icon: Icons.cloud_off_rounded,
          title: l10n.translate('question_review.error.title'),
          message: l10n.translate(
            viewModel.hasRetainedAnswerError
                ? 'question_review.error.operation_message'
                : 'question_review.error.load_message',
          ),
          action: FilledButton.icon(
            key: const Key('question_review_retry'),
            onPressed: viewModel.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.translate('common.retry')),
          ),
        );
      case QuestionReviewState.feedback:
        return _feedback(viewModel, l10n);
      case QuestionReviewState.ready:
      case QuestionReviewState.checking:
      case QuestionReviewState.grading:
        return _question(viewModel, l10n);
    }
  }

  Widget _question(
    QuestionReviewViewModel viewModel,
    AppLanguageProvider l10n,
  ) {
    final item = viewModel.current!;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SingleChildScrollView(
        key: const Key('question_review_question_scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressHeader(
              key: const Key('question_review_progress_header'),
              text: l10n.translate('question_review.progress', [
                viewModel.completed + 1,
                viewModel.remaining,
              ]),
              value: viewModel.remaining == 0
                  ? 1
                  : viewModel.completed /
                        (viewModel.completed + viewModel.remaining),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Semantics(
              header: true,
              child: Container(
                key: const Key('question_review_prompt'),
                padding: EdgeInsets.all(AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xl.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate(_instructionKey(item.type)),
                      key: const Key('question_review_instruction'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      item.stem,
                      key: const Key('question_review_stem'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: ExerciseAnswerInput(
                key: ValueKey(item.id),
                type: item.type,
                options: item.options,
                answer: viewModel.answer,
                enabled: viewModel.state == QuestionReviewState.ready,
                onAnswerChanged: viewModel.setAnswer,
                onSubmit: viewModel.check,
                textFieldKey: const Key('question_review_text_answer'),
                submitKey: const Key('question_review_check'),
                submitLabel: l10n.translate('question_review.check'),
                hintText: l10n.translate('question_review.answer_hint'),
                showOptionLabels: item.type == 'mcq',
                selectedSemanticsLabel: l10n.translate(
                  'lesson.answer_state.selected',
                ),
                correctSemanticsLabel: l10n.translate(
                  'lesson.answer_state.correct',
                ),
                incorrectSemanticsLabel: l10n.translate(
                  'lesson.answer_state.incorrect',
                ),
              ),
            ),
            if (viewModel.isBusy) ...[
              SizedBox(height: AppSpacing.md.h),
              Semantics(
                liveRegion: true,
                label: l10n.translate('question_review.status.checking'),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _instructionKey(String type) => switch (type) {
    'mcq' => 'lesson.instruction.choose_answer',
    'reorder' => 'lesson.instruction.arrange_words',
    _ => 'lesson.instruction.enter_answer',
  };

  Widget _feedback(
    QuestionReviewViewModel viewModel,
    AppLanguageProvider l10n,
  ) {
    final feedback = viewModel.feedback!;
    final item = viewModel.current!;
    final scheme = Theme.of(context).colorScheme;
    final isCorrect = feedback.correct;
    final icon = isCorrect ? Icons.check_circle_rounded : Icons.info_rounded;
    final title = l10n.translate(
      isCorrect
          ? 'question_review.feedback.correct'
          : 'question_review.feedback.wrong',
    );

    return Semantics(
      key: const Key('question_review_feedback'),
      container: true,
      liveRegion: true,
      label: l10n.translate('question_review.feedback.semantics'),
      child: Focus(
        focusNode: _feedbackFocus,
        child: SingleChildScrollView(
          key: const Key('question_review_feedback_scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                color: isCorrect
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                borderColor: isCorrect ? scheme.primary : scheme.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          color: isCorrect ? scheme.primary : scheme.error,
                        ),
                        SizedBox(width: AppSpacing.xs.w),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (!isCorrect) ...[
                      SizedBox(height: AppSpacing.sm.h),
                      Text(
                        l10n.translate('question_review.feedback.answer', [
                          feedback.correctAnswer,
                        ]),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if (feedback.explanationVi?.isNotEmpty == true) ...[
                      SizedBox(height: AppSpacing.xs.h),
                      Text(feedback.explanationVi!),
                    ],
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              ExerciseAnswerInput(
                key: ValueKey('feedback-${item.id}'),
                type: item.type,
                options: item.options,
                answer: viewModel.answer,
                enabled: false,
                onAnswerChanged: (_) {},
                onSubmit: (_) {},
                textFieldKey: const Key('question_review_feedback_answer'),
                submitKey: const Key('question_review_feedback_submit'),
                submitLabel: l10n.translate('question_review.check'),
                hintText: l10n.translate('question_review.answer_hint'),
                feedbackCorrect: feedback.correct,
                correctAnswer: feedback.correctAnswer,
                selectedSemanticsLabel: l10n.translate(
                  'lesson.answer_state.selected',
                ),
                correctSemanticsLabel: l10n.translate(
                  'lesson.answer_state.correct',
                ),
                incorrectSemanticsLabel: l10n.translate(
                  'lesson.answer_state.incorrect',
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),
              if (isCorrect)
                _RatingChoices(viewModel: viewModel, l10n: l10n)
              else
                FilledButton(
                  key: const Key('question_review_next'),
                  onPressed: viewModel.next,
                  child: Text(l10n.translate('question_review.next')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _returnAction(AppLanguageProvider l10n) => OutlinedButton(
    key: const Key('question_review_return'),
    onPressed: _backToReview,
    child: Text(l10n.translate('question_review.complete.return')),
  );
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({super.key, required this.text, required this.value});

  final String text;
  final double value;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: text,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: Theme.of(context).textTheme.labelLarge),
        SizedBox(height: AppSpacing.sm.h),
        AppProgress(
          key: const Key('question_review_progress_bar'),
          value: value,
          height: 6,
        ),
      ],
    ),
  );
}

class _RatingChoices extends StatelessWidget {
  const _RatingChoices({required this.viewModel, required this.l10n});

  final QuestionReviewViewModel viewModel;
  final AppLanguageProvider l10n;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: Wrap(
      spacing: AppSpacing.sm.w,
      runSpacing: AppSpacing.sm.h,
      children: [
        for (final rating in [2, 3, 4])
          SizedBox(
            height: 48.h,
            child: FilledButton(
              key: Key('question_review_rating_$rating'),
              onPressed: viewModel.isBusy
                  ? null
                  : () => viewModel.grade(rating),
              child: Text(l10n.translate('question_review.rating.$rating')),
            ),
          ),
      ],
    ),
  );
}

class _ReviewStateCard extends StatelessWidget {
  const _ReviewStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48.sp, color: Theme.of(context).colorScheme.primary),
          SizedBox(height: AppSpacing.md.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: AppSpacing.lg.h),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    ),
  );
}
