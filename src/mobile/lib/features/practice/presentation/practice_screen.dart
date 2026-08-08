import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/practice/domain/practice_models.dart';
import 'package:lingoroad_mobile/features/practice/presentation/practice_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class AiPracticeScreen extends StatefulWidget {
  const AiPracticeScreen({super.key});

  @override
  State<AiPracticeScreen> createState() => _AiPracticeScreenState();
}

class _AiPracticeScreenState extends State<AiPracticeScreen> {
  final _question = TextEditingController();
  final _task = TextEditingController(text: 'Describe your hometown.');
  final _essay = TextEditingController();
  final _speakingPrompt =
      TextEditingController(text: 'I have lived here for two years.');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AiPracticeViewModel>().loadHistory();
    });
  }

  @override
  void dispose() {
    _question.dispose();
    _task.dispose();
    _essay.dispose();
    _speakingPrompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'practice.title')),
          bottom: TabBar(tabs: [
            Tab(text: _tr(context, 'practice.tabs.advisor')),
            Tab(text: _tr(context, 'practice.tabs.writing')),
            Tab(text: _tr(context, 'practice.tabs.speaking')),
          ]),
        ),
        body: TabBarView(children: [
          _advisor(context),
          _writing(context),
          _speaking(context),
        ]),
      ),
    );
  }

  Widget _advisor(BuildContext context) {
    final vm = context.watch<AiPracticeViewModel>();
    return _Panel(children: [
      Text(_tr(context, 'practice.advisor.title'),
          style: Theme.of(context).textTheme.headlineSmall),
      TextField(
        key: const Key('advisor_question'),
        controller: _question,
        minLines: 3,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: _tr(context, 'practice.advisor.hint'),
          border: const OutlineInputBorder(),
        ),
      ),
      FilledButton.icon(
        key: const Key('advisor_submit'),
        onPressed: vm.advisorStatus == PracticeStatus.loading
            ? null
            : () => vm.askAdvisor(_question.text),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(_tr(context, 'practice.advisor.submit')),
      ),
      if (vm.advisorStatus == PracticeStatus.loading) const _Loading(),
      if (vm.advisorStatus == PracticeStatus.error)
        _ErrorCard(code: vm.advisorError, onRetry: vm.retryAdvisor),
      if (vm.advisorAnswer != null)
        AppCard(
          key: const Key('advisor_answer'),
          child: SelectableText(vm.advisorAnswer!),
        ),
    ]);
  }

  Widget _writing(BuildContext context) {
    final vm = context.watch<AiPracticeViewModel>();
    return _Panel(children: [
      Text(_tr(context, 'practice.writing.title'),
          style: Theme.of(context).textTheme.headlineSmall),
      TextField(
        key: const Key('writing_task'),
        controller: _task,
        decoration: InputDecoration(
          labelText: _tr(context, 'practice.writing.task'),
          border: const OutlineInputBorder(),
        ),
      ),
      TextField(
        key: const Key('writing_essay'),
        controller: _essay,
        minLines: 7,
        maxLines: 14,
        decoration: InputDecoration(
          labelText: _tr(context, 'practice.writing.essay'),
          border: const OutlineInputBorder(),
        ),
      ),
      FilledButton.icon(
        key: const Key('writing_submit'),
        onPressed: vm.writingStatus == PracticeStatus.loading
            ? null
            : () => vm.evaluateWriting(_task.text, _essay.text),
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(_tr(context, 'practice.writing.submit')),
      ),
      if (vm.writingStatus == PracticeStatus.loading) const _Loading(),
      if (vm.writingStatus == PracticeStatus.error)
        _ErrorCard(code: vm.writingError, onRetry: vm.retryWriting),
      if (vm.writingResult case final result?) _WritingResult(result: result),
    ]);
  }

  Widget _speaking(BuildContext context) {
    final vm = context.watch<AiPracticeViewModel>();
    return _Panel(children: [
      Text(_tr(context, 'practice.speaking.title'),
          style: Theme.of(context).textTheme.headlineSmall),
      Text(_tr(context, 'practice.speaking.privacy')),
      TextField(
        key: const Key('speaking_prompt'),
        controller: _speakingPrompt,
        enabled: !vm.recording && vm.speakingStatus != PracticeStatus.loading,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: _tr(context, 'practice.speaking.prompt'),
          border: const OutlineInputBorder(),
        ),
      ),
      FilledButton.icon(
        key: Key(vm.recording ? 'speaking_stop' : 'speaking_record'),
        style: vm.recording
            ? FilledButton.styleFrom(backgroundColor: AppColors.error)
            : null,
        onPressed: vm.speakingStatus == PracticeStatus.loading
            ? null
            : vm.recording
                ? vm.stopAndScore
                : () => vm.startRecording(_speakingPrompt.text),
        icon: Icon(vm.recording ? Icons.stop_rounded : Icons.mic_rounded),
        label: Text(vm.recording
            ? _tr(
                context, 'practice.speaking.stop_score', [vm.recordingSeconds])
            : _tr(context, 'practice.speaking.start')),
      ),
      if (vm.recording)
        TextButton(
          key: const Key('speaking_cancel'),
          onPressed: vm.cancelRecording,
          child: Text(_tr(context, 'practice.speaking.cancel')),
        ),
      if (vm.speakingStatus == PracticeStatus.loading) const _Loading(),
      if (vm.speakingStatus == PracticeStatus.error)
        _ErrorCard(
          code: vm.speakingError,
          onRetry: vm.canRetrySpeaking
              ? vm.retrySpeaking
              : () => vm.startRecording(_speakingPrompt.text),
        ),
      if (vm.speakingScore case final score?) _SpeakingResult(score: score),
      SectionTitle(_tr(context, 'practice.speaking.history')),
      if (vm.historyStatus == PracticeStatus.loading) const _Loading(),
      if (vm.historyStatus == PracticeStatus.error)
        _ErrorCard(code: vm.historyError, onRetry: vm.loadHistory),
      if (vm.historyStatus == PracticeStatus.success && vm.history.isEmpty)
        AppCard(child: Text(_tr(context, 'practice.speaking.empty'))),
      for (final item in vm.history) _HistoryCard(item: item),
    ]);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.all(AppSpacing.margin.w),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: AppSpacing.md.h),
          ]
        ],
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(key: Key('practice_loading')));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.code, required this.onRetry});
  final String? code;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
        color: AppColors.errorSoft,
        child: Row(children: [
          Expanded(
              child: Text(
                  '${_tr(context, 'practice.error.request_failed')}: ${code ?? 'unknown'}')),
          TextButton(
            key: const Key('practice_retry'),
            onPressed: onRetry,
            child: Text(_tr(context, 'common.retry')),
          ),
        ]),
      );
}

