import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../utils/mastery_level.dart';
import '../widgets/root_preview_card.dart';
import '../widgets/tile_grid.dart';
import 'word_detail_screen.dart';

/// Which mastery level the frequency list is narrowed to; null shows all.
class FrequencyFilterNotifier extends Notifier<MasteryLevel?> {
  @override
  MasteryLevel? build() => null;

  void set(MasteryLevel? level) => state = level;
}

final frequencyFilterProvider =
    NotifierProvider<FrequencyFilterNotifier, MasteryLevel?>(
      FrequencyFilterNotifier.new,
    );

/// The Frequency view of the Roots tab: the most useful roots, most common
/// first, whichever campaign each lives in. They're the same cards as
/// everywhere else, so this shows progress made anywhere. None come up by
/// themselves; holding tiles and choosing "Learn" adds them to the queue.
///
/// The list runs to hundreds of tiles, so rows are built as they're
/// scrolled to, rather than all at once as [TileGrid] does.
class FrequencyView extends ConsumerWidget {
  const FrequencyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final filter = ref.watch(frequencyFilterProvider);
    final roots =
        (ref.watch(allFlashcardsProvider).asData?.value ?? const <Flashcard>[])
            .where((card) => card.frequencyRank != null)
            .toList()
          ..sort((a, b) => a.frequencyRank!.compareTo(b.frequencyRank!));
    final learnt = roots.where((card) => !card.isNew).length;
    final shown = filter == null
        ? roots
        : roots.where((card) => masteryLevelOf(card) == filter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hold a root to add it to your queue',
                  style: TextStyle(color: colors.inkMuted, fontSize: 13),
                ),
              ),
              Text(
                '$learnt of ${roots.length} learnt',
                style: TextStyle(color: colors.inkMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _LevelFilter(),
        const SizedBox(height: 8),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'No roots here yet.',
                    style: TextStyle(color: colors.inkMuted),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = TileGrid.columnsFor(
                      constraints.maxWidth - 40,
                    );
                    final rows = (shown.length / columns).ceil();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: rows,
                      itemBuilder: (context, row) => _TileRow(
                        cards: shown.skip(row * columns).take(columns).toList(),
                        columns: columns,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One row of the grid, aligned with the others even when it's short.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.cards, required this.columns});

  final List<Flashcard> cards;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TileGrid.spacing),
      child: Center(
        child: SizedBox(
          width: TileGrid.widthFor(columns),
          child: Row(
            children: [
              for (final (index, card) in cards.indexed) ...[
                if (index > 0) const SizedBox(width: TileGrid.spacing),
                RootPreviewCard(
                  card: card,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WordDetailScreen(card: card),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelFilter extends ConsumerWidget {
  const _LevelFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(frequencyFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final level in <MasteryLevel?>[null, ...MasteryLevel.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(level == null ? 'All' : masteryLabel(level)),
                selected: selected == level,
                onSelected: (_) =>
                    ref.read(frequencyFilterProvider.notifier).set(level),
              ),
            ),
        ],
      ),
    );
  }
}
