/// The classic SuperMemo-2 (SM-2) spaced repetition algorithm.
library;

/// How well the user recalled a card, mapped onto the SM-2 0-5 quality
/// scale. Only 4 buttons are exposed in the UI (Anki-style) rather than
/// the full 6-point scale, which is friendlier without changing the math.
enum Grade {
  again(1),
  hard(3),
  good(4),
  easy(5);

  const Grade(this.quality);
  final int quality;
}

class SM2Result {
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;

  const SM2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
  });
}

/// Computes the next ease factor, interval (in days), repetition count and
/// due date for a card, given how well it was just recalled.
///
/// [quality] must be in the 0-5 range used by SM-2 (0 = total blackout,
/// 5 = perfect recall). [now] defaults to [DateTime.now] and exists so
/// tests can pin the clock.
SM2Result computeSM2({
  required double easeFactor,
  required int interval,
  required int repetitions,
  required int quality,
  DateTime? now,
}) {
  assert(quality >= 0 && quality <= 5, 'quality must be between 0 and 5');

  var newEaseFactor =
      easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (newEaseFactor < 1.3) newEaseFactor = 1.3;

  int newRepetitions;
  int newInterval;
  if (quality < 3) {
    // Failed recall: restart the learning sequence but keep the ease factor
    // penalty above, so the card gets easier to schedule next time.
    newRepetitions = 0;
    newInterval = 1;
  } else {
    newRepetitions = repetitions + 1;
    if (newRepetitions == 1) {
      newInterval = 1;
    } else if (newRepetitions == 2) {
      newInterval = 6;
    } else {
      newInterval = (interval * newEaseFactor).round();
    }
  }

  final today = now ?? DateTime.now();
  final nextReview = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: newInterval));

  return SM2Result(
    easeFactor: newEaseFactor,
    interval: newInterval,
    repetitions: newRepetitions,
    nextReview: nextReview,
  );
}
