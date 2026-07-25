import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded, size: 64, color: AppColors.primary),
            SizedBox(height: AppSpacing.md),
            Text(
              'lingoRoad',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
