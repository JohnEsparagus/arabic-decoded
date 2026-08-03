import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thin repeating zigzag rule, the kind of simple geometric border used
/// throughout traditional Arabic manuscript design. Drawn rather than
/// loaded from an asset so it stays crisp at any width with no extra files.
class PatternDivider extends StatelessWidget {
  const PatternDivider({super.key, this.height = 10, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZigzagPainter(color ?? AppColors.gold.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _ZigzagPainter extends CustomPainter {
  _ZigzagPainter(this.color);

  final Color color;
  static const double _step = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(0, size.height);
    var x = 0.0;
    var up = true;
    while (x < size.width) {
      x = math.min(x + _step, size.width);
      path.lineTo(x, up ? 0 : size.height);
      up = !up;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ZigzagPainter oldDelegate) =>
      oldDelegate.color != color;
}
