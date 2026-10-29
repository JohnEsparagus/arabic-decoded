import '../models/deck.dart';
import '../models/flashcard.dart';
import 'flashcard_repository.dart';
import 'local_flashcard_repository.dart';

/// The [FlashcardRepository] a signed-in user gets: everything still reads
/// and writes the on-device database through [LocalFlashcardRepository],
/// so the app stays fully usable offline — this only adds a nudge to
/// upload after each write that changes progress.
///
/// [onProgressChanged] is fired and forgotten rather than awaited, so
/// grading a card never waits on (or fails because of) the network.
class SyncedFlashcardRepository implements FlashcardRepository {
  SyncedFlashcardRepository(this._local, {required this.onProgressChanged});

  final LocalFlashcardRepository _local;
  final void Function() onProgressChanged;

  @override
  Future<Deck> getOrCreateDeck(String name, {String? description}) =>
      _local.getOrCreateDeck(name, description: description);

  @override
  Future<void> insertFlashcard(Flashcard card) => _local.insertFlashcard(card);

  @override
  Future<void> insertFlashcards(List<Flashcard> cards) =>
      _local.insertFlashcards(cards);

  @override
  Future<void> updateFlashcard(Flashcard card) async {
    await _local.updateFlashcard(card);
    onProgressChanged();
  }

  @override
  Future<void> updateFlashcardContent(Flashcard card) =>
      _local.updateFlashcardContent(card);

  @override
  Future<void> setQueued(int cardId, bool queued) async {
    await _local.setQueued(cardId, queued);
    onProgressChanged();
  }

  @override
  Future<void> markMastered(int cardId) async {
    await _local.markMastered(cardId);
    onProgressChanged();
  }

  @override
  Future<void> resetFlashcard(int cardId) async {
    await _local.resetFlashcard(cardId);
    onProgressChanged();
  }

  @override
  Future<void> markSeen(int cardId) async {
    await _local.markSeen(cardId);
    onProgressChanged();
  }

  @override
  Future<void> deleteFlashcard(int cardId) => _local.deleteFlashcard(cardId);

  @override
  Future<List<Flashcard>> getQueuedFlashcards() => _local.getQueuedFlashcards();

  @override
  Future<List<Flashcard>> getFlashcardsForDeck(int deckId) =>
      _local.getFlashcardsForDeck(deckId);

  @override
  Future<List<Flashcard>> getAllFlashcards() => _local.getAllFlashcards();

  @override
  Future<List<Flashcard>> getDueReviewFlashcards({
    DateTime? asOf,
    bool includeWords = true,
    bool includeLetters = true,
  }) => _local.getDueReviewFlashcards(
    asOf: asOf,
    includeWords: includeWords,
    includeLetters: includeLetters,
  );

  @override
  Future<List<Flashcard>> getNewFlashcards({
    required int limit,
    bool includeWords = true,
    bool includeLetters = true,
    bool quranFirst = false,
  }) => _local.getNewFlashcards(
    limit: limit,
    includeWords: includeWords,
    includeLetters: includeLetters,
    quranFirst: quranFirst,
  );

  @override
  Future<int> countIntroducedSince(DateTime cutoff) =>
      _local.countIntroducedSince(cutoff);

  @override
  Future<List<Flashcard>> searchFlashcards(String query) =>
      _local.searchFlashcards(query);

  @override
  Future<int?> getSentencesVersion() => _local.getSentencesVersion();

  @override
  Future<void> replaceSentences(
    List<({String arabic, String english, String search, Set<String> keys})>
    sentences, {
    required int version,
  }) => _local.replaceSentences(sentences, version: version);

  @override
  Future<void> moveCard({
    required String fromDeck,
    required String from,
    required String toDeck,
    required String to,
  }) => _local.moveCard(fromDeck: fromDeck, from: from, toDeck: toDeck, to: to);

  @override
  Future<void> setQuranRanks(Map<String, int> ranks) =>
      _local.setQuranRanks(ranks);
}
