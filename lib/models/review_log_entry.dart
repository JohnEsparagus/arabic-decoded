/// One moment at which a card's progress changed: what its interval was
/// from then on, and whether it was (back to being) a new card. The whole
/// log, replayed in order, gives every card's mastery level on any past
/// day, which is what the learning stats are drawn from.
class ReviewLogEntry {
  final int cardId;
  final DateTime at;

  /// Days until the card was next due, as of this entry.
  final int interval;

  /// True if this entry left the card never-studied (a reset).
  final bool isNew;

  /// True if this was the user grading the card in a study session, as
  /// opposed to marking it mastered by hand, a reset, or progress arriving
  /// from another device. Only these count as "reviews" and toward a
  /// streak.
  final bool graded;

  const ReviewLogEntry({
    required this.cardId,
    required this.at,
    required this.interval,
    this.isNew = false,
    this.graded = false,
  });

  factory ReviewLogEntry.fromMap(Map<String, Object?> map) {
    return ReviewLogEntry(
      cardId: map['card_id'] as int,
      at: DateTime.fromMillisecondsSinceEpoch(map['at'] as int),
      interval: map['interval'] as int,
      isNew: (map['is_new'] as int) != 0,
      graded: (map['graded'] as int) != 0,
    );
  }
}
