import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/brand_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 112),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: 'Đang tải',
              child: CircularProgressIndicator(
                key: Key('splash_progress'),
                value: 0.68,
                strokeWidth: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
