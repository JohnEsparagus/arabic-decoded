import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// The app's single [SharedPreferences] instance, obtained once in `main()`
/// before `runApp` and injected via `ProviderScope.overrides` — every
/// persisted setting below reads/writes through this rather than calling
/// `SharedPreferences.getInstance()` itself, so tests can swap in an
/// isolated instance the same way they already do for `DatabaseService`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

const _darkModeKey = 'settings.dark_mode';
const _maxNewCardsPerDayKey = 'settings.max_new_cards_per_day';
const _studyWordsKey = 'settings.study_words';
const _studyAlphabetKey = 'settings.study_alphabet';
const _dailyGoalKey = 'settings.daily_goal';
const _arabicFontKey = 'settings.arabic_font';

/// Default daily cap on never-studied cards, used until the user changes it
/// from Settings.
const defaultMaxNewCardsPerDay = 10;

/// Reasonable bounds for the new-cards-per-day setting — 0 lets someone
/// pause new material entirely while still reviewing, 100 is generous
/// enough that no one plausibly wants more in one sitting.
const minNewCardsPerDay = 0;
const maxNewCardsPerDayLimit = 100;

/// Whether night mode is on. Defaults to off (the parchment/manuscript
/// look) until the user opts in from Settings.
class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_darkModeKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_darkModeKey, value);
  }
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

/// How many never-studied cards can be introduced in a single day, across
/// every campaign combined — user-tunable from Settings.
///
/// `StudySessionNotifier` watches this provider (see
/// `study_session_provider.dart`), so changing it takes effect immediately:
/// a session that had already exhausted today's quota re-evaluates and can
/// introduce more cards the moment the cap goes up, instead of waiting
/// until tomorrow.
class MaxNewCardsPerDayNotifier extends Notifier<int> {
  @override
  int build() {
    return ref.watch(sharedPreferencesProvider).getInt(_maxNewCardsPerDayKey) ??
        defaultMaxNewCardsPerDay;
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(minNewCardsPerDay, maxNewCardsPerDayLimit);
    state = clamped;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_maxNewCardsPerDayKey, clamped);
  }
}

final maxNewCardsPerDayProvider =
    NotifierProvider<MaxNewCardsPerDayNotifier, int>(
      MaxNewCardsPerDayNotifier.new,
    );

/// Whether word and pattern cards are fed into the study queue on their
/// own, or only roots. Off by default: roots are the core of the app, and
/// words are something to opt into (or add one at a time by hand, which
/// works either way). Switching it off doesn't throw anything away: those
/// cards keep their progress and stay browsable, they just stop coming up
/// until it's switched back on. `StudySessionNotifier` watches this the same way it
/// watches the daily cap, so the queue changes straight away.
class StudyWordsNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_studyWordsKey) ??
        false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_studyWordsKey, value);
  }
}

final studyWordsProvider = NotifierProvider<StudyWordsNotifier, bool>(
  StudyWordsNotifier.new,
);

/// Whether the alphabet is part of the study queue. Off by default: most
/// people opening an app about roots can already read the script. On, the
/// 28 letters are taught before any root, and come back for review like
/// any other card.
class StudyAlphabetNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_studyAlphabetKey) ??
        false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_studyAlphabetKey, value);
  }
}

final studyAlphabetProvider = NotifierProvider<StudyAlphabetNotifier, bool>(
  StudyAlphabetNotifier.new,
);

/// The choices offered for the daily goal, and the one used until the
/// user picks.
const dailyGoalChoices = [10, 20, 30, 50];
const defaultDailyGoal = 20;

/// How many cards the user aims to study a day, reviews and new cards
/// together. It's only a target shown on the welcome card: nothing is
/// held back or forced by it (that's what the new-card cap is for).
class DailyGoalNotifier extends Notifier<int> {
  @override
  int build() {
    return ref.watch(sharedPreferencesProvider).getInt(_dailyGoalKey) ??
        defaultDailyGoal;
  }

  Future<void> set(int value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setInt(_dailyGoalKey, value);
  }
}

final dailyGoalProvider = NotifierProvider<DailyGoalNotifier, int>(
  DailyGoalNotifier.new,
);

/// Which typeface Arabic text is shown in. `ArabicDecodedApp` puts it in
/// the theme, so a change shows everywhere at once.
class ArabicFontNotifier extends Notifier<ArabicFont> {
  @override
  ArabicFont build() {
    return ArabicFont.fromName(
      ref.watch(sharedPreferencesProvider).getString(_arabicFontKey),
    );
  }

  Future<void> set(ArabicFont font) async {
    state = font;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_arabicFontKey, font.name);
  }
}

final arabicFontProvider = NotifierProvider<ArabicFontNotifier, ArabicFont>(
  ArabicFontNotifier.new,
);
