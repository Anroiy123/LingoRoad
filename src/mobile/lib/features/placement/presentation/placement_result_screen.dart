import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';

class PlacementResultScreen extends StatelessWidget {
  const PlacementResultScreen({
    required this.viewModel,
    required this.sessionController,
    super.key,
  });

  final PlacementViewModel viewModel;
  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final result = viewModel.result;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bạn đã hoàn thành!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'lingoRoad đã xác định cấp độ khởi đầu phù hợp với bạn.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    color: AppColors.primaryFixed,
                    child: Column(
                      children: [
                        Text(
                          'Cấp độ CEFR',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          result?.cefr ?? '',
                          key: const Key('placement_result_cefr'),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontSize: 52,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ResultMetric(
                              label: 'Đã trả lời',
                              value: '${result?.itemsAnswered ?? 0} câu',
                            ),
                            _ResultMetric(
                              label: 'Độ tin cậy',
                              value: result == null
                                  ? ''
                                  : 'SE ${result.se.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Kết quả này sẽ được dùng để xây dựng lộ trình '
                            'học cá nhân hóa. Đây là đánh giá định hướng ban '
                            'đầu, không phải chứng chỉ CEFR chính thức.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const Key('placement_result_continue'),
                    onPressed: () {
                      sessionController.markPlacementCompleted();
                      context.go('/home');
                    },
                    child: const Text('Bắt đầu lộ trình'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
