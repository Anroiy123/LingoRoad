import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_form_components.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await viewModel.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return ChangeNotifierProvider<AuthViewModel>(
      create: (context) => AuthViewModel(
        authRepository: context.read<AuthRepository>(),
        sessionController: context.read<SessionController>(),
      ),
      child: Consumer<AuthViewModel>(
        builder: (context, viewModel, _) {
          final scheme = Theme.of(context).colorScheme;
          return AuthFormScaffold(
            title: l10n.translate('auth.register.title'),
            subtitle: l10n.translate('auth.register.subtitle'),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      fieldKey: const Key('register_name'),
                      controller: _nameController,
                      label: l10n.translate('auth.register.name_label'),
                      hint: l10n.translate('auth.register.name_placeholder'),
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !viewModel.isSubmitting,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (_) => null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      fieldKey: const Key('register_email'),
                      controller: _emailController,
                      label: l10n.translate('auth.login.email'),
                      hint: l10n.translate('auth.register.email_placeholder'),
                      prefixIcon: Icons.mail_outlined,
                      enabled: !viewModel.isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final key = AuthViewModel.validateEmail(value);
                        return key == null ? null : l10n.translate(key);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      fieldKey: const Key('register_password'),
                      controller: _passwordController,
                      label: l10n.translate('auth.login.password'),
                      hint: l10n.translate(
                        'auth.register.password_placeholder',
                      ),
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !viewModel.isSubmitting,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      suffixIcon: _visibilityButton(
                        obscure: _obscurePassword,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        scheme: scheme,
                        l10n: l10n,
                      ),
                      validator: (value) {
                        final key = AuthViewModel.validatePassword(value);
                        return key == null ? null : l10n.translate(key);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      fieldKey: const Key('register_confirm_password'),
                      controller: _confirmPasswordController,
                      label: l10n.translate(
                        'auth.register.confirm_password_label',
                      ),
                      hint: l10n.translate(
                        'auth.register.confirm_password_placeholder',
                      ),
                      prefixIcon: Icons.lock_reset_rounded,
                      enabled: !viewModel.isSubmitting,
                      obscureText: _obscureConfirmation,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      suffixIcon: _visibilityButton(
                        obscure: _obscureConfirmation,
                        onPressed: () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                        scheme: scheme,
                        l10n: l10n,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.translate(
                            'auth.validation.confirm_password_empty',
                          );
                        }
                        if (value != _passwordController.text) {
                          return l10n.translate(
                            'auth.validation.confirm_password_mismatch',
                          );
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(viewModel),
                    ),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.translate(viewModel.errorMessage!),
                          key: const Key('auth_error'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('register_submit'),
                        onPressed: viewModel.isSubmitting
                            ? null
                            : () => _submit(viewModel),
                        child: viewModel.isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n
                                    .translate('auth.register.submit')
                                    .toUpperCase(),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AuthDivider(),
                    const SizedBox(height: AppSpacing.lg),
                    const AuthSocialButtons(),
                    const SizedBox(height: AppSpacing.sm),
                    AuthSwitchButton(
                      prompt: l10n.translate('auth.register.has_account'),
                      action: l10n.translate('auth.register.login_action'),
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _visibilityButton({
    required bool obscure,
    required VoidCallback onPressed,
    required ColorScheme scheme,
    required AppLanguageProvider l10n,
  }) => IconButton(
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    onPressed: onPressed,
    icon: Icon(
      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: scheme.onSurfaceVariant,
    ),
    tooltip: l10n.translate(
      obscure ? 'auth.login.show_password' : 'auth.login.hide_password',
    ),
  );
}
