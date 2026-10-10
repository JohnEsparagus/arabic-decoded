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
  Future<void> updateFlashcard(Flashcard card) async {
    await _local.updateFlashcard(card);
    onProgressChanged();
  }

  @override
  Future<List<Flashcard>> getFlashcardsForDeck(int deckId) =>
      _local.getFlashcardsForDeck(deckId);

  @override
  Future<List<Flashcard>> getAllFlashcards() => _local.getAllFlashcards();

  @override
  Future<List<Flashcard>> getDueReviewFlashcards({DateTime? asOf}) =>
      _local.getDueReviewFlashcards(asOf: asOf);

  @override
  Future<List<Flashcard>> getNewFlashcards({required int limit}) =>
      _local.getNewFlashcards(limit: limit);

  @override
  Future<int> countIntroducedSince(DateTime cutoff) =>
      _local.countIntroducedSince(cutoff);

  @override
  Future<List<Flashcard>> searchFlashcards(String query) =>
      _local.searchFlashcards(query);
}
