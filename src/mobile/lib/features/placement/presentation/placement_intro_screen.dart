import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';

class PlacementIntroScreen extends StatelessWidget {
  const PlacementIntroScreen({required this.viewModel, super.key});

  final PlacementViewModel viewModel;

  Future<void> _start(BuildContext context) async {
    final started = await viewModel.start();
    if (started && context.mounted) {
      context.go('/placement/question');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedBuilder(
                animation: viewModel,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Kiểm tra trình độ đầu vào',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'lingoRoad sẽ chọn câu hỏi thích ứng để xác định cấp độ '
                      'CEFR phù hợp với bạn.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const AppCard(
                      child: Column(
                        children: [
                          _IntroPoint(
                            icon: Icons.quiz_outlined,
                            title: '8–30 câu hỏi',
                            description:
                                'Bài kiểm tra kết thúc khi kết quả đủ tin cậy.',
                          ),
                          SizedBox(height: AppSpacing.lg),
                          _IntroPoint(
                            icon: Icons.tune_rounded,
                            title: 'Độ khó thích ứng',
                            description:
                                'Câu tiếp theo được chọn theo câu trả lời trước.',
                          ),
                          SizedBox(height: AppSpacing.lg),
                          _IntroPoint(
                            icon: Icons.insights_rounded,
                            title: 'Kết quả CEFR',
                            description:
                                'Kết quả giúp cá nhân hóa lộ trình học ban đầu.',
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        viewModel.errorMessage!,
                        key: const Key('placement_intro_error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      key: const Key('placement_start'),
                      onPressed:
                          viewModel.isLoading ? null : () => _start(context),
                      child: viewModel.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Bắt đầu kiểm tra'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Hãy chọn đáp án tốt nhất. Bạn không thể quay lại câu '
                      'trước.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
