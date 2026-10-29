import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_collection.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/review_log_entry.dart';
import '../repositories/flashcard_repository.dart';
import '../repositories/local_flashcard_repository.dart';
import '../repositories/synced_flashcard_repository.dart';
import '../services/content_importer.dart';
import '../services/database_service.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

/// The raw on-device SQLite connection. Only [flashcardRepositoryProvider],
/// sync (see `sync_providers.dart`) and the debug-only "reset all
/// progress" button in the Campaigns tab should need this directly —
/// everything else should go through [flashcardRepositoryProvider] instead,
/// so it doesn't care whether data is local-only or synced.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

/// What every provider/service actually reads and writes decks/flashcards
/// through. Signed out, that's plain [LocalFlashcardRepository]; signed
/// in, it's wrapped in a [SyncedFlashcardRepository] that also uploads
/// each newly graded card. Either way the data itself is read from and
/// written to the same on-device database.
final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  final local = LocalFlashcardRepository(ref.watch(databaseServiceProvider));
  if (ref.watch(currentUserIdProvider) == null) return local;
  return SyncedFlashcardRepository(
    local,
    onProgressChanged: () => ref.read(syncProvider.notifier).push(),
  );
});

final contentImporterProvider = Provider<ContentImporter>((ref) {
  return ContentImporter(ref.watch(flashcardRepositoryProvider));
});

/// Imports every campaign listed in `lib/config/campaign_sources.dart`
/// (creating each one's deck if needed) and returns them in campaign
/// order. Safe to watch from multiple places — importing is a no-op for
/// words that are already stored, so this can run on every screen that
/// needs campaign data without duplicating anything.
final campaignDecksProvider = FutureProvider<List<Deck>>((ref) async {
  final importer = ref.watch(contentImporterProvider);
  return importer.importAll();
});

/// The sentence corpus, loaded into the database (once per edition; see
/// `ContentImporter.importSentences`). Started in the background as soon
/// as the app is up, by `RootShell`, and awaited by anything that reads
/// sentences, so the cards don't wait on thousands of sentences to load.
final sentenceCorpusProvider = FutureProvider<void>((ref) async {
  await ref.watch(campaignDecksProvider.future);
  await ref.watch(contentImporterProvider).importSentences();
});

/// Current text in the dictionary tab's search field.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Which kind of card the dictionary tab is narrowed down to; null shows
/// roots, words and patterns together. Starts on roots, the core of the
/// app, rather than on several hundred entries of every kind mixed up.
class DictionaryKindNotifier extends Notifier<CardKind?> {
  @override
  CardKind? build() => CardKind.root;

  void set(CardKind? value) => state = value;
}

final dictionaryKindProvider =
    NotifierProvider<DictionaryKindNotifier, CardKind?>(
      DictionaryKindNotifier.new,
    );

/// Every flashcard across every deck when the search field is empty
/// (browsing mode), or the matching subset once the user types something.
final dictionaryEntriesProvider = FutureProvider<List<Flashcard>>((ref) async {
  // Make sure every campaign's words are imported, even if the user opens
  // the Dictionary tab before ever visiting Campaign.
  await ref.watch(campaignDecksProvider.future);

  final repository = ref.watch(flashcardRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final kind = ref.watch(dictionaryKindProvider);
  final entries = query.trim().isEmpty
      ? await repository.getAllFlashcards()
      : await repository.searchFlashcards(query);
  // Sentences have a screen of their own, and read-once cards aren't
  // something to look up.
  return entries
      .where(
        (card) =>
            card.kind != CardKind.sentence &&
            card.kind != CardKind.info &&
            (kind == null || card.kind == kind),
      )
      .toList();
});

/// Every card there is, regardless of what's typed in the search field —
/// what a card's links (a root's words, a word's root and pattern) are
/// looked up in, and what the welcome card counts progress over.
final allFlashcardsProvider = FutureProvider<List<Flashcard>>((ref) async {
  await ref.watch(campaignDecksProvider.future);
  return ref.watch(flashcardRepositoryProvider).getAllFlashcards();
});

/// The user's collections, and what's in each. These and favorites live
/// only in the on-device database (they aren't progress, so they aren't
/// synced), which is why they read [databaseServiceProvider] directly.
final collectionsProvider = FutureProvider<List<CardCollection>>((ref) {
  return ref.watch(databaseServiceProvider).getCollections();
});

final collectionFlashcardsProvider =
    FutureProvider.family<List<Flashcard>, int>((ref, collectionId) {
      return ref
          .watch(databaseServiceProvider)
          .getCollectionFlashcards(collectionId);
    });

/// Which collections one card is in, for the "Add to collection" list.
final cardCollectionIdsProvider = FutureProvider.family<Set<int>, int>((
  ref,
  cardId,
) {
  return ref.watch(databaseServiceProvider).getCollectionIdsForCard(cardId);
});

/// Every change to any card's progress, oldest first: the raw material of
/// the learning stats (see `stats_providers.dart`).
final reviewLogProvider = FutureProvider<List<ReviewLogEntry>>((ref) async {
  await ref.watch(campaignDecksProvider.future);
  return ref.watch(databaseServiceProvider).getReviewLog();
});

/// The roots/words that belong to one campaign deck, for the Campaigns
/// browser's per-campaign grid.
final deckFlashcardsProvider = FutureProvider.family<List<Flashcard>, int>((
  ref,
  deckId,
) async {
  // Wait for the import to finish, same as dictionaryEntriesProvider above.
  // Without this, invalidating both providers together (e.g. the debug
  // reset button) lets this query race the reimport and read the deck
  // while its flashcards table is still empty, then never re-run.
  await ref.watch(campaignDecksProvider.future);

  final repository = ref.watch(flashcardRepositoryProvider);
  return repository.getFlashcardsForDeck(deckId);
});
