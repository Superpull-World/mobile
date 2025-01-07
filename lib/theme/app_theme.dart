import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFEEFC42);
  static const Color secondaryColor = Colors.black;
  static const Color backgroundColor = Colors.black;
  static const Color surfaceColor = Color(0xFF1A1A1A);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Colors.white70;

  static ThemeData get theme => ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: secondaryColor,
        disabledBackgroundColor: primaryColor.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    cardTheme: CardTheme(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
        letterSpacing: 0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        color: textSecondaryColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: textSecondaryColor,
      ),
    ),
    iconTheme: const IconThemeData(
      color: primaryColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textPrimaryColor,
      elevation: 0,
    ),
  );
} 