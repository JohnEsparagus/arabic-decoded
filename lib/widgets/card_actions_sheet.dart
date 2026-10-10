import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../utils/mastery_level.dart';

/// The menu that holding a card brings up, anywhere a card is shown: add
/// it to the queue, mark it mastered, star it, file it in a collection, or
/// reset it.
Future<void> showCardActions(BuildContext context, Flashcard card) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CardActionsSheet(card: card),
  );
}

/// Asks for a collection's name. Null if the dialog was dismissed or the
/// name left empty.
Future<String?> promptCollectionName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Travel words'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class _CardActionsSheet extends ConsumerWidget {
  const _CardActionsSheet({required this.card});

  /// The card as it was when the menu was opened. [build] looks up the
  /// current copy, since the star or queue state may have changed since
  /// whichever list this came from was loaded.
  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final current =
        ref
            .watch(allFlashcardsProvider)
            .asData
            ?.value
            .where((other) => other.id == card.id)
            .firstOrNull ??
        card;
    final actions = CardActions(ref);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Runs an action, closes the menu and says what happened. The action
    // finishes first: it refreshes providers through this sheet's `ref`,
    // which stops working once the sheet is gone.
    Future<void> run(Future<void> Function() action, String message) async {
      await action();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final isQueued = current.queuedAt != null;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.arabicWord,
              textDirection: TextDirection.rtl,
              style: arabicTextStyle(context, fontSize: 28, color: colors.ink),
            ),
            Text(
              current.englishTranslation,
              style: TextStyle(color: colors.inkMuted),
            ),
            const SizedBox(height: 8),
            if (current.isNew)
              ListTile(
                leading: Icon(
                  isQueued ? Icons.playlist_remove : Icons.playlist_add,
                ),
                title: Text(isQueued ? 'Remove from my queue' : 'Learn'),
                subtitle: isQueued
                    ? null
                    : const Text('Add to my queue as the next new card'),
                onTap: () => run(
                  () => actions.setQueued(current, !isQueued),
                  isQueued ? 'Removed from your queue' : 'Added to your queue',
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.replay),
                title: const Text('Review now'),
                subtitle: const Text('Add to today\'s reviews'),
                onTap: () => run(
                  () => actions.setQueued(current, true),
                  'Added to today\'s reviews',
                ),
              ),
            if (masteryLevelOf(current) != MasteryLevel.mastered)
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('Mark as mastered'),
                subtitle: const Text('I know this one already'),
                onTap: () => run(
                  () => actions.markMastered(current),
                  'Marked as mastered',
                ),
              ),
            ListTile(
              leading: Icon(
                current.isFavorite ? Icons.star : Icons.star_border,
                color: current.isFavorite ? colors.gold : null,
              ),
              title: Text(
                current.isFavorite ? 'Remove from favorites' : 'Favorite',
              ),
              onTap: () => run(
                () => actions.setFavorite(current, !current.isFavorite),
                current.isFavorite
                    ? 'Removed from favorites'
                    : 'Added to favorites',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Add to collection'),
              onTap: () {
                navigator.pop();
                showModalBottomSheet<void>(
                  context: navigator.context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => _CollectionPickerSheet(card: current),
                );
              },
            ),
            if (!current.isNew)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset'),
                subtitle: const Text('Forget my progress on this card'),
                onTap: () => run(() => actions.reset(current), 'Card reset'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tick the collections a card belongs in, or start a new one with it.
class _CollectionPickerSheet extends ConsumerWidget {
  const _CollectionPickerSheet({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collections = ref.watch(collectionsProvider).asData?.value ?? [];
    final selected =
        ref.watch(cardCollectionIdsProvider(card.id!)).asData?.value ??
        const <int>{};
    final actions = CardActions(ref);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add ${card.arabicWord} to…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No collections yet. Make one to group cards you want to '
                  'go through together.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.inkMuted),
                ),
              ),
            for (final collection in collections)
              CheckboxListTile(
                title: Text(collection.name),
                value: selected.contains(collection.id),
                onChanged: (value) => actions.setInCollection(
                  collection.id,
                  card,
                  value ?? false,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New collection'),
              onTap: () async {
                final name = await promptCollectionName(context);
                if (name == null) return;
                final id = await actions.createCollection(name);
                await actions.setInCollection(id, card, true);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
