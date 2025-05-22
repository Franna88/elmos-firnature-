import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryRed = Color(0xFF1A365D);
  static const Color accentRed = Color(0xFF2A4A80);
  static const Color backgroundWhite = Color(0xFFF7FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF1A202C);
  static const Color textMedium = Color(0xFF4A5568);
  static const Color textLight = Color(0xFF718096);

  // UI colors
  static const Color blueAccent = Color(0xFF3182CE);
  static const Color greenAccent = Color(0xFF38A169);
  static const Color orangeAccent = Color(0xFFDD6B20);
  static const Color purpleAccent = Color(0xFF805AD5);

  // Neutral colors
  static const Color divider = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFEDF2F7);

  // Additional colors from UI upgrade
  static const Color primary = Color(0xFF1A365D);
  static const Color primaryLight = Color(0xFF2A4A80);
  static const Color primaryDark = Color(0xFF0F2942);

  // Secondary Colors
  static const Color secondary = Color(0xFF2C7A7B);
  static const Color secondaryLight = Color(0xFF38B2AC);
  static const Color secondaryDark = Color(0xFF285E61);

  // Accent Colors
  static const Color accent = Color(0xFFDD6B20);
  static const Color accentLight = Color(0xFFED8936);
  static const Color accentDark = Color(0xFFC05621);

  // More Neutral Colors
  static const Color background = Color(0xFFF7FAFC);
  static const Color surfaceLight = Color(0xFFEDF2F7);
  static const Color surface = Color(0xFFE2E8F0);
  static const Color grey100 = Color(0xFFCBD5E0);
  static const Color grey200 = Color(0xFFA0AEC0);
  static const Color grey300 = Color(0xFF718096);
  static const Color grey400 = Color(0xFF4A5568);
  static const Color grey500 = Color(0xFF2D3748);
  static const Color black = Color(0xFF1A202C);
  static const Color white = Colors.white;

  // Semantic Colors
  static const Color success = Color(0xFF38A169);
  static const Color warning = Color(0xFFECC94B);
  static const Color error = Color(0xFFE53E3E);
  static const Color info = Color(0xFF3182CE);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  static const Color textDisabled = Color(0xFFA0AEC0);

  // Border Colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E0);
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      background: AppColors.background,
      surface: AppColors.surfaceWhite,
      onBackground: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      brightness: Brightness.light,
      error: AppColors.error,
      onError: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: Colors.white,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: Colors.white,
      surfaceVariant: AppColors.surfaceLight,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.background,

    // AppBar theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surfaceWhite,
      margin: EdgeInsets.zero,
    ),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        disabledForegroundColor: AppColors.textDisabled,
        disabledBackgroundColor: AppColors.grey100,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        disabledForegroundColor: AppColors.textDisabled,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        disabledForegroundColor: AppColors.textDisabled,
      ),
    ),

    // Input field theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textTertiary),
    ),

    // Divider theme
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // Text theme
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 32,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 28,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
        letterSpacing: -0.25,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.25,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        letterSpacing: -0.25,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        height: 1.5,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      ),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.disabled)) {
          return AppColors.grey100;
        }
        if (states.contains(MaterialState.selected)) {
          return AppColors.primary;
        }
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(AppColors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
      ),
      side: BorderSide(color: AppColors.grey300),
    ),

    // Tab Bar Theme
    tabBarTheme: TabBarTheme(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    ),

    // Dialog Theme
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.white,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // Progress Indicator Theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.grey100,
      linearTrackColor: AppColors.grey100,
    ),
  );
}
