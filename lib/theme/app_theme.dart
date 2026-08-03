import 'package:flutter/material.dart';

/// Family name declared in pubspec.yaml for the bundled Amiri font files
/// (assets/fonts/) — a classic Naskh-style Arabic typeface, SIL OFL 1.1.
const _amiri = 'Amiri';

/// A warm, old-manuscript palette: parchment paper, deep emerald ink, and a
/// touch of gold leaf — evoking classic Arabic book design rather than a
/// generic Material app.
abstract final class AppColors {
  static const parchment = Color(0xFFF7EFDC);
  static const parchmentDark = Color(0xFFEDE0BF);
  static const ink = Color(0xFF2B2116);
  static const inkMuted = Color(0xFF6B6152);
  static const deepGreen = Color(0xFF1F5C4A);
  static const gold = Color(0xFFC9A24B);
  static const goldSoft = Color(0xFFE4D3A0);
  static const cardBorder = Color(0xFFDCC79A);
}

/// Arabic headword styling — the same face used for every Arabic-script
/// string in the app (flashcard fronts/backs, dictionary entries).
TextStyle arabicTextStyle({
  double fontSize = 28,
  FontWeight fontWeight = FontWeight.w600,
  Color color = AppColors.ink,
}) {
  return TextStyle(
    fontFamily: _amiri,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.deepGreen,
    brightness: Brightness.light,
  ).copyWith(secondary: AppColors.gold, surface: AppColors.parchment);

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.parchment,
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: _amiri,
        color: AppColors.ink,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFamily: _amiri,
        color: AppColors.ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.parchment,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: _amiri,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.parchmentDark,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.gold.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.deepGreen : AppColors.inkMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.deepGreen : AppColors.inkMuted,
        );
      }),
    ),
  );
}
