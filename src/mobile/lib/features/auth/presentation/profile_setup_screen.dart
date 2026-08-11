import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

/// Required, restart-safe onboarding form. There deliberately is no back or skip action.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _cefr = 'B2';
  int _minutes = 30;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().completeProfileSetup(
        name: _name.text.trim(),
        targetCefr: _cefr,
        dailyGoalMinutes: _minutes,
      );
      if (!mounted) return;
      context.read<SessionController>().markProfileSetupCompleted();
    } catch (_) {
      if (mounted) setState(() => _error = 'profile_setup.submit_error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: scheme.primary,
                      size: 56,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.translate('profile_setup.title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.translate('profile_setup.subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      variant: AppCardVariant.outlined,
                      borderColor: scheme.outlineVariant,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const Key('profile_setup_name'),
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: l10n.translate('profile_setup.name'),
                              hintText: l10n.translate(
                                'profile_setup.name_hint',
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? l10n.translate('profile_setup.name_required')
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.translate('profile_setup.target'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'A1', label: Text('A1')),
                              ButtonSegment(value: 'A2', label: Text('A2')),
                              ButtonSegment(value: 'B1', label: Text('B1')),
                              ButtonSegment(value: 'B2', label: Text('B2')),
                            ],
                            selected: {_cefr},
                            onSelectionChanged: _submitting
                                ? null
                                : (values) =>
                                      setState(() => _cefr = values.first),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.translate('profile_setup.daily_goal', [
                              _minutes,
                            ]),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Slider(
                            key: const Key('profile_setup_daily_goal'),
                            value: _minutes.toDouble(),
                            min: 10,
                            max: 120,
                            divisions: 22,
                            label: '$_minutes',
                            onChanged: _submitting
                                ? null
                                : (value) =>
                                      setState(() => _minutes = value.round()),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.translate(_error!),
                          key: const Key('profile_setup_error'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      key: const Key('profile_setup_submit'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(),
                            )
                          : Text(l10n.translate('profile_setup.submit')),
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

class ProfileSetupStatusErrorScreen extends StatelessWidget {
  const ProfileSetupStatusErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final session = context.read<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.translate('profile_setup.status_error_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.translate('profile_setup.status_error_subtitle'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const Key('profile_setup_status_retry'),
                    onPressed: session.refreshProfileSetupStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.translate('common.retry')),
                  ),
                  TextButton.icon(
                    key: const Key('profile_setup_status_logout'),
                    onPressed: () async {
                      try {
                        await session.logout();
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
