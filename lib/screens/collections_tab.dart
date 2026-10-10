import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_collection.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/card_actions_sheet.dart';
import 'collection_screen.dart';

/// The Collections part of the Campaigns tab: Favorites (every starred
/// card) followed by the collections the user has made. Cards get into
/// either from the menu that holding a card brings up.
class CollectionsTab extends ConsumerWidget {
  const CollectionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collections = ref.watch(collectionsProvider).asData?.value ?? [];
    final favoriteCount =
        ref
            .watch(allFlashcardsProvider)
            .asData
            ?.value
            .where((card) => card.isFavorite)
            .length ??
        0;

    void open(CardCollection? collection) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionScreen(collection: collection),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.star, color: colors.gold),
            title: const Text('Favorites'),
            subtitle: Text(_cards(favoriteCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(null),
          ),
        ),
        for (final collection in collections)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              child: ListTile(
                leading: Icon(
                  Icons.collections_bookmark_outlined,
                  color: colors.deepGreen,
                ),
                title: Text(collection.name),
                subtitle: Text(_cards(collection.cardCount)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(collection),
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New collection'),
          onPressed: () async {
            final name = await promptCollectionName(context);
            if (name != null) await CardActions(ref).createCollection(name);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Hold any card and choose "Add to collection" to file it here, '
          'then open a collection to practise just those cards.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.inkMuted),
        ),
      ],
    );
  }

  String _cards(int count) => '$count card${count == 1 ? '' : 's'}';
}
