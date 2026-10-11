import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/root_preview_card.dart';
import '../widgets/tile_grid.dart';
import 'word_detail_screen.dart';

/// The Words part of the Campaigns tab: every word learnt so far, then the
/// words that are ready to be learnt because their root is already known.
/// Both are grids of the same small tiles the Roots tab uses, coloured by
/// mastery, so progress shows at a glance. Holding a tile selects it,
/// which is how words get added to the queue from here.
///
/// Words are optional. The switch at the top is the same setting as the
/// one in Settings: on, the app feeds words in by itself; off, the only
/// words in the queue are the ones added from here (or from any card's
/// hold menu).
class WordsTab extends ConsumerWidget {
  const WordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final allCards = ref.watch(allFlashcardsProvider).asData?.value;
    if (allCards == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final knownRoots = {
      for (final card in allCards)
        if (card.kind == CardKind.root && !card.isNew)
          (card.deckId, card.arabicWord),
    };
    final words = allCards.where((card) => card.kind == CardKind.word);
    final learnt = words.where((card) => !card.isNew).toList();
    final ready = words
        .where(
          (card) =>
              card.isNew && knownRoots.contains((card.deckId, card.rootKey)),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            title: const Text('Add words automatically'),
            subtitle: const Text(
              'Mix words from roots you know into your new cards',
            ),
            value: ref.watch(studyWordsProvider),
            onChanged: (value) =>
                ref.read(studyWordsProvider.notifier).set(value),
          ),
        ),
        const SizedBox(height: 24),
        _Heading('Learnt', learnt.length),
        if (learnt.isEmpty)
          Text('No words learnt yet.', style: TextStyle(color: colors.inkMuted))
        else
          _WordGrid(words: learnt),
        const SizedBox(height: 24),
        _Heading('Ready to learn', ready.length),
        Text(
          ready.isEmpty
              ? 'Words show up here once you have learnt their root.'
              : 'Built from roots you know. Hold one to select it, tap any '
                    'others, then choose "Learn" to add them to your queue.',
          style: TextStyle(color: colors.inkMuted),
        ),
        const SizedBox(height: 12),
        _WordGrid(words: ready),
      ],
    );
  }
}

/// Words as the same small tiles the Roots tab uses for roots, coloured by
/// how well each one is known.
class _WordGrid extends StatelessWidget {
  const _WordGrid({required this.words});

  final List<Flashcard> words;

  @override
  Widget build(BuildContext context) {
    return TileGrid(
      children: words
          .map(
            (card) => RootPreviewCard(
              card: card,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WordDetailScreen(card: card)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Text('$count', style: TextStyle(color: context.colors.inkMuted)),
        ],
      ),
    );
  }
}
