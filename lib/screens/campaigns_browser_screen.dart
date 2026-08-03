import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deck.dart';
import '../providers/database_providers.dart';
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

    return decksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Could not load campaigns:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkMuted),
        ),
      ),
      data: (decks) {
        if (decks.isEmpty) {
          return const Center(
            child: Text(
              'No campaigns yet.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: decks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 24),
          itemBuilder: (context, index) => _CampaignSection(deck: decks[index]),
        );
      },
    );
  }
}

class _CampaignSection extends ConsumerWidget {
  const _CampaignSection({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootsAsync = ref.watch(deckFlashcardsProvider(deck.id!));

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
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            if (deck.description != null && deck.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                deck.description!,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ],
            const SizedBox(height: 14),
            rootsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Could not load roots: $error',
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              data: (roots) {
                if (roots.isEmpty) {
                  return const Text(
                    'No roots in this campaign yet.',
                    style: TextStyle(color: AppColors.inkMuted),
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
