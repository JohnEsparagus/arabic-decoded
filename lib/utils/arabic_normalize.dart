/// Diacritics (tashkeel/harakat, U+064B-U+065F and U+0670), Quranic
/// annotation signs (U+06D6-U+06ED) and tatweel (U+0640) — marks that are
/// meaningful for pronunciation but should be ignored for search, e.g.
/// "كَتَبَ" should match a search for "كتب".
final RegExp _diacritics = RegExp(
  '[ً-ٰٟۖ-ۭـ]',
);

/// Maps visually/phonetically related letter variants onto one canonical
/// form so a search for "اكتب" also matches "أكتب" or "إكتب".
final Map<String, String> _letterVariants = {
  'آ': 'ا', // آ (alef madda) -> ا
  'أ': 'ا', // أ (alef hamza above) -> ا
  'إ': 'ا', // إ (alef hamza below) -> ا
  'ٱ': 'ا', // ٱ (alef wasla) -> ا
  'ى': 'ي', // ى (alef maksura) -> ي
  'ة': 'ه', // ة (ta marbuta) -> ه
};

/// Normalizes Arabic text for search/comparison: strips diacritics and
/// tatweel, folds common letter variants (alef forms, ya/alef-maksura,
/// ta-marbuta/ha) to one canonical spelling, and collapses whitespace.
///
/// This is intentionally a plain-Dart, dependency-free implementation so
/// there's no third-party package to keep in sync — the rules rarely change
/// and are cheap to run over an in-memory list of flashcards.
String normalizeArabic(String input) {
  var result = input.trim().replaceAll(_diacritics, '');
  for (final entry in _letterVariants.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  result = result.replaceAll(RegExp(r'\s+'), ' ');
  return result.toLowerCase();
}
