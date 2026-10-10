import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/root_preview_card.dart';
import 'word_detail_screen.dart';

/// The Alphabet part of the Campaigns tab: the 28 letters as tiles, for
/// someone starting from nothing. Each letter is a card like any other
/// (its name, its sound, how it's written in each position, a word that
/// uses it), coloured here by how well it's known.
///
/// It's optional. The switch is the same setting as the one in Settings:
/// on, the letters are taught before any root.
class AlphabetTab extends ConsumerWidget {
  const AlphabetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final allCards = ref.watch(allFlashcardsProvider).asData?.value;
    if (allCards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Alphabetical order is the order they were imported in.
    final letters =
        allCards.where((card) => card.kind == CardKind.letter).toList()
          ..sort((a, b) => a.id!.compareTo(b.id!));
    final learnt = letters.where((card) => !card.isNew).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            title: const Text('Learn the alphabet'),
            subtitle: const Text('Teach me the 28 letters before any roots'),
            value: ref.watch(studyAlphabetProvider),
            onChanged: (value) =>
                ref.read(studyAlphabetProvider.notifier).set(value),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Letters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '$learnt of ${letters.length} learnt',
              style: TextStyle(color: colors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Arabic is read right to left, and so is this: the first letter '
          'is at the top right.',
          style: TextStyle(color: colors.inkMuted),
        ),
        const SizedBox(height: 14),
        Wrap(
          // Laid out the way the script runs.
          textDirection: TextDirection.rtl,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in letters)
              RootPreviewCard(
                card: card,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WordDetailScreen(card: card),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
