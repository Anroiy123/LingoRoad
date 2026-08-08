import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class PlacementIntroScreen extends StatelessWidget {
  const PlacementIntroScreen({super.key});

  Future<void> _start(
      BuildContext context, PlacementViewModel viewModel) async {
    final started = await viewModel.start();
    if (started && context.mounted) {
      context.go('/placement/question');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlacementViewModel>();
    final l10n = context.watch<AppLanguageProvider>();
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
                    Icons.route_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.translate('placement.intro.title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.translate('placement.intro.subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      children: [
                        _IntroPoint(
                          icon: Icons.quiz_outlined,
                          title:
                              l10n.translate('placement.intro.duration_title'),
                          description:
                              l10n.translate('placement.intro.duration_desc'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _IntroPoint(
                          icon: Icons.tune_rounded,
                          title:
                              l10n.translate('placement.intro.adaptive_title'),
                          description:
                              l10n.translate('placement.intro.adaptive_desc'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _IntroPoint(
                          icon: Icons.insights_rounded,
                          title: l10n.translate('placement.intro.result_title'),
                          description:
                              l10n.translate('placement.intro.result_desc'),
                        ),
                      ],
                    ),
                  ),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.translate(viewModel.errorMessage!),
                      key: const Key('placement_intro_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const Key('placement_start'),
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _start(context, viewModel),
                    child: viewModel.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.translate('placement.intro.start')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.translate('placement.intro.note'),
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
