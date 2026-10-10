import '../models/review_log_entry.dart';
import 'mastery_level.dart';

/// How wide each bar of the stats chart is, and the most bars it shows.
/// The chart starts at the period the user first studied in, so there are
/// fewer bars than [maxBuckets] until they've been at it that long; after
/// that it's the most recent [maxBuckets].
enum StatsScale {
  /// A bar per day, up to the last 30.
  days(30),

  /// A bar per month, up to the last 12.
  months(12),

  /// A bar per year, up to the last 10.
  years(10);

  const StatsScale(this.maxBuckets);

  final int maxBuckets;

  /// How many of this scale's periods lie between [from] and [to]: 0 if
  /// they're in the same one, 1 if [to] is in the next, and so on. Days
  /// are counted on the calendar (via UTC dates, which have no clock
  /// changes to throw a day off), not as 24-hour spans.
  int periodsBetween(DateTime from, DateTime to) => switch (this) {
    StatsScale.days => DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays,
    StatsScale.months => (to.year - from.year) * 12 + to.month - from.month,
    StatsScale.years => to.year - from.year,
  };
}

/// The levels a card being studied can be at, lowest first. (A card that
/// is [MasteryLevel.unlearned] isn't being studied, so it isn't counted.)
const studiedLevels = [
  MasteryLevel.weak,
  MasteryLevel.learning,
  MasteryLevel.strong,
  MasteryLevel.mastered,
];

/// One bar of the chart: a day, month or year.
class StatsBucket {
  /// The period covered, [start] inclusive to [end] exclusive.
  final DateTime start;
  final DateTime end;

  /// How many cards were at each level when the period ended (or right
  /// now, for the period still in progress).
  final Map<MasteryLevel, int> counts;

  /// How many cards were graded during the period.
  final int reviews;

  const StatsBucket({
    required this.start,
    required this.end,
    required this.counts,
    required this.reviews,
  });

  /// Every card being studied at the end of the period.
  int get total => counts.values.fold(0, (sum, count) => sum + count);
}

class LearningStats {
  final StatsScale scale;
  final List<StatsBucket> buckets;

  /// How many days in a row, up to today, at least one card was graded. A
  /// streak still counts if today's session hasn't happened yet.
  final int dayStreak;

  const LearningStats({
    required this.scale,
    required this.buckets,
    required this.dayStreak,
  });

  /// Where things stand now.
  StatsBucket get latest => buckets.last;
}

/// Turns the review log into a chart's worth of buckets at [scale], ending
/// with the period [now] falls in.
///
/// [log] must be oldest first. This is one pass over it: the level of
/// every card is tracked as entries go by, and the running totals are
/// copied out each time a bucket's end is passed. So the cost is the size
/// of the log plus the number of buckets, however far back the log goes.
LearningStats buildLearningStats(
  List<ReviewLogEntry> log, {
  required StatsScale scale,
  required DateTime now,
}) {
  // From the period of the very first entry up to now, capped at the
  // scale's maximum. With nothing studied yet that's just the current one.
  final sinceStart = log.isEmpty ? 0 : scale.periodsBetween(log.first.at, now);
  final bucketCount = (sinceStart + 1).clamp(1, scale.maxBuckets);
  final starts = _bucketStarts(scale, now, bucketCount);

  final levelOfCard = <int, MasteryLevel>{};
  final counts = {for (final level in studiedLevels) level: 0};
  final buckets = <StatsBucket>[];
  var next = 0;

  for (var i = 0; i < bucketCount; i++) {
    final start = starts[i];
    final end = starts[i + 1];
    var reviews = 0;
    while (next < log.length && log[next].at.isBefore(end)) {
      final entry = log[next++];
      final level = masteryLevelFor(
        isNew: entry.isNew,
        interval: entry.interval,
      );
      final previous = levelOfCard[entry.cardId];
      if (previous != null) counts[previous] = counts[previous]! - 1;
      if (level == MasteryLevel.unlearned) {
        levelOfCard.remove(entry.cardId);
      } else {
        levelOfCard[entry.cardId] = level;
        counts[level] = counts[level]! + 1;
      }
      // Entries from before the first bucket set the starting totals but
      // aren't this bucket's reviews.
      if (entry.graded && !entry.at.isBefore(start)) reviews++;
    }
    buckets.add(
      StatsBucket(
        start: start,
        end: end,
        counts: Map.unmodifiable(Map.of(counts)),
        reviews: reviews,
      ),
    );
  }

  return LearningStats(
    scale: scale,
    buckets: buckets,
    dayStreak: dayStreak(log, now),
  );
}

/// The start of each of [count] buckets, plus one more: the end of the
/// last. Built
/// with the [DateTime] constructor, which rolls months and days over by
/// itself and keeps to local midnight across clock changes.
List<DateTime> _bucketStarts(StatsScale scale, DateTime now, int count) {
  return [
    for (var back = count - 1; back >= -1; back--)
      switch (scale) {
        StatsScale.days => DateTime(now.year, now.month, now.day - back),
        StatsScale.months => DateTime(now.year, now.month - back),
        StatsScale.years => DateTime(now.year - back),
      },
  ];
}

/// How many cards were graded on the calendar day [now] falls in.
int reviewsToday(List<ReviewLogEntry> log, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var count = 0;
  // Newest entries are at the end, so stop at the first one from before
  // today instead of walking the whole history.
  for (final entry in log.reversed) {
    if (entry.at.isBefore(today)) break;
    if (entry.graded) count++;
  }
  return count;
}

/// How many days in a row, up to [now], at least one card was graded. Not
/// having studied yet today doesn't break a streak.
int dayStreak(List<ReviewLogEntry> log, DateTime now) {
  final studiedDays = {
    for (final entry in log)
      if (entry.graded) DateTime(entry.at.year, entry.at.month, entry.at.day),
  };
  var day = DateTime(now.year, now.month, now.day);
  // Not having studied yet today doesn't break a streak; start from
  // yesterday in that case.
  if (!studiedDays.contains(day)) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (studiedDays.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
