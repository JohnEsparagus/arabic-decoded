import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import 'card_actions_sheet.dart';

/// The bar along the bottom of the Campaigns tab while cards are selected:
/// how many, and what to do with them all — the same actions a single
/// card's hold menu has. Takes up no space when nothing is selected.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(cardSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final cards =
        ref
            .watch(allFlashcardsProvider)
            .asData
            ?.value
            .where((card) => selection.contains(card.id))
            .toList() ??
        const <Flashcard>[];
    final actions = CardActions(ref);
    final messenger = ScaffoldMessenger.of(context);
    final count = '${cards.length} card${cards.length == 1 ? '' : 's'}';
    final allFavorite = cards.every((card) => card.isFavorite);

    // Runs an action on the selection, then lets go of it and says what
    // happened.
    Future<void> run(Future<void> Function() action, String message) async {
      await action();
      ref.read(cardSelectionProvider.notifier).clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return Material(
      color: colors.cardSurface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                  onPressed: () =>
                      ref.read(cardSelectionProvider.notifier).clear(),
                ),
                Text(
                  '${selection.length} selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Row(
              children: [
                _BarAction(
                  icon: Icons.playlist_add,
                  label: 'Learn',
                  onPressed: () => run(
                    () => actions.queueAll(cards),
                    'Added $count to your queue',
                  ),
                ),
                _BarAction(
                  icon: Icons.verified_outlined,
                  label: 'Mastered',
                  onPressed: () => run(
                    () => actions.markAllMastered(cards),
                    'Marked $count as mastered',
                  ),
                ),
                _BarAction(
                  icon: allFavorite ? Icons.star : Icons.star_border,
                  label: allFavorite ? 'Unfavorite' : 'Favorite',
                  onPressed: () => run(
                    () => actions.setAllFavorite(cards, !allFavorite),
                    allFavorite
                        ? 'Removed $count from favorites'
                        : 'Added $count to favorites',
                  ),
                ),
                _BarAction(
                  icon: Icons.collections_bookmark_outlined,
                  label: 'Collection',
                  onPressed: () async {
                    final name = await _pickCollection(context, ref);
                    if (name == null) return;
                    await run(
                      () => actions.addAllToCollection(name.$1, cards),
                      'Added $count to ${name.$2}',
                    );
                  },
                ),
                _BarAction(
                  icon: Icons.restart_alt,
                  label: 'Reset',
                  onPressed: () async {
                    if (!await _confirmReset(context, count)) return;
                    await run(() => actions.resetAll(cards), 'Reset $count');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lets the user choose a collection, or make one. Returns its id and
  /// name, or null if they backed out.
  Future<(int, String)?> _pickCollection(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<(int, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Consumer(
            builder: (context, sheetRef, _) {
              final collections =
                  sheetRef.watch(collectionsProvider).asData?.value ?? [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add to…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final collection in collections)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(collection.name),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop((collection.id, collection.name)),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New collection'),
                    onTap: () async {
                      final name = await promptCollectionName(context);
                      if (name == null) return;
                      final id = await CardActions(ref).createCollection(name);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop((id, name));
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmReset(BuildContext context, String count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $count?'),
        content: const Text(
          'They go back to never-studied. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.deepGreen),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
