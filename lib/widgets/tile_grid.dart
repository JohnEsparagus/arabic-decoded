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

  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const tile = RootPreviewCard.width;
        final columns = ((constraints.maxWidth + _spacing) / (tile + _spacing))
            .floor()
            .clamp(1, children.isEmpty ? 1 : children.length);
        return Center(
          child: SizedBox(
            width: columns * tile + (columns - 1) * _spacing,
            child: Wrap(
              textDirection: textDirection,
              spacing: _spacing,
              runSpacing: _spacing,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
