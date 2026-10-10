import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_collection.dart';
import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/pattern_divider.dart';
import 'practice_screen.dart';

/// One collection's cards, with a button to practise them. A null
/// [collection] is Favorites: every starred card.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.collection});

  final CardCollection? collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collection = this.collection;
    final title = collection?.name ?? 'Favorites';
    final List<Flashcard>? cards = collection == null
        ? ref
              .watch(allFlashcardsProvider)
              .asData
              ?.value
              .where((card) => card.isFavorite)
              .toList()
        : ref.watch(collectionFlashcardsProvider(collection.id)).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (collection != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete collection',
              onPressed: () => _confirmDelete(context, ref, collection),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: cards == null
                  ? const Center(child: CircularProgressIndicator())
                  : cards.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          collection == null
                              ? 'Nothing starred yet. Hold any card and '
                                    'choose "Favorite".'
                              : 'Nothing in here yet. Hold any card and '
                                    'choose "Add to collection".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.inkMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          CardListTile(card: cards[index]),
                    ),
            ),
            if (cards != null && cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PracticeScreen(title: title, cards: cards),
                      ),
                    ),
                    child: Text(
                      'Practise ${cards.length} '
                      'card${cards.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CardCollection collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${collection.name}"?'),
        content: const Text(
          'The cards stay where they are, with their progress. Only the '
          'collection is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await CardActions(ref).deleteCollection(collection.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}
