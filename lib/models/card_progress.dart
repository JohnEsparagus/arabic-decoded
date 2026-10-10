/// One card's SM-2 state in the shape that gets synced between devices —
/// the progress half of a [Flashcard], without any of its content.
///
/// Cards are identified by [deckName] + [arabicWord] rather than
/// [Flashcard.id], because every device's local database hands out its own
/// ids. That's the same pair `ContentImporter` already uses to recognise a
/// card it has imported before.
class CardProgress {
  final String deckName;
  final String arabicWord;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;
  final DateTime? introducedAt;

  /// When the card was last graded. Sync is last-write-wins on this.
  final DateTime updatedAt;

  const CardProgress({
    required this.deckName,
    required this.arabicWord,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
    this.introducedAt,
    required this.updatedAt,
  });

  /// From a `card_progress` row (see `supabase/migrations/`).
  factory CardProgress.fromRemote(Map<String, dynamic> row) {
    final introducedAt = row['introduced_at'] as String?;
    return CardProgress(
      deckName: row['deck_name'] as String,
      arabicWord: row['arabic_word'] as String,
      easeFactor: (row['ease_factor'] as num).toDouble(),
      interval: row['interval_days'] as int,
      repetitions: row['repetitions'] as int,
      nextReview: DateTime.parse(row['next_review'] as String).toLocal(),
      introducedAt: introducedAt == null
          ? null
          : DateTime.parse(introducedAt).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toRemote({required String userId}) {
    return {
      'user_id': userId,
      'deck_name': deckName,
      'arabic_word': arabicWord,
      'ease_factor': easeFactor,
      'interval_days': interval,
      'repetitions': repetitions,
      'next_review': nextReview.toUtc().toIso8601String(),
      'introduced_at': introducedAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
