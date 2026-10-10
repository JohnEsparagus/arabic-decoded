import '../models/deck.dart';
import '../models/flashcard.dart';

/// The single source of truth every provider/service reads and writes
/// decks and flashcards through, instead of talking to storage directly.
///
/// [LocalFlashcardRepository] (the only implementation today) backs this
/// with the on-device SQLite database via [DatabaseService]. A future
/// signed-in user would get a different implementation that also syncs to
/// a remote backend — nothing above this interface needs to know which
/// one it's talking to, or whether sync even exists yet.
///
/// Deliberately narrow: this only has the operations providers/services
/// actually call today (see grep results for `databaseServiceProvider`
/// before this existed). `DatabaseService.resetDatabase()` — the debug-only
/// "wipe everything" button — is intentionally NOT here: it's a local-dev
/// affordance, not something a synced implementation should have to give a
/// sane meaning to (nuking someone's cloud data from a debug button would
/// be a disaster), so callers that need it go through
/// `databaseServiceProvider` directly instead.
abstract class FlashcardRepository {
  Future<Deck> getOrCreateDeck(String name, {String? description});

  Future<void> insertFlashcard(Flashcard card);
  Future<void> updateFlashcard(Flashcard card);

  /// Replaces a card's content without touching its progress.
  Future<void> updateFlashcardContent(Flashcard card);

  /// The things a user does to one card by hand that change its progress
  /// (see "Card actions" in `DatabaseService`).
  Future<void> setQueued(int cardId, bool queued);
  Future<void> markMastered(int cardId);
  Future<void> resetFlashcard(int cardId);

  /// Marks a read-once ([CardKind.info]) card as read.
  Future<void> markSeen(int cardId);

  /// Removes a card that's no longer part of the bundled content.
  Future<void> deleteFlashcard(int cardId);

  Future<List<Flashcard>> getFlashcardsForDeck(int deckId);
  Future<List<Flashcard>> getAllFlashcards();
  Future<List<Flashcard>> getDueReviewFlashcards({
    DateTime? asOf,
    bool includeWords = true,
    bool includeLetters = true,
  });
  Future<List<Flashcard>> getNewFlashcards({
    required int limit,
    bool includeWords = true,
    bool includeLetters = true,
  });
  Future<List<Flashcard>> getQueuedFlashcards();
  Future<int> countIntroducedSince(DateTime cutoff);
  Future<List<Flashcard>> searchFlashcards(String query);
}
