import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFB22300);
  static const primaryContainer = Color(0xFFDA3711);
  static const pressed = Color(0xFFC92A0B);
  static const primaryFixed = Color(0xFFFFDAD2);
  static const background = Color(0xFFFBF9F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF5F3F3);
  static const surfaceDisabled = Color(0xFFEFeded);
  static const surfaceHigh = Color(0xFFE3E2E2);
  static const cardBorder = Color(0xFFE6E1E0);
  static const text = Color(0xFF1B1C1C);
  static const textSecondary = Color(0xFF5C403A);
  static const border = Color(0xFFE5BEB5);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const successSurface = Color(0xFFECFDF2);
  static const successForeground = Color(0xFF166534);
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
      fontFamily: 'HankenGrotesk',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            onSurfaceVariant: AppColors.textSecondary,
            error: AppColors.error,
            onError: Colors.white,
          ).copyWith(
            primaryContainer: AppColors.primaryFixed,
            onPrimaryContainer: AppColors.text,
            outline: AppColors.border,
            outlineVariant: AppColors.border,
            surfaceContainerLowest: AppColors.surface,
            surfaceContainerLow: AppColors.surfaceLow,
            surfaceContainer: AppColors.surfaceLow,
            surfaceContainerHigh: AppColors.surfaceHigh,
            surfaceContainerHighest: AppColors.surfaceHigh,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.text,
        iconColor: AppColors.primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: TextStyle(
          fontFamily: 'HankenGrotesk',
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'HankenGrotesk',
          color: AppColors.textSecondary,
          fontSize: 16,
        ),
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
        bodySmall: baseText.copyWith(fontSize: 12, height: 1.33),
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

  static ThemeData get dark {
    const baseText = TextStyle(
      fontFamily: 'HankenGrotesk',
      color: AppColorsDark.text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'HankenGrotesk',
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme:
          ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: AppColorsDark.primary,
            primary: AppColorsDark.primary,
            onPrimary: Colors.white,
            surface: AppColorsDark.surface,
            onSurface: AppColorsDark.text,
            onSurfaceVariant: AppColorsDark.textSecondary,
            error: AppColorsDark.error,
            onError: Colors.white,
          ).copyWith(
            primaryContainer: AppColorsDark.primaryContainer,
            onPrimaryContainer: AppColorsDark.text,
            outline: AppColorsDark.border,
            outlineVariant: AppColorsDark.border,
            surfaceContainerLowest: AppColorsDark.surface,
            surfaceContainerLow: AppColorsDark.surfaceLow,
            surfaceContainer: AppColorsDark.surfaceLow,
            surfaceContainerHigh: AppColorsDark.surfaceHigh,
            surfaceContainerHighest: AppColorsDark.surfaceHigh,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.background,
        foregroundColor: AppColorsDark.text,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColorsDark.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColorsDark.border),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColorsDark.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColorsDark.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColorsDark.error, width: 1.5),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColorsDark.text,
        iconColor: AppColorsDark.primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColorsDark.surface,
        titleTextStyle: TextStyle(
          fontFamily: 'HankenGrotesk',
          color: AppColorsDark.text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'HankenGrotesk',
          color: AppColorsDark.textSecondary,
          fontSize: 16,
        ),
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
        bodySmall: baseText.copyWith(fontSize: 12, height: 1.33),
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
        backgroundColor: AppColorsDark.surface,
        indicatorColor: AppColorsDark.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColorsDark.text),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColorsDark.primary
              : AppColorsDark.surfaceHigh,
        ),
      ),
    );
  }
}

abstract final class AppColorsDark {
  static const primary = Color(0xFFFF5733);
  static const primaryContainer = Color(0xFF8B1A00);
  static const pressed = Color(0xFFE03E1A);
  static const primaryFixed = Color(0xFF4A1205);
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceLow = Color(0xFF242424);
  static const surfaceDisabled = Color(0xFF2C2C2C);
  static const surfaceHigh = Color(0xFF383838);
  static const cardBorder = Color(0xFF383838);
  static const text = Color(0xFFF3F4F6);
  static const textSecondary = Color(0xFFD1D5DB);
  static const border = Color(0xFF4B5563);
  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0xFF14532D);
  static const successSurface = Color(0xFF1B3123);
  static const successForeground = Color(0xFFDCFCE7);
  static const error = Color(0xFFEF4444);
  static const errorSoft = Color(0xFF7F1D1D);
  static const muted = Color(0xFF9CA3AF);
  static const warning = Color(0xFFF59E0B);
  static const shadow = Color(0x33000000);
  static const primaryShadow = Color(0x55FF5733);
}
