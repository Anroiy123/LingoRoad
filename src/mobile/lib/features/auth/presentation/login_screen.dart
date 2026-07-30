import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_scaffold.dart';
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
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
        builder: (context, viewModel, _) => AuthScaffold(
          title: l10n.translate('auth.login.title'),
          subtitle: l10n.translate('auth.login.subtitle'),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('login_email'),
                    controller: _emailController,
                    enabled: !viewModel.isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l10n.translate('auth.login.email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final key = AuthViewModel.validateEmail(value);
                      return key != null ? l10n.translate(key) : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('login_password'),
                    controller: _passwordController,
                    enabled: !viewModel.isSubmitting,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: l10n.translate('auth.login.password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? l10n.translate('auth.login.show_password')
                            : l10n.translate('auth.login.hide_password'),
                      ),
                    ),
                    validator: (value) {
                      final key = AuthViewModel.validatePassword(value);
                      return key != null ? l10n.translate(key) : null;
                    },
                    onFieldSubmitted: (_) => _submit(viewModel),
                  ),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.translate(viewModel.errorMessage!),
                      key: const Key('auth_error'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('login_submit'),
                    onPressed: viewModel.isSubmitting ? null : () => _submit(viewModel),
                    child: viewModel.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.translate('auth.login.submit')),
                  ),
                  TextButton(
                    onPressed: viewModel.isSubmitting
                        ? null
                        : () => context.go('/register'),
                    child: Text(l10n.translate('auth.login.register_link')),
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

