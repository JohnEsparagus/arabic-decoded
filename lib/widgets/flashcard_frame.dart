import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The gold double-border "manuscript page" chrome shared by the study
/// screen's flip card and the standalone word detail view, so both always
/// look like the same physical object.
class FlashcardFrame extends StatelessWidget {
  const FlashcardFrame({super.key, required this.child, this.accent});

  final Widget child;

  /// Washes the page faintly in this colour and uses it for the outer
  /// border, to mark a card that's a different sort of thing from the
  /// ones being studied (a lesson, a story).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent == null
              ? colors.cardSurface
              : Color.alphaBlend(
                  accent!.withValues(alpha: 0.06),
                  colors.cardSurface,
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent ?? colors.gold, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.goldSoft, width: 1),
            ),
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }
}
