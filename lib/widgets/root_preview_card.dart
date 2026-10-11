import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../theme/app_theme.dart';
import '../utils/mastery_level.dart';

/// A small, compact tappable card showing just a root's Arabic word (plus
/// its transliteration, if any) — used to fill a campaign's root grid,
/// where the goal is scanning many words at a glance rather than reading
/// full detail. Tapping opens the full word detail view.
///
/// Holding one selects it (see [cardSelectionProvider]). While anything is
/// selected, tapping a tile adds or removes it instead of opening it, so a
/// whole batch can be picked out and acted on together.
class RootPreviewCard extends ConsumerWidget {
  const RootPreviewCard({super.key, required this.card, required this.onTap});

  /// Every tile is this wide, which is what lets [TileGrid] work out how
  /// many fit in a row.
  static const width = 92.0;

  final Flashcard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selecting = ref.watch(
      cardSelectionProvider.select((selection) => selection.isNotEmpty),
    );
    final selected = ref.watch(
      cardSelectionProvider.select((selection) => selection.contains(card.id)),
    );
    void toggle() => ref.read(cardSelectionProvider.notifier).toggle(card.id!);

    return InkWell(
      onTap: selecting ? toggle : onTap,
      onLongPress: toggle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _backgroundColorFor(colors, masteryLevelOf(card)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.cardBorder),
        ),
        // Drawn over the tile rather than as a thicker border, so
        // selecting doesn't nudge the tile's contents around.
        foregroundDecoration: selected
            ? BoxDecoration(
                color: colors.deepGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.deepGreen, width: 2.5),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.arabicWord,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arabicTextStyle(context, fontSize: 20, color: colors.ink),
            ),
            if (card.transliteration != null &&
                card.transliteration!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                card.transliteration!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _backgroundColorFor(AppColors colors, MasteryLevel level) {
  switch (level) {
    case MasteryLevel.unlearned:
      return colors.cardSurface;
    case MasteryLevel.weak:
      return colors.masteryWeak;
    case MasteryLevel.learning:
      return colors.masteryLearning;
    case MasteryLevel.strong:
      return colors.masteryStrong;
    case MasteryLevel.mastered:
      return colors.masteryMastered;
  }
}
