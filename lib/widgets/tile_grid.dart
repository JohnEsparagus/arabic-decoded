import 'package:flutter/material.dart';

import 'root_preview_card.dart';

/// A grid of [RootPreviewCard]s, centred as a block: as many columns as
/// fit, with the leftover space split evenly either side. Rows still fill
/// from the start, so a short last row lines up under the others instead
/// of floating in the middle.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.textDirection});

  final List<Widget> children;

  /// Which side rows fill from. Right-to-left for the alphabet.
  final TextDirection? textDirection;

  static const spacing = 10.0;

  /// How many tiles fit across [width].
  static int columnsFor(double width) {
    final fit = (width + spacing) / (RootPreviewCard.width + spacing);
    return fit.floor().clamp(1, 1000);
  }

  /// How wide a row of [columns] tiles is.
  static double widthFor(int columns) =>
      columns * RootPreviewCard.width + (columns - 1) * spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
        ).clamp(1, children.isEmpty ? 1 : children.length);
        return Center(
          child: SizedBox(
            width: widthFor(columns),
            child: Wrap(
              textDirection: textDirection,
              spacing: spacing,
              runSpacing: spacing,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
