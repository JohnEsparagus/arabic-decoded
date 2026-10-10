import '../models/flashcard.dart';

/// Buckets a flashcard's SM-2 [Flashcard.interval] (days until it's next
/// due) into a coarse mastery level, so the campaign browser can give an
/// at-a-glance signal of how well-known each root is without showing raw
/// interval numbers.
enum MasteryLevel {
  /// Never studied yet — [Flashcard.isNew] is still true.
  unlearned,

  /// Failed recently or just introduced: due back within a week.
  weak,

  /// A few successful reviews in: due back within a few weeks.
  learning,

  /// Well-established: due back within a few months.
  strong,

  /// Long-term memory: due back in months or more.
  mastered,
}

/// Thresholds follow SM-2's natural growth curve (interval roughly
/// multiplies by the ease factor, ~2.5x, each successful review), so each
/// bucket lines up with a handful of consecutive repetitions rather than
/// splitting one apart.
MasteryLevel masteryLevelOf(Flashcard card) =>
    masteryLevelFor(isNew: card.isNew, interval: card.interval);

/// The same buckets from the two numbers they depend on, for when there's
/// no [Flashcard] to hand — a past entry in the review log, say.
MasteryLevel masteryLevelFor({required bool isNew, required int interval}) {
  if (isNew) return MasteryLevel.unlearned;
  final days = interval;
  if (days <= 7) return MasteryLevel.weak;
  if (days <= 30) return MasteryLevel.learning;
  if (days <= 90) return MasteryLevel.strong;
  return MasteryLevel.mastered;
}
