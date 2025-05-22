import 'package:flutter/material.dart';

class AppColors {
  // Main colors
  static const Color primaryBlue = Color(0xFF0A5688);
  static const Color accentTeal = Color(0xFF00838F);
  static const Color backgroundWhite = Color(0xffFAFAFA);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xff2D3748);
  static const Color textMedium = Color(0xff4A5568);
  static const Color textLight = Color(0xff718096);

  // UI colors
  static const Color blueAccent = Color(0xff3182CE);
  static const Color greenAccent = Color(0xff38A169);
  static const Color orangeAccent = Color(0xffED8936);
  static const Color purpleAccent = Color(0xff805AD5);
  static const Color tealAccent = Color(0xFF009688);

  // Neutral colors
  static const Color divider = Color(0xffE2E8F0);
  static const Color cardBorder = Color(0xffEDF2F7);
  static const Color borderColor = Color(0xffE2E8F0);
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      primary: AppColors.primaryBlue,
      onPrimary: Colors.white,
      secondary: AppColors.accentTeal,
      onSecondary: Colors.white,
      background: AppColors.backgroundWhite,
      surface: AppColors.surfaceWhite,
      onBackground: AppColors.textDark,
      onSurface: AppColors.textDark,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.backgroundWhite,

    // AppBar theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.primaryBlue,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      color: AppColors.surfaceWhite,
      margin: EdgeInsets.zero,
    ),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentTeal,
        side: BorderSide(color: AppColors.accentTeal),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // Input field theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.textLight),
      hintStyle: TextStyle(color: AppColors.textLight),
    ),

    // Divider theme
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 24,
    ),

    // Text theme
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.bold,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.bold,
        fontSize: 28,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.bold,
        fontSize: 24,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      titleMedium: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(
        color: AppColors.textMedium,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textMedium,
        fontSize: 14,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: AppColors.textDark,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
