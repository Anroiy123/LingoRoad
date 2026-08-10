import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_complete_view.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/features/dictionary/data/dictionary_repository.dart';
import 'package:lingoroad_mobile/features/dictionary/data/saved_word_repository.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _answerController = TextEditingController();
  final _selectedWords = <String>[];
  String? _exerciseId;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LessonViewModel>().load(widget.lessonId);
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LessonViewModel>();
    final l10n = context.watch<AppLanguageProvider>();
    final current = viewModel.current;
    if (current?.id != _exerciseId) {
      _exerciseId = current?.id;
      _answerController.clear();
      _selectedWords.clear();
    }
    if (viewModel.state == LessonState.completed) {
      _scheduleRefresh();
      return LessonCompleteView(
        key: const Key('lesson_completed'),
        completion: viewModel.completion!,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_localizedTitle(l10n, viewModel.attempt)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: _content(context, l10n, viewModel),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLanguageProvider l10n,
    LessonViewModel viewModel,
  ) {
    if (viewModel.state == LessonState.initial ||
        viewModel.state == LessonState.loading ||
        viewModel.state == LessonState.completing) {
      return Center(
        key: const Key('lesson_loading'),
        child: loadingView(),
      );
    }
    if (viewModel.state == LessonState.error) {
      return _StateCard(
        key: const Key('lesson_error'),
        icon: Icons.cloud_off_rounded,
        title: l10n.translate('lesson.error.title'),
        message: l10n.translate('lesson.error.message'),
        action: FilledButton.icon(
          key: const Key('lesson_retry'),
          onPressed: viewModel.attempt == null
              ? viewModel.retryLoad
              : viewModel.retryComplete,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.translate('common.retry')),
        ),
      );
    }

    final exercise = viewModel.current;
    if (exercise == null) {
      return _StateCard(
        icon: Icons.inbox_rounded,
        title: l10n.translate('lesson.empty.title'),
        message: l10n.translate('lesson.empty.message'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${viewModel.currentNumber}/${viewModel.total}'),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: AppProgress(value: viewModel.progress)),
          ],
        ),
        SizedBox(height: AppSpacing.xl.h),
        Wrap(
          key: const Key('lesson_stem'),
          children: exercise.stem.split(' ').map((word) {
            final cleanWord =
                word.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
            return GestureDetector(
              onLongPress: () => _showDictionaryBottomSheet(
                  context, l10n, cleanWord, viewModel.attempt?.skillCode ?? ''),
              child: Padding(
                padding: EdgeInsets.only(right: 6.w, bottom: 4.h),
                child: Text(
                  word.replaceAll('*', ''),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: AppSpacing.lg.h),
        Expanded(
          child: SingleChildScrollView(
            child: viewModel.state == LessonState.feedback
                ? _feedback(context, l10n, viewModel)
                : _answer(context, l10n, viewModel, exercise),
          ),
        ),
      ],
    );
  }

  Widget _answer(
    BuildContext context,
    AppLanguageProvider l10n,
    LessonViewModel viewModel,
    LessonExercise exercise,
  ) {
    final disabled = viewModel.state == LessonState.submitting;
    final children = <Widget>[];
    if (exercise.type == 'mcq') {
      children.addAll(exercise.options.map(
        (option) => Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
          child: OutlinedButton(
            key: Key('lesson_option_$option'),
            onPressed: disabled ? null : () => viewModel.submit(option),
            child: Text(option),
          ),
        ),
      ));
    } else if (exercise.type == 'reorder') {
      children.add(Wrap(
        spacing: AppSpacing.xs.w,
        runSpacing: AppSpacing.xs.h,
        children: exercise.options.map((word) {
          final selected = _selectedWords.contains(word);
          return FilterChip(
            label: Text(word),
            selected: selected,
            onSelected: disabled
                ? null
                : (value) => setState(() {
                      if (value) {
                        _selectedWords.add(word);
                      } else {
                        _selectedWords.remove(word);
                      }
                    }),
          );
        }).toList(),
      ));
      children.add(SizedBox(height: AppSpacing.md.h));
      children.add(Text(_selectedWords.join(' ')));
    } else {
      children.add(TextField(
        key: const Key('lesson_text_answer'),
        controller: _answerController,
        enabled: !disabled,
        decoration: InputDecoration(
          hintText: l10n.translate('lesson.answer_hint'),
        ),
        onSubmitted: disabled ? null : viewModel.submit,
      ));
    }
    if (viewModel.errorCode != null) {
      children.addAll([
        SizedBox(height: AppSpacing.sm.h),
        Text(
          l10n.translate('lesson.submit_error'),
          key: const Key('lesson_submit_error'),
          style: const TextStyle(color: AppColors.error),
        ),
      ]);
    }
    if (exercise.type != 'mcq') {
      children.addAll([
        SizedBox(height: AppSpacing.lg.h),
        FilledButton(
          key: const Key('lesson_submit'),
          onPressed: disabled
              ? null
              : () => viewModel.submit(
                    exercise.type == 'reorder'
                        ? _selectedWords.join(' ')
                        : _answerController.text,
                  ),
          child: disabled
              ? const CircularProgressIndicator()
              : Text(l10n.translate('lesson.submit')),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _feedback(
    BuildContext context,
    AppLanguageProvider l10n,
    LessonViewModel viewModel,
  ) {
    final feedback = viewModel.feedback!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = feedback.correct
        ? (isDark ? AppColorsDark.successSoft : AppColors.successSoft)
        : (isDark ? AppColorsDark.errorSoft : AppColors.errorSoft);
    final titleColor = feedback.correct
        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF14532D))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D));
    final textColor = feedback.correct
        ? (isDark ? Colors.white : const Color(0xFF14532D))
        : (isDark ? Colors.white : const Color(0xFF7F1D1D));

    return AppCard(
      color: cardBg,
      borderColor: feedback.correct ? AppColors.success : AppColors.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feedback.correct
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,
                color: titleColor,
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(
                  l10n.translate(
                    feedback.correct
                        ? 'lesson.feedback.correct'
                        : 'lesson.feedback.wrong',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          if (!feedback.correct)
            Text(
              l10n.translate(
                  'lesson.feedback.answer', [feedback.correctAnswer]),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (feedback.explanationVi?.isNotEmpty == true) ...[
            SizedBox(height: AppSpacing.xs.h),
            Text(
              feedback.explanationVi!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                  ),
            ),
          ],
          SizedBox(height: AppSpacing.lg.h),
          FilledButton(
            key: const Key('lesson_next'),
            onPressed: viewModel.next,
            child: Text(l10n.translate('lesson.next')),
          ),
        ],
      ),
    );
  }

  String _localizedTitle(AppLanguageProvider l10n, LessonAttempt? attempt) {
    if (attempt == null) return l10n.translate('lesson.title');
    return l10n.currentLanguage == AppLanguage.vi
        ? attempt.titleVi
        : attempt.title;
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardViewModel?>()?.load();
      context.read<LearningPathViewModel?>()?.load();
      context.read<ReviewViewModel?>()?.load();
      context.read<ProgressViewModel?>()?.load();
    });
  }

  void _showDictionaryBottomSheet(BuildContext context,
      AppLanguageProvider l10n, String word, String skillCode) {
    if (word.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _DictionarySheet(word: word, skillCode: skillCode),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48.sp, color: AppColors.primary),
              SizedBox(height: AppSpacing.md.h),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: AppSpacing.xs.h),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                SizedBox(height: AppSpacing.lg.h),
                action!,
              ],
            ],
          ),
        ),
      );
}

