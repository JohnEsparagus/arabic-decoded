import 'package:arabic_decoded/services/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9);

  Schedule first(Grade grade) => schedule(grade: grade, isNew: true, now: now);

  test('a new card comes back sooner the harder it was', () {
    final days = [for (final g in Grade.values) first(g).interval];
    expect(days, [1, 1, 3, 16]);
    // Harder grades leave it harder.
    expect(
      first(Grade.again).difficulty,
      greaterThan(first(Grade.easy).difficulty),
    );
    expect(first(Grade.good).nextReview, DateTime(2026, 10, 20));
  });

  test('remembering it on time makes the next gap much longer', () {
    var card = first(Grade.good);
    var day = now;
    final gaps = <int>[];
    for (var i = 0; i < 5; i++) {
      final reviewed = day.add(Duration(days: card.interval));
      card = schedule(
        grade: Grade.good,
        isNew: false,
        stability: card.stability,
        difficulty: card.difficulty,
        interval: card.interval,
        lastReview: day,
        now: reviewed,
      );
      day = reviewed;
      gaps.add(card.interval);
    }
    for (var i = 1; i < gaps.length; i++) {
      expect(gaps[i], greaterThan(gaps[i - 1]), reason: '$gaps');
    }
    // A handful of good reviews reaches months, not years.
    expect(gaps.last, inInclusiveRange(60, 1000), reason: '$gaps');
  });

  test('forgetting cuts it back hard, never to more than it was', () {
    final learnt = schedule(
      grade: Grade.again,
      isNew: false,
      stability: 60,
      difficulty: 5,
      interval: 60,
      lastReview: now.subtract(const Duration(days: 60)),
      now: now,
    );
    expect(learnt.stability, lessThan(60));
    expect(learnt.interval, lessThan(15));
    expect(learnt.difficulty, greaterThan(5));
  });

  test('a card seen again the same day changes only a little', () {
    final morning = first(Grade.good);
    final again = schedule(
      grade: Grade.good,
      isNew: false,
      stability: morning.stability,
      difficulty: morning.difficulty,
      interval: morning.interval,
      lastReview: now,
      now: now.add(const Duration(hours: 3)),
    );
    expect(again.stability, closeTo(morning.stability, morning.stability));
    expect(again.interval, inInclusiveRange(1, 6));
  });

  test('a card the old scheduler set picks up from where it was', () {
    // SM-2 had it due in 30 days with a typical ease: reviewing it on time
    // as "good" should push it further out, not start it over.
    final converted = schedule(
      grade: Grade.good,
      isNew: false,
      interval: 30,
      easeFactor: 2.5,
      lastReview: now.subtract(const Duration(days: 30)),
      now: now,
    );
    expect(converted.interval, greaterThan(30));
    expect(converted.difficulty, inInclusiveRange(1, 10));
  });

  test('difficulty stays within 1 to 10 however it is graded', () {
    var card = first(Grade.again);
    for (var i = 0; i < 30; i++) {
      card = schedule(
        grade: Grade.again,
        isNew: false,
        stability: card.stability,
        difficulty: card.difficulty,
        interval: card.interval,
        lastReview: now.subtract(Duration(days: card.interval)),
        now: now,
      );
    }
    expect(card.difficulty, lessThanOrEqualTo(10));
    expect(card.interval, greaterThanOrEqualTo(1));
  });

  test('intervals read naturally on the buttons', () {
    expect(formatInterval(1), '1d');
    expect(formatInterval(10), '10d');
    expect(formatInterval(21), '3w');
    expect(formatInterval(120), '4mo');
    expect(formatInterval(400), '1.1y');
    expect(formatInterval(1200), '3y');
  });
}
