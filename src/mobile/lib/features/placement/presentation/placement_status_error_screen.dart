import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class PlacementStatusErrorScreen extends StatelessWidget {
  const PlacementStatusErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionController = context.read<SessionController>();
    final l10n = context.watch<AppLanguageProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.translate('placement.error.title'),
                    key: const Key('placement_status_error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.translate('placement.error.subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const Key('placement_status_retry'),
                    onPressed: sessionController.refreshPlacementStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.translate('placement.error.retry')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    key: const Key('placement_status_logout'),
                    onPressed: () async {
                      try {
                        await sessionController.logout();
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.translate('placement.error.logout_failed'),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.translate('placement.error.logout')),
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
