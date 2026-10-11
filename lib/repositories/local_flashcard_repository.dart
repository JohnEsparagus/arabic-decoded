import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/database_service.dart';
import 'flashcard_repository.dart';

/// Backs [FlashcardRepository] with the on-device SQLite database via
/// [DatabaseService] — today's only implementation, used whether or not
/// the user is signed in. A future synced implementation would sit
/// alongside this one (reading/writing locally first, then pushing to a
/// remote source) rather than replacing it outright, since the app should
/// keep working fully offline either way.
class LocalFlashcardRepository implements FlashcardRepository {
  LocalFlashcardRepository(this._db);

  final DatabaseService _db;

  @override
  Future<Deck> getOrCreateDeck(String name, {String? description}) {
    return _db.getOrCreateDeck(name, description: description);
  }

  @override
  Future<void> insertFlashcard(Flashcard card) => _db.insertFlashcard(card);

  @override
  Future<void> insertFlashcards(List<Flashcard> cards) =>
      _db.insertFlashcards(cards);

  @override
  Future<void> updateFlashcard(Flashcard card) => _db.updateFlashcard(card);

  @override
  Future<void> updateFlashcardContent(Flashcard card) =>
      _db.updateFlashcardContent(card);

  @override
  Future<void> setQueued(int cardId, bool queued) =>
      _db.setQueued(cardId, queued);

  @override
  Future<void> markMastered(int cardId) => _db.markMastered(cardId);

  @override
  Future<void> resetFlashcard(int cardId) => _db.resetFlashcard(cardId);

  @override
  Future<void> markSeen(int cardId) => _db.markSeen(cardId);

  @override
  Future<void> deleteFlashcard(int cardId) => _db.deleteFlashcard(cardId);

  @override
  Future<List<Flashcard>> getQueuedFlashcards() => _db.getQueuedFlashcards();

  @override
  Future<List<Flashcard>> getFlashcardsForDeck(int deckId) =>
      _db.getFlashcardsForDeck(deckId);

  @override
  Future<List<Flashcard>> getAllFlashcards() => _db.getAllFlashcards();

  @override
  Future<List<Flashcard>> getDueReviewFlashcards({
    DateTime? asOf,
    bool includeWords = true,
    bool includeLetters = true,
  }) => _db.getDueReviewFlashcards(
    asOf: asOf,
    includeWords: includeWords,
    includeLetters: includeLetters,
  );

  @override
  Future<List<Flashcard>> getNewFlashcards({
    required int limit,
    bool includeWords = true,
    bool includeLetters = true,
  }) => _db.getNewFlashcards(
    limit: limit,
    includeWords: includeWords,
    includeLetters: includeLetters,
  );

  @override
  Future<int> countIntroducedSince(DateTime cutoff) =>
      _db.countIntroducedSince(cutoff);

  @override
  Future<List<Flashcard>> searchFlashcards(String query) =>
      _db.searchFlashcards(query);

  @override
  Future<int?> getSentencesVersion() => _db.getSentencesVersion();

  @override
  Future<void> replaceSentences(
    List<({String arabic, String english, String search, Set<String> keys})>
    sentences, {
    required int version,
  }) => _db.replaceSentences(sentences, version: version);
}
