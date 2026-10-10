import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deck.dart';
import '../providers/database_providers.dart';
import '../providers/study_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/root_preview_card.dart';
import 'word_detail_screen.dart';

/// The "Campaigns" tab: a browsable overview of every campaign (currently
/// just one — "Campaign" — but the layout is built to hold the 10s-100s of
/// campaigns planned later, each a themed group of roots the student works
/// through in order). Each campaign is its own section with a scrollable
/// grid of its roots as compact preview cards.
///
/// Tapping a root opens the same [WordDetailScreen] the Dictionary tab
/// uses. Adding a root to an "active study queue" from here is intentionally
/// not wired up yet — this screen is the browsing/exploration layer that
/// future queue-management UI will hang off of.
class CampaignsBrowserScreen extends ConsumerWidget {
  const CampaignsBrowserScreen({super.key});

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
      data: (decks) {
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
    ref.invalidate(studySessionProvider);
  }
}

class _CampaignSection extends ConsumerWidget {
  const _CampaignSection({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootsAsync = ref.watch(deckFlashcardsProvider(deck.id!));
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
              Text(
                deck.description!,
                style: TextStyle(color: colors.inkMuted),
              ),
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
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
