import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/models/review_log_entry.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/utils/learning_stats.dart';
import 'package:arabic_decoded/utils/mastery_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final now = DateTime(2026, 10, 11, 15);

  ReviewLogEntry entry(
    int card,
    DateTime at,
    int interval, {
    bool isNew = false,
    bool graded = true,
  }) => ReviewLogEntry(
    cardId: card,
    at: at,
    interval: interval,
    isNew: isNew,
    graded: graded,
  );

  test('each bucket shows where every card stood when it ended', () {
    final stats = buildLearningStats(
      [
        // Card 1: weak three days ago, learning yesterday.
        entry(1, DateTime(2026, 10, 8, 9), 1),
        entry(1, DateTime(2026, 10, 10, 9), 10),
        // Card 2: introduced and mastered by hand today.
        entry(2, DateTime(2026, 10, 11, 8), 180, graded: false),
      ],
      scale: StatsScale.days,
      now: now,
    );

    // The chart starts on the day of the first entry, not 30 days back.
    expect(stats.buckets.map((b) => b.start.day), [8, 9, 10, 11]);
    expect(stats.buckets.last.start, DateTime(2026, 10, 11));
    final byDay = {for (final b in stats.buckets) b.start.day: b};
    expect(byDay[8]!.counts[MasteryLevel.weak], 1);
    expect(byDay[9]!.counts[MasteryLevel.weak], 1); // carried forward
    expect(byDay[10]!.counts[MasteryLevel.weak], 0);
    expect(byDay[10]!.counts[MasteryLevel.learning], 1);
    expect(stats.latest.counts[MasteryLevel.mastered], 1);
    expect(stats.latest.total, 2);

    // Only grading counts as a review.
    expect(byDay[8]!.reviews, 1);
    expect(byDay[9]!.reviews, 0);
    expect(stats.latest.reviews, 0);
  });

  test('a reset takes the card back out of the totals', () {
    final stats = buildLearningStats(
      [
        entry(1, DateTime(2026, 10, 9), 40),
        entry(1, DateTime(2026, 10, 10), 0, isNew: true, graded: false),
      ],
      scale: StatsScale.days,
      now: now,
    );
    final byDay = {for (final b in stats.buckets) b.start.day: b};
    expect(byDay[9]!.counts[MasteryLevel.strong], 1);
    expect(byDay[10]!.total, 0);
  });

  test('history older than the window still counts toward the totals', () {
    final stats = buildLearningStats(
      [entry(1, DateTime(2020, 1, 1), 200)],
      scale: StatsScale.days,
      now: now,
    );
    expect(stats.buckets, hasLength(StatsScale.days.maxBuckets));
    expect(stats.buckets.first.counts[MasteryLevel.mastered], 1);
    expect(stats.buckets.first.reviews, 0);
  });

  test('months and years bucket on calendar boundaries', () {
    final log = [
      entry(1, DateTime(2025, 12, 31, 23), 1),
      entry(2, DateTime(2026, 1, 1), 1),
    ];
    final months = buildLearningStats(log, scale: StatsScale.months, now: now);
    expect(months.buckets, hasLength(11)); // December 2025 to October 2026
    expect(months.buckets.first.start, DateTime(2025, 12));
    expect(months.buckets.last.start, DateTime(2026, 10));
    expect(months.buckets[0].total, 1); // December 2025
    expect(months.buckets[1].total, 2); // January 2026

    // Years start at the year they started, not a fixed span back.
    final years = buildLearningStats(log, scale: StatsScale.years, now: now);
    expect(years.buckets.map((b) => b.start.year), [2025, 2026]);
    expect(years.buckets[0].total, 1);
    expect(years.buckets[1].total, 2);

    // Nothing studied yet: just the current period.
    final empty = buildLearningStats([], scale: StatsScale.years, now: now);
    expect(empty.buckets.single.start, DateTime(2026));
  });

  test('the streak counts back from today, or from yesterday if today '
      'hasn\'t been studied yet', () {
    LearningStats on(List<int> days) => buildLearningStats(
      [for (final day in days) entry(day, DateTime(2026, 10, day, 12), 1)],
      scale: StatsScale.days,
      now: now,
    );

    expect(on([9, 10, 11]).dayStreak, 3);
    expect(on([9, 10]).dayStreak, 2);
    expect(on([7, 9]).dayStreak, 0);
    expect(on([7, 8, 10, 11]).dayStreak, 2);
    expect(on([]).dayStreak, 0);
  });

  test('today counts only cards graded today', () {
    final log = [
      entry(1, DateTime(2026, 10, 10, 23, 59), 1),
      entry(2, DateTime(2026, 10, 11, 0, 0), 1),
      entry(3, DateTime(2026, 10, 11, 9), 180, graded: false),
      entry(4, DateTime(2026, 10, 11, 14), 1),
    ];
    expect(reviewsToday(log, now), 2);
    expect(reviewsToday([], now), 0);
  });

  test('the database logs grading, mastering and resetting', () async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');
    final id = await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: 'ك ت ب',
        englishTranslation: 'Writing',
        exampleSentence: '',
        deckId: deck.id!,
      ),
    );
    final card = (await db.getAllFlashcards()).single;
    expect(await db.getReviewLog(), isEmpty);

    await db.updateFlashcard(card.copyWith(isNew: false, interval: 6));
    await db.markMastered(id);
    await db.resetFlashcard(id);

    final log = await db.getReviewLog();
    expect(log.map((e) => e.interval), [6, 180, 0]);
    expect(log.map((e) => e.graded), [true, false, false]);
    expect(log.map((e) => e.isNew), [false, false, true]);
  });
}
