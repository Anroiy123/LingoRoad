import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_form_components.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await viewModel.login(
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
            title: l10n.translate('auth.login.title'),
            subtitle: l10n.translate('auth.login.subtitle'),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      fieldKey: const Key('login_email'),
                      controller: _emailController,
                      label: l10n.translate('auth.login.email'),
                      hint: l10n.translate('auth.login.email_placeholder'),
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
                      fieldKey: const Key('login_password'),
                      controller: _passwordController,
                      label: l10n.translate('auth.login.password'),
                      hint: l10n.translate('auth.login.password_placeholder'),
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !viewModel.isSubmitting,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      suffixIcon: IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        tooltip: l10n.translate(
                          _obscurePassword
                              ? 'auth.login.show_password'
                              : 'auth.login.hide_password',
                        ),
                      ),
                      validator: (value) {
                        final key = AuthViewModel.validatePassword(value);
                        return key == null ? null : l10n.translate(key);
                      },
                      onFieldSubmitted: (_) => _submit(viewModel),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('common.not_implemented'),
                                ),
                              ),
                            ),
                        child: Text(
                          l10n.translate('auth.login.forgot_password'),
                        ),
                      ),
                    ),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
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
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('login_submit'),
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
                                    .translate('auth.login.submit')
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
                      prompt: l10n.translate('auth.login.no_account'),
                      action: l10n.translate('auth.login.register_action'),
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () => context.go('/register'),
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
}
