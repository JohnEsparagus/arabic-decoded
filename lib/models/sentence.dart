/// One sentence of the corpus, with where it stands for this user. The
/// corpus is content: it's bundled with the app and can run to thousands
/// of sentences, so it lives in a table of its own that's read a page at a
/// time. A sentence only becomes a flashcard (with progress, reviews and
/// everything else a card has) once the user adds it to their queue.
class Sentence {
  final int id;
  final String arabic;
  final String english;

  /// The id of its flashcard, if the user has ever added it.
  final int? cardId;

  /// In the queue of new cards, waiting to be studied for the first time.
  final bool isQueued;

  /// Already being studied: it has been graded at least once.
  final bool isStudied;

  const Sentence({
    required this.id,
    required this.arabic,
    required this.english,
    this.cardId,
    this.isQueued = false,
    this.isStudied = false,
  });

  /// From a `sentences` row joined to its flashcard, if any (see
  /// `DatabaseService.searchSentences`).
  factory Sentence.fromMap(Map<String, Object?> map) {
    return Sentence(
      id: map['id'] as int,
      arabic: map['arabic'] as String,
      english: map['english'] as String,
      cardId: map['card_id'] as int?,
      isQueued: map['queued_at'] != null && map['is_new'] == 1,
      isStudied: map['is_new'] == 0,
    );
  }

  Sentence copyWith({int? cardId, bool? isQueued}) {
    return Sentence(
      id: id,
      arabic: arabic,
      english: english,
      cardId: isQueued == false && !isStudied ? null : cardId ?? this.cardId,
      isQueued: isQueued ?? this.isQueued,
      isStudied: isStudied,
    );
  }
}
