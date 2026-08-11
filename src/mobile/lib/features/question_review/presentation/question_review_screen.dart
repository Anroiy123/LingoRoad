import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/widgets/exercise_answer_input.dart';
import 'package:provider/provider.dart';

class QuestionReviewScreen extends StatefulWidget {
  const QuestionReviewScreen({super.key});

  @override
  State<QuestionReviewScreen> createState() => _QuestionReviewScreenState();
}

class _QuestionReviewScreenState extends State<QuestionReviewScreen> {
  final FocusNode _feedbackFocus = FocusNode();

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
    final vm = context.watch<QuestionReviewViewModel>();
    final l = context.watch<AppLanguageProvider>();
    if (vm.state == QuestionReviewState.feedback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _feedbackFocus.requestFocus();
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.translate('question_review.title'))),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: _content(context, vm, l))),
    );
  }

  Widget _content(BuildContext context, QuestionReviewViewModel vm, AppLanguageProvider l) {
    if (vm.state == QuestionReviewState.initial || vm.state == QuestionReviewState.loading) {
      return const Center(key: Key('question_review_loading'), child: CircularProgressIndicator());
    }
    if (vm.state == QuestionReviewState.empty) {
      return _StateView(key: const Key('question_review_empty'), title: l.translate('question_review.empty.title'), message: l.translate('question_review.empty.message'), action: _returnAction(context, l));
    }
    if (vm.state == QuestionReviewState.complete) {
      return _StateView(
        key: const Key('question_review_complete'),
        title: l.translate('question_review.complete.title'),
        message: l.translate('question_review.complete.summary', [vm.correctCount, vm.incorrectCount, vm.xp, vm.coins]),
        action: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (vm.dueCount > vm.completed) FilledButton(onPressed: vm.load, child: Text(l.translate('question_review.complete.more'))),
          OutlinedButton(onPressed: () => context.go('/home'), child: Text(l.translate('question_review.complete.return'))),
        ]),
      );
    }
    if (vm.state == QuestionReviewState.error) {
      return _StateView(
        key: const Key('question_review_error'),
        title: l.translate('question_review.error.title'),
        message: l.translate(vm.hasRetainedAnswerError
            ? 'question_review.error.operation_message'
            : 'question_review.error.load_message'),
        action: FilledButton(key: const Key('question_review_retry'), onPressed: vm.retry, child: Text(l.translate('common.retry'))),
      );
    }
    final item = vm.current!;
    if (vm.state == QuestionReviewState.feedback) return _feedback(vm, l);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.translate('question_review.progress', [vm.completed + 1, vm.remaining])),
      const SizedBox(height: 24),
      Text(item.stem, key: const Key('question_review_stem'), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      ExerciseAnswerInput(
        key: ValueKey(item.id),
        type: item.type,
        options: item.options,
        answer: vm.answer,
        enabled: vm.state == QuestionReviewState.ready,
        onAnswerChanged: vm.setAnswer,
        onSubmit: vm.check,
        textFieldKey: const Key('question_review_text_answer'),
        submitKey: const Key('question_review_check'),
        submitLabel: l.translate('question_review.check'),
        hintText: l.translate('question_review.answer_hint'),
      ),
      if (vm.state == QuestionReviewState.checking) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
    ]);
  }

  Widget _feedback(QuestionReviewViewModel vm, AppLanguageProvider l) {
    final feedback = vm.feedback!;
    return Semantics(
      key: const Key('question_review_feedback'),
      label: l.translate('question_review.feedback.semantics'),
      liveRegion: true,
      child: Focus(
        focusNode: _feedbackFocus,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(feedback.correct ? l.translate('question_review.feedback.correct') : l.translate('question_review.feedback.wrong'), style: Theme.of(context).textTheme.headlineSmall),
          if (!feedback.correct) Text(l.translate('question_review.feedback.answer', [feedback.correctAnswer])),
          if (feedback.explanationVi?.isNotEmpty == true) Text(feedback.explanationVi!),
          const SizedBox(height: 24),
          if (feedback.correct)
            Wrap(spacing: 8, children: [
              for (final rating in [2, 3, 4])
                FilledButton(key: Key('question_review_rating_$rating'), onPressed: vm.isBusy ? null : () => vm.grade(rating), child: Text(l.translate('question_review.rating.$rating'))),
            ])
          else
            FilledButton(key: const Key('question_review_next'), onPressed: vm.next, child: Text(l.translate('question_review.next'))),
        ]),
      ),
    );
  }

  Widget _returnAction(BuildContext context, AppLanguageProvider l) => OutlinedButton(onPressed: () => context.go('/home'), child: Text(l.translate('question_review.complete.return')));
}

class _StateView extends StatelessWidget {
  const _StateView({required this.title, required this.message, required this.action, super.key});
  final String title;
  final String message;
  final Widget action;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 20), action]));
}
