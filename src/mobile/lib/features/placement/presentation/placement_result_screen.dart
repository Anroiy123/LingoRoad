import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class PlacementResultScreen extends StatelessWidget {
  const PlacementResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlacementViewModel>();
    final sessionController = context.read<SessionController>();
    final l10n = context.watch<AppLanguageProvider>();
    final scheme = Theme.of(context).colorScheme;
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
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.translate('placement.result.title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.translate('placement.result.subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    color: scheme.primaryContainer,
                    child: Column(
                      children: [
                        Text(
                          l10n.translate('placement.result.cefr_level'),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          result?.cefr ?? '',
                          key: const Key('placement_result_cefr'),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: scheme.primary, fontSize: 52),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ResultMetric(
                              label: l10n.translate(
                                'placement.result.answered',
                              ),
                              value: l10n.translate(
                                'placement.result.answered_val',
                                [result?.itemsAnswered ?? 0],
                              ),
                            ),
                            _ResultMetric(
                              label: l10n.translate(
                                'placement.result.confidence',
                              ),
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
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            l10n.translate('placement.result.disclaimer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const Key('placement_result_continue'),
                    onPressed: () async {
                      await sessionController.markPlacementCompleted();
                      if (context.mounted) context.go('/home');
                    },
                    child: Text(
                      l10n.translate('placement.result.continue_btn'),
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

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
