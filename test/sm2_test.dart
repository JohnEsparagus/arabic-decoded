import 'package:arabic_decoded/services/sm2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSM2', () {
    test('first successful review schedules a 1-day interval', () {
      final result = computeSM2(
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        quality: Grade.good.quality,
        now: DateTime(2026, 1, 1),
      );

      expect(result.repetitions, 1);
      expect(result.interval, 1);
      expect(result.nextReview, DateTime(2026, 1, 2));
    });

    test('second successful review schedules a 6-day interval', () {
      final result = computeSM2(
        easeFactor: 2.5,
        interval: 1,
        repetitions: 1,
        quality: Grade.good.quality,
        now: DateTime(2026, 1, 1),
      );

      expect(result.repetitions, 2);
      expect(result.interval, 6);
    });

    test('third+ successful review multiplies interval by ease factor', () {
      final result = computeSM2(
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
        quality: Grade.good.quality,
        now: DateTime(2026, 1, 1),
      );

      expect(result.repetitions, 3);
      expect(result.interval, 15); // round(6 * 2.5)
    });

    test('failing a card resets repetitions and interval to 1 day', () {
      final result = computeSM2(
        easeFactor: 2.5,
        interval: 15,
        repetitions: 3,
        quality: Grade.again.quality,
        now: DateTime(2026, 1, 1),
      );

      expect(result.repetitions, 0);
      expect(result.interval, 1);
    });

    test('ease factor never drops below 1.3', () {
      var ease = 1.3;
      // Repeated "again" grades should floor out rather than go negative.
      for (var i = 0; i < 10; i++) {
        final result = computeSM2(
          easeFactor: ease,
          interval: 1,
          repetitions: 0,
          quality: Grade.again.quality,
        );
        ease = result.easeFactor;
      }
      expect(ease, 1.3);
    });

    test('an easy grade increases the ease factor', () {
      final result = computeSM2(
        easeFactor: 2.5,
        interval: 1,
        repetitions: 1,
        quality: Grade.easy.quality,
      );
      expect(result.easeFactor, greaterThan(2.5));
    });
  });
}
