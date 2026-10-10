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
  Future<void> updateFlashcard(Flashcard card) => _db.updateFlashcard(card);

  @override
  Future<List<Flashcard>> getFlashcardsForDeck(int deckId) =>
      _db.getFlashcardsForDeck(deckId);

  @override
  Future<List<Flashcard>> getAllFlashcards() => _db.getAllFlashcards();

  @override
  Future<List<Flashcard>> getDueReviewFlashcards({DateTime? asOf}) =>
      _db.getDueReviewFlashcards(asOf: asOf);

  @override
  Future<List<Flashcard>> getNewFlashcards({required int limit}) =>
      _db.getNewFlashcards(limit: limit);

  @override
  Future<int> countIntroducedSince(DateTime cutoff) =>
      _db.countIntroducedSince(cutoff);

  @override
  Future<List<Flashcard>> searchFlashcards(String query) =>
      _db.searchFlashcards(query);
}