class _WritingResult extends StatelessWidget {
  const _WritingResult({required this.result});
  final WritingResult result;

  @override
  Widget build(BuildContext context) => AppCard(
        key: const Key('writing_result'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.overallVi,
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: AppSpacing.sm.h),
          Text('Task ${result.scores.taskAchievement.toStringAsFixed(1)} · '
              'Coherence ${result.scores.coherenceCohesion.toStringAsFixed(1)} · '
              'Lexical ${result.scores.lexicalResource.toStringAsFixed(1)} · '
              'Grammar ${result.scores.grammaticalAccuracy.toStringAsFixed(1)}'),
          for (final feedback in result.feedback) ...[
            const Divider(),
            Text(feedback.sentence),
            Text('${feedback.issue} → ${feedback.suggestion}'),
          ]
        ]),
      );
}

class _SpeakingResult extends StatelessWidget {
  const _SpeakingResult({required this.score});
  final SpeakingScore score;

  @override
  Widget build(BuildContext context) => AppCard(
        key: const Key('speaking_result'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_tr(context, 'practice.speaking.overall')}: '
              '${(score.total * 100).round()}%'),
          Text(
              '${_tr(context, 'practice.speaking.transcript')}: ${score.transcript}'),
          Text(score.feedbackVi),
          Text(
              '${score.durationSeconds.toStringAsFixed(1)}s · ${score.modelVersion}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});
  final SpeakingHistoryItem item;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.promptText, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${(item.total * 100).round()}% · ${item.modelVersion}'),
        ]),
      );
}

String _tr(BuildContext context, String key, [List<dynamic>? args]) {
  try {
    return context.watch<AppLanguageProvider>().translate(key, args);
  } catch (_) {
    return key;
  }
}
