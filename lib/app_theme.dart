import 'package:flutter/material.dart';

/// Centralized color definitions for the app.
/// Use these instead of defining colors in individual screens.
///
/// Example:
/// ```dart
/// import 'package:a1_tools/app_theme.dart';
///
/// // Instead of: static const Color _accent = Color(0xFFF49320);
/// // Use: AppColors.accent
/// ```
class AppColors {
  AppColors._(); // Prevent instantiation

  /// Primary brand accent color (orange)
  static const Color accent = Color(0xFFF49320);

  /// Lighter variant of accent for hover/pressed states
  static const Color accentLight = Color(0xFFFFC470);

  /// Darker variant of accent
  static const Color accentDark = Color(0xFFD67D10);

  /// Success/positive color
  static const Color success = Color(0xFF4CAF50);

  /// Error/destructive color
  static const Color error = Color(0xFFE53935);

  /// Warning color
  static const Color warning = Color(0xFFFFA726);

  /// Info color
  static const Color info = Color(0xFF2196F3);
}

class AppTheme {
  static const Color accentOrange = AppColors.accent; // Use centralized color
  
  // Light theme colors
  static const Color lightBg = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFF5F5F5);
  static const Color lightText = Colors.black;
  static const Color lightTextSecondary = Color(0xFF757575);
  
  // Dark theme colors
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252525);
  static const Color darkText = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: accentOrange,
      secondary: accentOrange,
      surface: lightSurface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: lightText,
    ),
    scaffoldBackgroundColor: lightBg,
    canvasColor: lightSurface,
    cardColor: lightCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightText,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentOrange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: accentOrange, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentOrange),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentOrange, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: lightText,
      iconColor: accentOrange,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentOrange,
      linearTrackColor: Color(0xFFE0E0E0),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightCard,
      contentTextStyle: const TextStyle(color: lightText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accentOrange,
      secondary: accentOrange,
      surface: darkSurface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: darkText,
    ),
    scaffoldBackgroundColor: darkBg,
    canvasColor: darkSurface,
    cardColor: darkCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkText,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentOrange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentOrange,
        side: const BorderSide(color: accentOrange, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentOrange),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentOrange, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: darkText,
      iconColor: accentOrange,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF3A3A3A), thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentOrange,
      linearTrackColor: Color(0xFF3A3A3A),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkCard,
      contentTextStyle: const TextStyle(color: darkText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}