class _DictionarySheet extends StatefulWidget {
  const _DictionarySheet({required this.word, required this.skillCode});
  final String word;
  final String skillCode;

  @override
  State<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<_DictionarySheet> {
  String? _definition;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _wordSaved = false;

  @override
  void initState() {
    super.initState();
    _loadDefinition();
  }

  Future<void> _loadDefinition() async {
    try {
      final repo = context.read<DictionaryRepository>();
      final def = await repo.lookup(widget.word);
      if (mounted) {
        setState(() {
          _definition = def;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveWord() async {
    if (_definition == null) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<SavedWordRepository>();
      await repo.save(
          widget.skillCode, widget.word, _definition!.replaceAll('*', ''));
      if (mounted) {
        setState(() {
          _saving = false;
          _wordSaved = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.word,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: AppSpacing.md.h),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(l10n.translate('lesson.error.message'),
                style: const TextStyle(color: AppColors.error))
          else ...[
            Text((_definition ?? '').replaceAll('*', ''),
                key: const Key('dictionary_definition'),
                style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: AppSpacing.lg.h),
            if (_wordSaved)
              Row(
                key: const Key('dictionary_word_saved'),
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: AppSpacing.sm.w),
                  Text(l10n.translate('dictionary.word_saved')),
                ],
              )
            else
              FilledButton.icon(
                key: const Key('dictionary_save_word'),
                onPressed: _saving ? null : _saveWord,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.translate('dictionary.save_word')),
              ),
          ],
        ],
      ),
    );
  }
}
