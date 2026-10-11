import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/campaign_sources.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../providers/study_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/root_preview_card.dart';
import '../widgets/tile_grid.dart';
import '../widgets/selection_bar.dart';
import 'alphabet_tab.dart';
import 'collections_tab.dart';
import 'word_detail_screen.dart';
import 'words_tab.dart';

/// The "Campaigns" tab, in four parts: Alphabet (the 28 letters, for
/// anyone who can't read the script yet), Roots (every campaign, each a
/// themed group of roots the student works through in order), Words (the
/// words learnt so far, and the ones ready to be) and Collections (the
/// user's own lists of cards). It opens on Roots, the core of the app.
///
/// Holding a tile in the Roots or Words grid selects it, and more can be
/// tapped to join it; [SelectionBar] then offers the actions for all of
/// them at once.
class CampaignsBrowserScreen extends StatelessWidget {
  const CampaignsBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      initialIndex: 1,
      child: Column(
        children: [
          TabBar(
            labelPadding: EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              Tab(text: 'Alphabet'),
              Tab(text: 'Roots'),
              Tab(text: 'Words'),
              Tab(text: 'Collections'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AlphabetTab(),
                _RootsTab(),
                WordsTab(),
                CollectionsTab(),
              ],
            ),
          ),
          SelectionBar(),
        ],
      ),
    );
  }
}

/// Every campaign as its own section, with a grid of its roots as compact
/// preview cards. Tapping a root opens the same [WordDetailScreen] the
/// Dictionary tab uses.
class _RootsTab extends ConsumerWidget {
  const _RootsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(campaignDecksProvider);

    final colors = context.colors;
    return decksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Could not load campaigns:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.inkMuted),
        ),
      ),
      data: (allDecks) {
        // The patterns and the alphabet have decks but aren't campaigns.
        final decks = allDecks
            .where(
              (deck) =>
                  deck.name != patternsSource.deckName &&
                  deck.name != alphabetSource.deckName,
            )
            .toList();
        if (decks.isEmpty) {
          return Center(
            child: Text(
              'No campaigns yet.',
              style: TextStyle(color: colors.inkMuted),
            ),
          );
        }
        final showResetButton = kDebugMode;
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: decks.length + (showResetButton ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            if (index >= decks.length) return const _ResetProgressButton();
            return _CampaignSection(deck: decks[index]);
          },
        );
      },
    );
  }
}

/// Debug-only escape hatch for wiping local data while testing — the daily
/// new-card cap, first-launch import, campaign progression, etc. are much
/// easier to re-test from a clean slate than by uninstalling the app.
/// `kDebugMode` strips this out of release builds automatically, so it
/// never reaches a real user.
class _ResetProgressButton extends ConsumerWidget {
  const _ResetProgressButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmAndReset(context, ref),
        icon: const Icon(Icons.restart_alt, color: Colors.redAccent),
        label: const Text(
          'Reset all progress (debug)',
          style: TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'Deletes every deck and flashcard and re-imports the campaigns '
          'from scratch. This cannot be undone.',
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
    if (confirmed != true) return;

    await ref.read(databaseServiceProvider).resetDatabase();
    ref.invalidate(campaignDecksProvider);
    ref.invalidate(deckFlashcardsProvider);
    ref.invalidate(dictionaryEntriesProvider);
    ref.invalidate(allFlashcardsProvider);
    ref.invalidate(reviewLogProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionFlashcardsProvider);
    ref.invalidate(studySessionProvider);
  }
}

class _CampaignSection extends ConsumerWidget {
  const _CampaignSection({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A campaign is its roots; its words are on the Words tab.
    final rootsAsync = ref
        .watch(deckFlashcardsProvider(deck.id!))
        .whenData(
          (cards) => cards.where((card) => card.kind == CardKind.root).toList(),
        );
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deck.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                rootsAsync.maybeWhen(
                  data: (roots) => Text(
                    '${roots.length} root${roots.length == 1 ? '' : 's'}',
                    style: TextStyle(color: colors.inkMuted),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            if (deck.description != null && deck.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(deck.description!, style: TextStyle(color: colors.inkMuted)),
            ],
            const SizedBox(height: 14),
            rootsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Could not load roots: $error',
                style: TextStyle(color: colors.inkMuted),
              ),
              data: (roots) {
                if (roots.isEmpty) {
                  return Text(
                    'No roots in this campaign yet.',
                    style: TextStyle(color: colors.inkMuted),
                  );
                }
                return TileGrid(
                  children: roots
                      .map(
                        (card) => RootPreviewCard(
                          card: card,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WordDetailScreen(card: card),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
