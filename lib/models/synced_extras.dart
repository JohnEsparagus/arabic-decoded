/// The two things besides card progress that sync between a user's
/// devices: their review history, and their "library" (favorites and
/// collections). See `SyncService` and
/// `supabase/migrations/20261011000000_review_log_and_library.sql`.
library;

/// One review-log entry in the shape it travels in. A card is named by
/// deck + Arabic word, as in `CardProgress`, because every device's local
/// database hands out its own ids.
class SyncedReview {
  /// The row's id on this device (when read from the local database) or
  /// on the server (when fetched from it). Never sent in either direction;
  /// it's only how the side that produced the row refers back to it.
  final int id;
  final String deckName;
  final String arabicWord;
  final DateTime at;
  final int interval;
  final bool isNew;
  final bool graded;

  const SyncedReview({
    required this.id,
    required this.deckName,
    required this.arabicWord,
    required this.at,
    required this.interval,
    required this.isNew,
    required this.graded,
  });

  /// From a `review_log` row on the server.
  factory SyncedReview.fromRemote(Map<String, dynamic> row) {
    return SyncedReview(
      id: row['id'] as int,
      deckName: row['deck_name'] as String,
      arabicWord: row['arabic_word'] as String,
      at: DateTime.parse(row['reviewed_at'] as String).toLocal(),
      interval: row['interval_days'] as int,
      isNew: row['is_new'] as bool,
      graded: row['graded'] as bool,
    );
  }

  Map<String, dynamic> toRemote({required String userId}) {
    return {
      'user_id': userId,
      'deck_name': deckName,
      'arabic_word': arabicWord,
      'reviewed_at': at.toUtc().toIso8601String(),
      'interval_days': interval,
      'is_new': isNew,
      'graded': graded,
    };
  }
}

/// A user's favorites and collections as one document, plus when it was
/// last changed. It syncs whole: whichever device changed it most recently
/// wins, the same rule a single card's progress follows.
///
/// [data] is plain JSON:
/// ```json
/// {
///   "favorites": [{"deck": "Absolute Core", "word": "ك ت ب"}],
///   "collections": [
///     {
///       "name": "Travel",
///       "created_at": 1791676800000,
///       "cards": [{"deck": "Nature", "word": "بَحْر", "added_at": 1791676800000}]
///     }
///   ]
/// }
/// ```
class LibrarySnapshot {
  final Map<String, dynamic> data;
  final DateTime updatedAt;

  const LibrarySnapshot({required this.data, required this.updatedAt});

  /// From a `user_library` row on the server.
  factory LibrarySnapshot.fromRemote(Map<String, dynamic> row) {
    return LibrarySnapshot(
      data: (row['data'] as Map).cast<String, dynamic>(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toRemote({required String userId}) {
    return {
      'user_id': userId,
      'data': data,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
