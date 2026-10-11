import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../models/sentence.dart';
import '../utils/arabic_normalize.dart';
import '../utils/mastery_level.dart';
import 'database_providers.dart';
import 'study_session_provider.dart';

/// How well each word the app teaches is known, keyed by the word with its
/// vowel marks stripped (the form `wordKeys` produces). It's what colours
/// the words of a sentence. Built once per change to the cards, from the
/// few hundred word cards, not per sentence.
final wordMasteryProvider = Provider<Map<String, MasteryLevel>>((ref) {
  final cards = ref.watch(allFlashcardsProvider).asData?.value ?? const [];
  final levels = <String, MasteryLevel>{};
  for (final card in cards) {
    if (card.kind != CardKind.word) continue;
    final key = wordKey(card.arabicWord);
    final level = masteryLevelOf(card);
    // The same spelling can be two cards (a verb and its noun, once the
    // vowels are gone); show the better-known of them.
    final known = levels[key];
    if (known == null || level.index > known.index) levels[key] = level;
  }
  return levels;
});

/// Up to twenty sentences containing a card's word: for a word card, that
/// word; for a root, any of the words built from it. Only asked for when
/// someone opens the "Sentences" section on a card, and dropped again
/// when they leave.
final sentencesForCardProvider = FutureProvider.autoDispose
    .family<List<Sentence>, int>((ref, cardId) async {
      final cards = await ref.watch(allFlashcardsProvider.future);
      final card = cards.where((c) => c.id == cardId).firstOrNull;
      if (card == null) return const [];
      final words = switch (card.kind) {
        CardKind.word => [card],
        CardKind.root => cards.where(
          (c) =>
              c.kind == CardKind.word &&
              c.deckId == card.deckId &&
              c.rootKey == card.arabicWord,
        ),
        _ => const <Flashcard>[],
      };
      return ref.watch(databaseServiceProvider).getSentencesWithWords([
        for (final word in words) wordKey(word.arabicWord),
      ]);
    });

/// What the sentence explorer is showing: the search, the sentences
/// loaded so far, and whether there are more to fetch.
class SentenceExplorerState {
  final String query;
  final List<Sentence> sentences;
  final bool hasMore;
  final bool loading;

  /// How many sentences the corpus holds in all.
  final int total;

  const SentenceExplorerState({
    this.query = '',
    this.sentences = const [],
    this.hasMore = true,
    this.loading = false,
    this.total = 0,
  });
}

/// Pages through the corpus for the sentence explorer. Only what's been
/// scrolled to is ever in memory: a page is fetched when the list nears
/// its end, and a new search starts again from the first page.
class SentenceExplorerNotifier extends Notifier<SentenceExplorerState> {
  static const pageSize = 40;

  /// Counts searches, so a page that comes back after the search has
  /// changed is recognised as stale and dropped.
  int _generation = 0;

  @override
  SentenceExplorerState build() {
    Future.microtask(() => search(''));
    return const SentenceExplorerState(loading: true);
  }

  /// Starts over with a new search (empty for the whole corpus).
  Future<void> search(String query) async {
    final generation = ++_generation;
    state = SentenceExplorerState(
      query: query,
      loading: true,
      total: state.total,
    );
    // The corpus is loaded by the same import the cards are.
    await ref.read(campaignDecksProvider.future);
    final db = ref.read(databaseServiceProvider);
    final total = await db.countSentences();
    final page = await db.searchSentences(
      search: normalizeArabic(query),
      limit: pageSize,
    );
    if (generation != _generation) return;
    state = SentenceExplorerState(
      query: query,
      sentences: page,
      hasMore: page.length == pageSize,
      total: total,
    );
  }

  /// Fetches the next page, if there is one and none is on its way.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final generation = _generation;
    final current = state;
    state = SentenceExplorerState(
      query: current.query,
      sentences: current.sentences,
      loading: true,
      total: current.total,
    );
    final page = await ref
        .read(databaseServiceProvider)
        .searchSentences(
          search: normalizeArabic(current.query),
          limit: pageSize,
          offset: current.sentences.length,
        );
    if (generation != _generation) return;
    state = SentenceExplorerState(
      query: current.query,
      sentences: [...current.sentences, ...page],
      hasMore: page.length == pageSize,
      total: current.total,
    );
  }

  /// Swaps in a sentence whose state just changed, in place, so the list
  /// doesn't have to be fetched again.
  void replace(Sentence updated) {
    state = SentenceExplorerState(
      query: state.query,
      sentences: [
        for (final sentence in state.sentences)
          sentence.id == updated.id ? updated : sentence,
      ],
      hasMore: state.hasMore,
      loading: state.loading,
      total: state.total,
    );
  }
}

final sentenceExplorerProvider =
    NotifierProvider<SentenceExplorerNotifier, SentenceExplorerState>(
      SentenceExplorerNotifier.new,
    );

/// Adds a sentence to the study queue or takes it back out, wherever the
/// button for that was pressed, and returns the sentence as it now is.
/// Works offline like everything else: it's a local write.
Future<Sentence> toggleSentenceQueued(WidgetRef ref, Sentence sentence) async {
  final queued = !sentence.isQueued;
  final cardId = await ref
      .read(databaseServiceProvider)
      .setSentenceQueued(sentence.id, queued);
  final updated = sentence.copyWith(cardId: cardId, isQueued: queued);
  ref.read(sentenceExplorerProvider.notifier).replace(updated);
  ref.invalidate(sentencesForCardProvider);
  ref.invalidate(allFlashcardsProvider);
  ref.invalidate(studySessionProvider);
  return updated;
}
