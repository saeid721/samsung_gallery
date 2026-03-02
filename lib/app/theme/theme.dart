// ============================================================
// core/theme/app_theme.dart — Samsung-inspired Material 3 Theme
// ============================================================

import 'package:flutter/material.dart';

abstract class AppColors {
  // Samsung Gallery primary palette
  static const primary = Color(0xFF1259C3);       // Samsung Blue
  static const primaryDark = Color(0xFF0A3880);
  static const accent = Color(0xFF00B4D8);
  static const background = Color(0xFFF8F9FA);
  static const backgroundDark = Color(0xFF1A1A1A);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF2C2C2C);
  static const onSurface = Color(0xFF1C1B1F);
  static const onSurfaceDark = Color(0xFFE6E1E5);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF2E7D32);

  // Shimmer loading
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Text
  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF757575);

  // Badges & Overlays
  static const Color videoBadge = Color(0xCC000000);
  static const Color gifBadge = Color(0xFF9C27B0);

  // Selection
  static const Color selectionOverlay = Color(0x4D1a73e8);
  static const Color selectionBorder = Color(0xFF1a73e8);
}

abstract class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    fontFamily: 'SamsungSans',
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SamsungSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'SamsungSans', fontSize: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primary.withOpacity(0.1),
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(fontFamily: 'SamsungSans'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    fontFamily: 'SamsungSans',
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: AppColors.onSurfaceDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SamsungSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurfaceDark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: AppColors.primary.withOpacity(0.25),
    ),
  );
}
