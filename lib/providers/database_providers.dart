import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/content_importer.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final contentImporterProvider = Provider<ContentImporter>((ref) {
  return ContentImporter(ref.watch(databaseServiceProvider));
});

/// The maximum number of never-studied cards introduced in a single day,
/// across all campaigns combined.
final maxNewCardsPerDayProvider = Provider<int>((ref) => 10);

/// Imports every campaign listed in `lib/config/campaign_sources.dart`
/// (creating each one's deck if needed) and returns them in campaign
/// order. Safe to watch from multiple places — importing is a no-op for
/// words that are already stored, so this can run on every screen that
/// needs campaign data without duplicating anything.
final campaignDecksProvider = FutureProvider<List<Deck>>((ref) async {
  final importer = ref.watch(contentImporterProvider);
  return importer.importAll();
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

/// Every flashcard across every deck when the search field is empty
/// (browsing mode), or the matching subset once the user types something.
final dictionaryEntriesProvider = FutureProvider<List<Flashcard>>((ref) async {
  // Make sure every campaign's words are imported, even if the user opens
  // the Dictionary tab before ever visiting Campaign.
  await ref.watch(campaignDecksProvider.future);

  final db = ref.watch(databaseServiceProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return db.getAllFlashcards();
  return db.searchFlashcards(query);
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

  final db = ref.watch(databaseServiceProvider);
  return db.getFlashcardsForDeck(deckId);
});
