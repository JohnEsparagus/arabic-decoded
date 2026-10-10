import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../utils/arabic_normalize.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/pattern_divider.dart';

/// What's typed in the Sentences screen's search field.
class SentenceQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final sentenceQueryProvider = NotifierProvider<SentenceQueryNotifier, String>(
  SentenceQueryNotifier.new,
);

/// Every sentence card, in corpus order, narrowed to those matching the
/// search (Arabic matched loosely, ignoring vowel marks, like the
/// dictionary's). Computed here rather than in the list, so typing only
/// re-filters, and scrolling doesn't filter at all.
final sentencesProvider = Provider<List<Flashcard>?>((ref) {
  final cards = ref.watch(allFlashcardsProvider).asData?.value;
  if (cards == null) return null;
  final sentences =
      cards.where((card) => card.kind == CardKind.sentence).toList()
        ..sort((a, b) => a.id!.compareTo(b.id!));

  final query = ref.watch(sentenceQueryProvider).trim();
  if (query.isEmpty) return sentences;
  final arabic = normalizeArabic(query);
  final english = query.toLowerCase();
  return sentences
      .where(
        (card) =>
            (arabic.isNotEmpty &&
                normalizeArabic(card.arabicWord).contains(arabic)) ||
            card.englishTranslation.toLowerCase().contains(english),
      )
      .toList();
});

/// Reached from the sidebar: the sentence corpus. Sentences never come up
/// by themselves; the + on a row puts that one in the study queue (tap it
/// again to take it back out). After that it's a card like any other:
/// graded, reviewed, and open to the same hold menu.
class SentencesScreen extends ConsumerWidget {
  const SentencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sentences = ref.watch(sentencesProvider);
    final query = ref.watch(sentenceQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sentences')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Arabic or English',
                  prefixIcon: Icon(Icons.search, color: colors.inkMuted),
                ),
                onChanged: (value) =>
                    ref.read(sentenceQueryProvider.notifier).set(value),
              ),
            ),
            Expanded(
              child: sentences == null
                  ? const Center(child: CircularProgressIndicator())
                  : sentences.isEmpty
                  ? Center(
                      child: Text(
                        query.trim().isEmpty
                            ? 'No sentences yet.'
                            : 'No matches for "$query".',
                        style: TextStyle(color: colors.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: sentences.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _SentenceRow(card: sentences[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceRow extends ConsumerWidget {
  const _SentenceRow({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final queued = card.queuedAt != null;
    return CardListTile(
      card: card,
      // Once it's being studied there's nothing left to add; the hold
      // menu still has "Review now" and the rest.
      trailing: !card.isNew
          ? Tooltip(
              message: 'In your reviews',
              child: Icon(Icons.check, color: colors.inkMuted),
            )
          : IconButton(
              icon: Icon(
                queued ? Icons.check_circle : Icons.add_circle_outline,
              ),
              color: colors.deepGreen,
              tooltip: queued
                  ? 'In your queue. Tap to remove'
                  : 'Add to my queue',
              onPressed: () => CardActions(ref).setQueued(card, !queued),
            ),
    );
  }
}
