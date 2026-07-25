import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cta = Color(0xFFF24822);
  static const primary = Color(0xFFB22300);
  static const primaryContainer = Color(0xFFDA3711);
  static const pressed = Color(0xFFC92A0B);
  static const primaryFixed = Color(0xFFFFDAD2);
  static const background = Color(0xFFFBF9F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF5F3F3);
  static const surfaceDisabled = Color(0xFFEFeded);
  static const surfaceHigh = Color(0xFFE3E2E2);
  static const text = Color(0xFF1B1C1C);
  static const textSecondary = Color(0xFF5C403A);
  static const border = Color(0xFFE5BEB5);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const error = Color(0xFFBA1A1A);
  static const errorSoft = Color(0xFFFFDAD6);
  static const muted = Color(0xFF9C9694);
  static const warning = Color(0xFFD97706);
  static const shadow = Color(0x0A000000);
  static const primaryShadow = Color(0x30B22300);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const margin = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 24.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    const baseText = TextStyle(
      fontFamily: 'HankenGrotesk',
      color: AppColors.text,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displaySmall: baseText.copyWith(
          fontSize: 32,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.64,
        ),
        headlineMedium: baseText.copyWith(
          fontSize: 24,
          height: 1.33,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseText.copyWith(
          fontSize: 22,
          height: 1.27,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseText.copyWith(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.copyWith(fontSize: 18, height: 1.55),
        bodyMedium: baseText.copyWith(fontSize: 16, height: 1.5),
        labelLarge: baseText.copyWith(
          fontSize: 14,
          height: 1.42,
          fontWeight: FontWeight.w600,
          letterSpacing: .14,
        ),
        labelSmall: baseText.copyWith(
          fontSize: 12,
          height: 1.33,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryFixed,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceHigh,
        ),
      ),
    );
  }
}
