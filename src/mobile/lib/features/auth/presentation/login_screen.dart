import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_scaffold.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authRepository,
    required this.sessionController,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthViewModel _viewModel;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthViewModel(
      authRepository: widget.authRepository,
      sessionController: widget.sessionController,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _viewModel.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Chào mừng trở lại',
      subtitle: 'Đăng nhập để tiếp tục lộ trình học của bạn.',
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('login_email'),
                  controller: _emailController,
                  enabled: !_viewModel.isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: AuthViewModel.validateEmail,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('login_password'),
                  controller: _passwordController,
                  enabled: !_viewModel.isSubmitting,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
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
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                    ),
                  ),
                  validator: AuthViewModel.validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _viewModel.errorMessage!,
                    key: const Key('auth_error'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('login_submit'),
                  onPressed: _viewModel.isSubmitting ? null : _submit,
                  child: _viewModel.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đăng nhập'),
                ),
                TextButton(
                  onPressed: _viewModel.isSubmitting
                      ? null
                      : () => context.go('/register'),
                  child: const Text('Chưa có tài khoản? Đăng ký'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
