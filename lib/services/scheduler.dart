/// When a card should next come up, worked out with FSRS (the Free Spaced
/// Repetition Scheduler, version 5): the algorithm Anki uses today, which
/// needs noticeably fewer reviews than the classic SM-2 for the same
/// memory.
///
/// FSRS keeps two numbers per card. **Stability** is how many days the
/// memory lasts before the chance of recalling it falls to 90%; it's also
/// the interval, since cards are scheduled to come back at exactly that
/// point. **Difficulty**, from 1 to 10, is how hard the card is for this
/// learner, and sets how quickly stability grows. Both are updated from
/// the grade and from how long it has been since the card was last seen.
///
/// The formulas and default weights are FSRS-5's, from
/// https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
library;

import 'dart:math' as math;

import '../models/flashcard.dart';

/// How well a card was recalled: the four buttons under a revealed card.
enum Grade {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Grade(this.rating);

  /// FSRS's 1-4 rating.
  final int rating;
}

/// A card's scheduling state after a review.
class Schedule {
  final double stability;
  final double difficulty;

  /// Whole days until the card is due again.
  final int interval;
  final DateTime nextReview;

  const Schedule({
    required this.stability,
    required this.difficulty,
    required this.interval,
    required this.nextReview,
  });
}

/// FSRS-5's default weights, fitted on a very large set of Anki reviews.
const _w = [
  0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, //
  1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, //
  2.9898, 0.51655, 0.6621,
];

/// The forgetting curve's shape. With these, recall is exactly 90% when
/// the days elapsed equal the stability.
const _decay = -0.5;
const _factor = 19 / 81;

/// Nothing is scheduled further out than this.
const maxIntervalDays = 36500;

/// Schedules [grade] for a card.
///
/// [stability] and [difficulty] are the card's FSRS state, null for a card
/// that has never been graded, or one last graded by the old SM-2
/// scheduler, whose state is then estimated from its [interval] and
/// [easeFactor] (see [_fromSm2]). [lastReview] is when it was last graded;
/// [now] defaults to [DateTime.now] and exists so tests can pin the clock.
Schedule schedule({
  required Grade grade,
  required bool isNew,
  double? stability,
  double? difficulty,
  int interval = 0,
  double easeFactor = 2.5,
  DateTime? lastReview,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final g = grade.rating;

  double s;
  double d;
  if (isNew) {
    s = _w[g - 1];
    d = _initialDifficulty(g);
  } else {
    var current = (stability: stability, difficulty: difficulty);
    if (current.stability == null || current.difficulty == null) {
      current = _fromSm2(interval, easeFactor);
    }
    final oldS = current.stability!;
    final oldD = current.difficulty!;
    final elapsed = lastReview == null
        ? interval
        : _daysBetween(lastReview, today);

    if (elapsed < 1) {
      // Seen again the same day: a short-term adjustment rather than a
      // full review, since there's been no time to forget.
      s = oldS * math.exp(_w[17] * (g - 3 + _w[18]));
    } else {
      final r = _retrievability(elapsed.toDouble(), oldS);
      s = g == 1
          ? math.min(_stabilityAfterLapse(oldD, oldS, r), oldS)
          : _stabilityAfterRecall(oldD, oldS, r, g);
    }
    d = _nextDifficulty(oldD, g);
  }

  s = s.clamp(0.1, maxIntervalDays.toDouble());
  // At 90% desired retention the interval is the stability itself.
  final days = s.round().clamp(1, maxIntervalDays);
  return Schedule(
    stability: s,
    difficulty: d,
    interval: days,
    nextReview: DateTime(today.year, today.month, today.day + days),
  );
}

/// How likely the card is to be recalled after [elapsed] days, given its
/// stability.
double _retrievability(double elapsed, double stability) =>
    math.pow(1 + _factor * elapsed / stability, _decay).toDouble();

double _initialDifficulty(int g) =>
    (_w[4] - math.exp(_w[5] * (g - 1)) + 1).clamp(1, 10).toDouble();

double _nextDifficulty(double d, int g) {
  final change = -_w[6] * (g - 3);
  // Damped as it nears 10, so a hard card can't run away to the ceiling.
  final damped = d + change * (10 - d) / 9;
  // And drawn gently back towards the difficulty of an "easy" new card.
  return (_w[7] * _initialDifficulty(4) + (1 - _w[7]) * damped)
      .clamp(1, 10)
      .toDouble();
}

double _stabilityAfterRecall(double d, double s, double r, int g) {
  final hardPenalty = g == 2 ? _w[15] : 1.0;
  final easyBonus = g == 4 ? _w[16] : 1.0;
  return s *
      (math.exp(_w[8]) *
              (11 - d) *
              math.pow(s, -_w[9]) *
              (math.exp(_w[10] * (1 - r)) - 1) *
              hardPenalty *
              easyBonus +
          1);
}

double _stabilityAfterLapse(double d, double s, double r) =>
    _w[11] *
    math.pow(d, -_w[12]) *
    (math.pow(s + 1, _w[13]) - 1) *
    math.exp(_w[14] * (1 - r));

/// An estimate of FSRS state for a card last scheduled by SM-2. Its
/// interval was set to roughly when it would be forgotten, which is what
/// stability measures; its ease (1.3 for the hardest cards, 2.5 for a
/// typical one, higher for easy ones) maps onto difficulty the other way
/// round.
({double? stability, double? difficulty}) _fromSm2(int interval, double ease) {
  return (
    stability: math.max(interval, 1).toDouble(),
    difficulty: (10 - (ease - 1.3) / 1.7 * 7).clamp(1, 10).toDouble(),
  );
}

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// A short label for an interval, for the grade buttons: "1d", "3w",
/// "4mo", "2y".
String formatInterval(int days) {
  if (days < 14) return '${days}d';
  if (days < 60) return '${(days / 7).round()}w';
  if (days < 365) return '${(days / 30).round()}mo';
  final years = days / 365;
  return years < 10
      ? '${years.toStringAsFixed(years < 2 ? 1 : 0)}y'
      : '${years.round()}y';
}

/// [schedule] for a card as it stands.
Schedule scheduleFor(Flashcard card, Grade grade, {DateTime? now}) {
  return schedule(
    grade: grade,
    isNew: card.isNew,
    stability: card.stability,
    difficulty: card.difficulty,
    interval: card.interval,
    easeFactor: card.easeFactor,
    lastReview: card.lastReviewedAt,
    now: now,
  );
}
