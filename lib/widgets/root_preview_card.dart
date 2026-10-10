import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../theme/app_theme.dart';
import '../utils/mastery_level.dart';

/// A small, compact tappable card showing just a root's Arabic word (plus
/// its transliteration, if any) — used to fill a campaign's root grid,
/// where the goal is scanning many words at a glance rather than reading
/// full detail. Tapping opens the full word detail view.
class RootPreviewCard extends StatelessWidget {
  const RootPreviewCard({super.key, required this.card, required this.onTap});

  final Flashcard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _backgroundColorFor(colors, masteryLevelOf(card)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.arabicWord,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arabicTextStyle(fontSize: 20, color: colors.ink),
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
