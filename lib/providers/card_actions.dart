import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import 'database_providers.dart';
import 'study_session_provider.dart';
import 'sync_providers.dart';

/// The ids of the cards currently picked out in the Campaigns tab's grids.
/// Holding a tile starts a selection; while there is one, tapping tiles
/// adds and removes them, and a bar of actions for the whole lot appears
/// (see `SelectionBar`).
class CardSelectionNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggle(int cardId) {
    state = state.contains(cardId)
        ? ({...state}..remove(cardId))
        : {...state, cardId};
  }

  void clear() => state = const {};
}

final cardSelectionProvider = NotifierProvider<CardSelectionNotifier, Set<int>>(
  CardSelectionNotifier.new,
);

/// The things a user can do to a card by hand, each followed by the
/// refreshes it needs so every screen showing that card catches up.
/// Screens call these rather than the repository, so none of them has to
/// remember which providers a change touches.
class CardActions {
  CardActions(this._ref);

  final WidgetRef _ref;

  /// Adds a card to the study queue, or takes it out again.
  Future<void> setQueued(Flashcard card, bool queued) async {
    await _ref.read(flashcardRepositoryProvider).setQueued(card.id!, queued);
    _refresh(queueChanged: true);
  }

  Future<void> markMastered(Flashcard card) async {
    await _ref.read(flashcardRepositoryProvider).markMastered(card.id!);
    _refresh(queueChanged: true);
  }

  /// Marks a read-once card as read, so it isn't put in front of the user
  /// again in a study session.
  Future<void> markSeen(Flashcard card) async {
    await _ref.read(flashcardRepositoryProvider).markSeen(card.id!);
    _refresh(queueChanged: true);
  }

  Future<void> reset(Flashcard card) async {
    await _ref.read(flashcardRepositoryProvider).resetFlashcard(card.id!);
    _refresh(queueChanged: true);
  }

  Future<void> setFavorite(Flashcard card, bool favorite) async {
    await _ref.read(databaseServiceProvider).setFavorite(card.id!, favorite);
    _uploadLibrary();
    _refresh();
  }

  /// Favorites and collections don't go through the repository (they
  /// aren't progress), so nothing else would nudge sync to upload a change
  /// to them. Does nothing when signed out.
  void _uploadLibrary() => _ref.read(syncProvider.notifier).push();

  Future<void> setInCollection(
    int collectionId,
    Flashcard card,
    bool inCollection,
  ) async {
    await _ref
        .read(databaseServiceProvider)
        .setInCollection(collectionId, card.id!, inCollection);
    _refreshCollections();
  }

  /// Creates a collection and returns its id.
  Future<int> createCollection(String name) async {
    final id = await _ref.read(databaseServiceProvider).createCollection(name);
    _refreshCollections();
    return id;
  }

  Future<void> deleteCollection(int collectionId) async {
    await _ref.read(databaseServiceProvider).deleteCollection(collectionId);
    _refreshCollections();
  }

  // The same actions for several cards at once (a selection), with one
  // round of refreshes at the end instead of one per card.

  /// Adds every card to the queue: new ones as the next new cards, ones
  /// already learnt as reviews for today.
  Future<void> queueAll(List<Flashcard> cards) async {
    final repository = _ref.read(flashcardRepositoryProvider);
    for (final card in cards) {
      await repository.setQueued(card.id!, true);
    }
    _refresh(queueChanged: true);
  }

  Future<void> markAllMastered(List<Flashcard> cards) async {
    final repository = _ref.read(flashcardRepositoryProvider);
    for (final card in cards) {
      await repository.markMastered(card.id!);
    }
    _refresh(queueChanged: true);
  }

  Future<void> resetAll(List<Flashcard> cards) async {
    final repository = _ref.read(flashcardRepositoryProvider);
    for (final card in cards) {
      await repository.resetFlashcard(card.id!);
    }
    _refresh(queueChanged: true);
  }

  Future<void> setAllFavorite(List<Flashcard> cards, bool favorite) async {
    final db = _ref.read(databaseServiceProvider);
    for (final card in cards) {
      await db.setFavorite(card.id!, favorite);
    }
    _uploadLibrary();
    _refresh();
  }

  Future<void> addAllToCollection(
    int collectionId,
    List<Flashcard> cards,
  ) async {
    final db = _ref.read(databaseServiceProvider);
    for (final card in cards) {
      await db.setInCollection(collectionId, card.id!, true);
    }
    _refreshCollections();
  }

  void _refreshCollections() {
    _uploadLibrary();
    _ref.invalidate(collectionsProvider);
    _ref.invalidate(collectionFlashcardsProvider);
    _ref.invalidate(cardCollectionIdsProvider);
  }

  void _refresh({bool queueChanged = false}) {
    _ref.invalidate(allFlashcardsProvider);
    _ref.invalidate(reviewLogProvider);
    _ref.invalidate(deckFlashcardsProvider);
    _ref.invalidate(dictionaryEntriesProvider);
    _ref.invalidate(collectionFlashcardsProvider);
    // Rebuilding the session is what puts a newly queued card in front of
    // the user now, and drops one that was just mastered or reset.
    if (queueChanged) _ref.invalidate(studySessionProvider);
  }
}
