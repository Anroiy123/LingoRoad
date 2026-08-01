import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await viewModel.register(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
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
        builder: (context, viewModel, _) => Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Background pattern (radial grid replacement using AppColors.border)
              const Positioned.fill(
                child: CustomPaint(
                  painter: GridBackgroundPainter(),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.margin,
                      vertical: AppSpacing.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand / Header
                          Image.asset(
                            'assets/images/logo_black.png',
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                           Text(
                            l10n.translate('auth.register.title'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('auth.register.subtitle'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Form Container
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Full Name Input
                                    Text(
                                      l10n.translate('auth.register.name_label'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      key: const Key('register_name'),
                                      controller: _nameController,
                                      enabled: !viewModel.isSubmitting,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      style: const TextStyle(color: AppColors.text),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        hintText: l10n.translate('auth.register.name_placeholder'),
                                        hintStyle: const TextStyle(color: AppColors.muted),
                                        prefixIcon: const Icon(
                                          Icons.person_outline_rounded,
                                          color: AppColors.muted,
                                          size: 20,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: AppSpacing.md,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.cta,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    // Email Input
                                    Text(
                                      l10n.translate('auth.login.email'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      key: const Key('register_email'),
                                      controller: _emailController,
                                      enabled: !viewModel.isSubmitting,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.newUsername],
                                      style: const TextStyle(color: AppColors.text),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        hintText: l10n.translate('auth.register.email_placeholder'),
                                        hintStyle: const TextStyle(color: AppColors.muted),
                                        prefixIcon: const Icon(
                                          Icons.mail_outlined,
                                          color: AppColors.muted,
                                          size: 20,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: AppSpacing.md,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.cta,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final key = AuthViewModel.validateEmail(value);
                                        return key != null ? l10n.translate(key) : null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    // Password Input
                                    Text(
                                      l10n.translate('auth.login.password'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      key: const Key('register_password'),
                                      controller: _passwordController,
                                      enabled: !viewModel.isSubmitting,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.newPassword],
                                      style: const TextStyle(color: AppColors.text),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        hintText: l10n.translate('auth.register.password_placeholder'),
                                        hintStyle: const TextStyle(color: AppColors.muted),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.muted,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: AppColors.muted,
                                          ),
                                          tooltip: _obscurePassword
                                              ? l10n.translate('auth.login.show_password')
                                              : l10n.translate('auth.login.hide_password'),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: AppSpacing.md,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.cta,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final key = AuthViewModel.validatePassword(value);
                                        return key != null ? l10n.translate(key) : null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    // Confirm Password Input
                                    Text(
                                      l10n.translate('auth.register.confirm_password_label'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      key: const Key('register_confirm_password'),
                                      controller: _confirmPasswordController,
                                      enabled: !viewModel.isSubmitting,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      style: const TextStyle(color: AppColors.text),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        hintText: l10n.translate('auth.register.confirm_password_placeholder'),
                                        hintStyle: const TextStyle(color: AppColors.muted),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.muted,
                                          size: 20,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: AppSpacing.md,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.cta,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return l10n.translate('auth.validation.confirm_password_empty');
                                        }
                                        if (value != _passwordController.text) {
                                          return l10n.translate('auth.validation.confirm_password_mismatch');
                                        }
                                        return null;
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

                                    // Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton(
                                        key: const Key('register_submit'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.cta,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                        ),
                                        onPressed: viewModel.isSubmitting
                                            ? null
                                            : () => _submit(viewModel),
                                        child: viewModel.isSubmitting
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                l10n.translate('auth.register.submit').toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Plus Jakarta Sans',
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Divider "or continue with"
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Divider(
                                            color: AppColors.border,
                                            thickness: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                          ),
                                          child: Text(
                                            l10n.translate('auth.login.or_continue'),
                                            style: TextStyle(
                                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Plus Jakarta Sans',
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          child: Divider(
                                            color: AppColors.border,
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Social Logins
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: AppColors.border,
                                                width: 2,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                            ),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(l10n.translate('common.not_implemented')),
                                                ),
                                              );
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const CustomPaint(
                                                  size: Size(20, 20),
                                                  painter: GoogleLogoPainter(),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Google',
                                                  style: TextStyle(
                                                    color: AppColors.text.withValues(alpha: 0.9),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'Plus Jakarta Sans',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: AppColors.border,
                                                width: 2,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                            ),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(l10n.translate('common.not_implemented')),
                                                ),
                                              );
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.facebook,
                                                  color: Color(0xFF1877F2),
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      'Facebook',
                                                      style: TextStyle(
                                                        color: AppColors.text.withValues(alpha: 0.9),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        fontFamily: 'Plus Jakarta Sans',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Sign In Footer
                                    Align(
                                      alignment: Alignment.center,
                                      child: GestureDetector(
                                        onTap: viewModel.isSubmitting
                                            ? null
                                            : () => context.go('/login'),
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textSecondary,
                                              fontFamily: 'Plus Jakarta Sans',
                                            ),
                                            children: [
                                              TextSpan(text: l10n.translate('auth.register.has_account')),
                                              TextSpan(
                                                text: l10n.translate('auth.register.login_action'),
                                                style: const TextStyle(
                                                  color: AppColors.cta,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridBackgroundPainter extends CustomPainter {
  const GridBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    const double spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final double thickness = size.width * 0.28;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - thickness / 2);

    // Red (Top)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 3.14159 * 1.15, 3.14159 * 0.7, false, redPaint);

    // Yellow (Left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 3.14159 * 0.65, 3.14159 * 0.5, false, yellowPaint);

    // Green (Bottom)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 3.14159 * 0.15, 3.14159 * 0.6, false, greenPaint);

    // Blue (Right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 3.14159 * -0.35, 3.14159 * 0.5, false, bluePaint);

    // Blue crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - thickness / 2, cx + r, cy + thickness / 2),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

