import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.height = 88,
    super.key,
  });

  static const assetPath = 'assets/images/logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo LingoRoad',
      child: ExcludeSemantics(
        child: Align(
          child: Container(
            height: height,
            constraints: BoxConstraints(maxWidth: height * 1.9),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
