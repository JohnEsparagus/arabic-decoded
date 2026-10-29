import 'package:flutter/material.dart';

import '../utils/mastery_level.dart';

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

/// The colour a mastery level is drawn in on a chart. Same hues as the
/// tile backgrounds (red, amber, green, blue, weakest to strongest) but
/// strong enough to be marks rather than washes, and a different set per
/// mode: each was checked against that mode's card surface for contrast
/// and for staying apart under colour-blindness.
Color masteryChartColor(BuildContext context, MasteryLevel level) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (level) {
    MasteryLevel.unlearned => context.colors.cardBorder,
    MasteryLevel.weak => const Color(0xFFE34948),
    MasteryLevel.learning => Color(dark ? 0xFFC98500 : 0xFFEDA100),
    MasteryLevel.strong => Color(dark ? 0xFF199E70 : 0xFF1BAF7A),
    MasteryLevel.mastered => Color(dark ? 0xFF3987E5 : 0xFF2A78D6),
  };
}

/// What a mastery level is called wherever it's named to the user.
String masteryLabel(MasteryLevel level) => switch (level) {
  MasteryLevel.unlearned => 'Not started',
  MasteryLevel.weak => 'Weak',
  MasteryLevel.learning => 'Learning',
  MasteryLevel.strong => 'Strong',
  MasteryLevel.mastered => 'Mastered',
};

/// Arabic headword styling — the same face used for every Arabic-script
/// string in the app (flashcard fronts/backs, dictionary entries). [color]
/// is required rather than defaulting to a fixed ink shade, since the right
/// shade depends on light vs. night mode — pass `context.colors.ink` (or
/// `inkMuted`, etc.) from the call site.
///
/// The typeface itself is the user's choice (see [ArabicFont]), read from
/// the theme, which is why this needs a [context].
TextStyle arabicTextStyle(
  BuildContext context, {
  required Color color,
  double fontSize = 28,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return TextStyle(
    fontFamily: Theme.of(context).extension<ArabicFontTheme>()?.font.family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

/// For English text that has Arabic in it (a lesson's "the root ف ع ل"):
/// a fallback so those words come out in the chosen Arabic typeface rather
/// than whatever the device has. Add it to the English text's style.
List<String> arabicFallback(BuildContext context) => [
  ?Theme.of(context).extension<ArabicFontTheme>()?.font.family,
];

/// The typefaces offered for Arabic text. All but [system] are bundled
/// with the app (see pubspec.yaml), so they work offline. This only
/// changes Arabic script; headings stay in Amiri, the app's own face.
enum ArabicFont {
  amiri('Amiri', 'Amiri', 'Classic book style'),
  scheherazade(
    'Scheherazade',
    'Scheherazade New',
    'Open and roomy, clear vowel marks',
  ),
  notoNaskh('Noto Naskh', 'Noto Naskh Arabic', 'Clean everyday print'),
  notoKufi('Noto Kufi', 'Noto Kufi Arabic', 'Modern and geometric'),
  system('System', null, 'Whatever this device uses');

  const ArabicFont(this.label, this.family, this.description);

  final String label;

  /// The font family to ask for, or null for the device's own.
  final String? family;
  final String description;

  static ArabicFont fromName(String? name) => ArabicFont.values.firstWhere(
    (font) => font.name == name,
    orElse: () => ArabicFont.amiri,
  );
}

/// Carries the chosen [ArabicFont] in the theme, so every widget showing
/// Arabic picks it up (and rebuilds when it changes) through
/// [arabicTextStyle] without knowing about settings.
class ArabicFontTheme extends ThemeExtension<ArabicFontTheme> {
  const ArabicFontTheme(this.font);

  final ArabicFont font;

  @override
  ArabicFontTheme copyWith({ArabicFont? font}) =>
      ArabicFontTheme(font ?? this.font);

  @override
  ArabicFontTheme lerp(ThemeExtension<ArabicFontTheme>? other, double t) =>
      other is ArabicFontTheme && t >= 0.5 ? other : this;
}

ThemeData buildAppTheme({
  required Brightness brightness,
  ArabicFont arabicFont = ArabicFont.amiri,
}) {
  final palette = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final base = ThemeData(useMaterial3: true, brightness: brightness);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.light.deepGreen,
    brightness: brightness,
  ).copyWith(secondary: palette.gold, surface: palette.parchment);

  return base.copyWith(
    extensions: [palette, ArabicFontTheme(arabicFont)],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
