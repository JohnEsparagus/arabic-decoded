import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small gold diamond, the ornament between a card's Arabic and its
/// meaning and at the head of list items. Drawn rather than typed as a ✦
/// character, so it looks the same everywhere and a browser doesn't have to
/// fetch a symbol font to show it.
class GoldDiamond extends StatelessWidget {
  const GoldDiamond({super.key, this.size = 7});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.gold,
          borderRadius: BorderRadius.circular(size / 6),
        ),
      ),
    );
  }
}
