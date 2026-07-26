import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_audio_player.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';

class PlacementQuestionScreen extends StatefulWidget {
  const PlacementQuestionScreen({
    required this.viewModel,
    this.audioPlayer,
    super.key,
  });

  final PlacementViewModel viewModel;
  final PlacementAudioPlayer? audioPlayer;

  @override
  State<PlacementQuestionScreen> createState() =>
      _PlacementQuestionScreenState();
}

class _PlacementQuestionScreenState extends State<PlacementQuestionScreen> {
  PlacementAudioPlayer? _audioPlayer;
  late final bool _ownsAudioPlayer;
  bool _isLoadingAudio = false;
  String? _audioError;

  PlacementViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _ownsAudioPlayer = widget.audioPlayer == null;
    _audioPlayer = widget.audioPlayer;
  }

  @override
  void dispose() {
    if (_ownsAudioPlayer && _audioPlayer != null) {
      unawaited(_audioPlayer!.dispose());
    }
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    if (_isLoadingAudio) {
      return;
    }
    setState(() {
      _isLoadingAudio = true;
      _audioError = null;
    });
    try {
      final player = _audioPlayer ??= DevicePlacementAudioPlayer();
      await player.play(url);
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioError = 'Không thể phát âm thanh. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _submit(BuildContext context) async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {
      // Audio cleanup must not block answer submission.
    }
    final completed = await viewModel.submitAnswer();
    if (completed && context.mounted) {
      context.go('/placement/result');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            final item = viewModel.currentItem;
            if (item == null) {
              return loadingView();
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.margin,
                        AppSpacing.md,
                        AppSpacing.margin,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Câu ${viewModel.questionNumber}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              Text(
                                'Tối đa 30 câu',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppProgress(
                            value: viewModel.questionNumber / 30,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.margin),
                        children: [
                          if (item.audioUrl != null) ...[
                            AppCard(
                              color: AppColors.primaryFixed,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.headphones_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Expanded(
                                        child: Text(
                                          'Nghe đoạn âm thanh rồi chọn đáp án.',
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        key: const Key(
                                          'placement_play_audio',
                                        ),
                                        onPressed: _isLoadingAudio
                                            ? null
                                            : () => _playAudio(item.audioUrl!),
                                        icon: _isLoadingAudio
                                            ? const SizedBox.square(
                                                dimension: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.play_arrow_rounded,
                                              ),
                                        label: const Text('Nghe'),
                                      ),
                                    ],
                                  ),
                                  if (_audioError != null) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      _audioError!,
                                      key: const Key(
                                        'placement_audio_error',
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          Text(
                            item.stem,
                            key: const Key('placement_question_stem'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          for (var index = 0;
                              index < item.options.length;
                              index++) ...[
                            _AnswerOption(
                              key: Key('placement_option_$index'),
                              label: String.fromCharCode(65 + index),
                              value: item.options[index],
                              selected: viewModel.selectedAnswer ==
                                  item.options[index],
                              enabled: !viewModel.isLoading,
                              onSelected: viewModel.selectAnswer,
                            ),
                            if (index != item.options.length - 1)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                          if (viewModel.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              viewModel.errorMessage!,
                              key: const Key('placement_question_error'),
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.margin,
                        AppSpacing.md,
                        AppSpacing.margin,
                        AppSpacing.margin,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.surfaceHigh),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('placement_answer_submit'),
                          onPressed: viewModel.canSubmit
                              ? () => _submit(context)
                              : null,
                          child: viewModel.isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Trả lời'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? () => onSelected(value) : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryFixed : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.surfaceHigh,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    selected ? AppColors.primary : AppColors.surfaceLow,
                foregroundColor:
                    selected ? AppColors.surface : AppColors.textSecondary,
                child: Text(label),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
