import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
