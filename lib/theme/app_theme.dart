import 'package:flutter/material.dart';

/// Family name declared in pubspec.yaml for the bundled Amiri font files
/// (assets/fonts/) — a classic Naskh-style Arabic typeface, SIL OFL 1.1.
const _amiri = 'Amiri';

/// A warm, old-manuscript palette: parchment paper, deep emerald ink, and a
/// touch of gold leaf — evoking classic Arabic book design rather than a
/// generic Material app. Registered on [ThemeData] as a [ThemeExtension] so
/// widgets read colors through [AppColorsX.colors] and automatically follow
/// light/night mode, instead of every widget hardcoding one fixed palette.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.parchment,
    required this.parchmentDark,
    required this.ink,
    required this.inkMuted,
    required this.deepGreen,
    required this.gold,
    required this.goldSoft,
    required this.cardBorder,
    required this.cardSurface,
    required this.masteryWeak,
    required this.masteryLearning,
    required this.masteryStrong,
    required this.masteryMastered,
  });

  final Color parchment;
  final Color parchmentDark;
  final Color ink;
  final Color inkMuted;
  final Color deepGreen;
  final Color gold;
  final Color goldSoft;
  final Color cardBorder;

  /// Plain card/surface background — white paper on the light palette, a
  /// dark warm brown standing in for it on night mode.
  final Color cardSurface;

  // Mastery-level backgrounds for root preview cards (see MasteryLevel) —
  // soft enough to keep the Arabic text readable, distinct enough to read
  // as a progression from weak (red) to mastered (blue) at a glance.
  final Color masteryWeak;
  final Color masteryLearning;
  final Color masteryStrong;
  final Color masteryMastered;

  static const light = AppColors(
    parchment: Color(0xFFF7EFDC),
    parchmentDark: Color(0xFFEDE0BF),
    ink: Color(0xFF2B2116),
    inkMuted: Color(0xFF6B6152),
    deepGreen: Color(0xFF1F5C4A),
    gold: Color(0xFFC9A24B),
    goldSoft: Color(0xFFE4D3A0),
    cardBorder: Color(0xFFDCC79A),
    cardSurface: Colors.white,
    masteryWeak: Color(0xFFFFCDD2),
    masteryLearning: Color(0xFFFFE0B2),
    masteryStrong: Color(0xFFC8E6C9),
    masteryMastered: Color(0xFFBBDEFB),
  );

  /// Same manuscript feel, re-tuned for a dark room: ink-black "paper",
  /// parchment-toned text, and brighter accent colors so gold/green/mastery
  /// tones keep enough contrast against the dark surfaces.
  static const dark = AppColors(
    parchment: Color(0xFF1B1712),
    parchmentDark: Color(0xFF262019),
    ink: Color(0xFFEDE3D0),
    inkMuted: Color(0xFFA79A83),
    deepGreen: Color(0xFF4FB995),
    gold: Color(0xFFD9B872),
    goldSoft: Color(0xFF4A3D25),
    cardBorder: Color(0xFF443925),
    cardSurface: Color(0xFF272119),
    masteryWeak: Color(0xFF5C2B2B),
    masteryLearning: Color(0xFF5C4420),
    masteryStrong: Color(0xFF265240),
    masteryMastered: Color(0xFF203F55),
  );

  @override
  AppColors copyWith({
    Color? parchment,
    Color? parchmentDark,
    Color? ink,
    Color? inkMuted,
    Color? deepGreen,
    Color? gold,
    Color? goldSoft,
    Color? cardBorder,
    Color? cardSurface,
    Color? masteryWeak,
    Color? masteryLearning,
    Color? masteryStrong,
    Color? masteryMastered,
  }) {
    return AppColors(
      parchment: parchment ?? this.parchment,
      parchmentDark: parchmentDark ?? this.parchmentDark,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      deepGreen: deepGreen ?? this.deepGreen,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      cardBorder: cardBorder ?? this.cardBorder,
      cardSurface: cardSurface ?? this.cardSurface,
      masteryWeak: masteryWeak ?? this.masteryWeak,
      masteryLearning: masteryLearning ?? this.masteryLearning,
      masteryStrong: masteryStrong ?? this.masteryStrong,
      masteryMastered: masteryMastered ?? this.masteryMastered,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      parchment: Color.lerp(parchment, other.parchment, t)!,
      parchmentDark: Color.lerp(parchmentDark, other.parchmentDark, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      deepGreen: Color.lerp(deepGreen, other.deepGreen, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      masteryWeak: Color.lerp(masteryWeak, other.masteryWeak, t)!,
      masteryLearning: Color.lerp(masteryLearning, other.masteryLearning, t)!,
      masteryStrong: Color.lerp(masteryStrong, other.masteryStrong, t)!,
      masteryMastered: Color.lerp(masteryMastered, other.masteryMastered, t)!,
    );
  }
}

/// Shorthand for `Theme.of(context).extension<AppColors>()!` — every widget
/// that needs a palette color goes through this so it follows light/night
/// mode automatically instead of hardcoding one fixed palette.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Arabic headword styling — the same face used for every Arabic-script
/// string in the app (flashcard fronts/backs, dictionary entries). [color]
/// is required rather than defaulting to a fixed ink shade, since the right
/// shade depends on light vs. night mode — pass `context.colors.ink` (or
/// `inkMuted`, etc.) from the call site.
TextStyle arabicTextStyle({
  required Color color,
  double fontSize = 28,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return TextStyle(
    fontFamily: _amiri,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final palette = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final base = ThemeData(useMaterial3: true, brightness: brightness);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.light.deepGreen,
    brightness: brightness,
  ).copyWith(secondary: palette.gold, surface: palette.parchment);

  return base.copyWith(
    extensions: [palette],
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.parchment,
    textTheme: base.textTheme
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: _amiri,
            color: palette.ink,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontFamily: _amiri,
            color: palette.ink,
          ),
        )
        .apply(bodyColor: palette.ink, displayColor: palette.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.parchment,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _amiri,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: palette.ink,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.cardSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder, width: 1.2),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.cardBorder, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.cardSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.deepGreen, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.deepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.parchmentDark,
      elevation: 0,
      height: 68,
      indicatorColor: palette.gold.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? palette.deepGreen : palette.inkMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? palette.deepGreen : palette.inkMuted,
        );
      }),
    ),
  );
}
