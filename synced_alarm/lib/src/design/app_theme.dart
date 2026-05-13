import 'package:flutter/material.dart';

class SereneWakeColors {
  static const background = Color(0xFFF7FAF4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF0F5EE);
  static const surfaceContainer = Color(0xFFE9F0E8);
  static const primary = Color(0xFF386948);
  static const primaryDark = Color(0xFF2B5D3C);
  static const primarySoft = Color(0xFFB9EFC5);
  static const accent = Color(0xFF386948);
  static const accentDark = Color(0xFF2B5D3C);
  static const text = Color(0xFF2C342E);
  static const mutedText = Color(0xFF59615A);
  static const outline = Color(0xFFABB4AC);
  static const success = Color(0xFF1C7C54);
  static const error = Color(0xFFA83836);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const margin = 20.0;
}

ThemeData buildSereneWakeTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: SereneWakeColors.primary,
    brightness: Brightness.light,
    primary: SereneWakeColors.primary,
    secondary: SereneWakeColors.accent,
    surface: SereneWakeColors.surface,
    error: SereneWakeColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: SereneWakeColors.background,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: SereneWakeColors.background,
      foregroundColor: SereneWakeColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: SereneWakeColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: SereneWakeColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SereneWakeColors.accent,
        foregroundColor: SereneWakeColors.surface,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SereneWakeColors.surfaceLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SereneWakeColors.primary, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : SereneWakeColors.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SereneWakeColors.primary
            : SereneWakeColors.surfaceContainer,
      ),
    ),
  );
}
