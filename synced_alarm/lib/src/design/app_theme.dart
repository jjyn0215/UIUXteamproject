import 'package:flutter/material.dart';

class SereneWakeColors {
  // Light Mode
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

  // Dark Mode
  static const backgroundDark = Color(0xFF1A1C19);
  static const surfaceDark = Color(0xFF222421);
  static const surfaceLowDark = Color(0xFF2A2D29);
  static const surfaceContainerDark = Color(0xFF323631);
  static const primaryDarkBtn = Color(0xFF96D3A4);
  static const primarySoftDark = Color(0xFF2B5035);
  static const textDark = Color(0xFFE2E3DD);
  static const mutedTextDark = Color(0xFFA1A59E);
  static const outlineDark = Color(0xFF434943);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const margin = 20.0;
}

ThemeData buildSereneWakeTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: SereneWakeColors.primary,
    brightness: brightness,
    primary: isDark
        ? SereneWakeColors.primaryDarkBtn
        : SereneWakeColors.primary,
    secondary: isDark
        ? SereneWakeColors.primaryDarkBtn
        : SereneWakeColors.accent,
    surface: isDark ? SereneWakeColors.surfaceDark : SereneWakeColors.surface,
    error: SereneWakeColors.error,
  );

  final backgroundColor = isDark
      ? SereneWakeColors.backgroundDark
      : SereneWakeColors.background;
  final textColor = isDark ? SereneWakeColors.textDark : SereneWakeColors.text;
  final surfaceColor = isDark
      ? SereneWakeColors.surfaceDark
      : SereneWakeColors.surface;
  final surfaceLowColor = isDark
      ? SereneWakeColors.surfaceLowDark
      : SereneWakeColors.surfaceLow;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark
            ? SereneWakeColors.primaryDarkBtn
            : SereneWakeColors.accent,
        foregroundColor: isDark
            ? SereneWakeColors.backgroundDark
            : SereneWakeColors.surface,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLowColor,
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
            ? (isDark ? SereneWakeColors.backgroundDark : Colors.white)
            : (isDark
                  ? SereneWakeColors.mutedTextDark
                  : SereneWakeColors.outline),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (isDark
                  ? SereneWakeColors.primaryDarkBtn
                  : SereneWakeColors.primary)
            : (isDark
                  ? SereneWakeColors.outlineDark
                  : SereneWakeColors.surfaceContainer),
      ),
    ),
  );
}
