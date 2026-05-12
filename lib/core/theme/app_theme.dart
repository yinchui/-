import 'package:flutter/material.dart';

class AppColors {
  static const warmBackground = Color(0xFFFDF6EE);
  static const card = Color(0xFFFFFFFF);
  static const green = Color(0xFF6BBF7A);
  static const greenSoft = Color(0xFFE8F7EB);
  static const orange = Color(0xFFF2994A);
  static const orangeSoft = Color(0xFFFFF0E0);
  static const red = Color(0xFFEF5350);
  static const redSoft = Color(0xFFFFEBEE);
  static const textPrimary = Color(0xFF3D2E1F);
  static const textSecondary = Color(0xFF8B7355);
  static const textMuted = Color(0xFFBBA88A);
  static const borderSoft = Color(0xFFF0E6D8);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      secondary: AppColors.green,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.warmBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.orangeSoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        labelMedium: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
