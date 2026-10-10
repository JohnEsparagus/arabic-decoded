import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_labels.dart';
import '../utils/learning_stats.dart';
import '../utils/mastery_level.dart';

/// The order the levels are stacked in, bottom to top: the most settled
/// knowledge is the base of each bar, the shakiest sits on top.
final _stackOrder = studiedLevels.reversed.toList();

/// Stacked bars of how many cards were at each mastery level over time,
/// one bar per [StatsBucket]. Touching or dragging across the chart picks
/// a bar, reported through [onSelected]; the numbers for it are shown by
/// whoever owns the chart, so nothing has to be squeezed onto the bars.
class MasteryChart extends StatelessWidget {
  const MasteryChart({
    super.key,
    required this.stats,
    required this.selected,
    required this.onSelected,
  });

  final LearningStats stats;
  final int selected;
  final ValueChanged<int> onSelected;

  static const _height = 190.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ChartLayout(
          size: Size(constraints.maxWidth, _height),
          bucketCount: stats.buckets.length,
        );
        void select(Offset position) =>
            onSelected(layout.bucketAt(position.dx));

        return Semantics(
          label:
              'Chart of cards at each mastery level over time. '
              '${stats.latest.total} cards being studied now.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => select(details.localPosition),
            onHorizontalDragUpdate: (details) => select(details.localPosition),
            child: CustomPaint(
              size: layout.size,
              painter: _MasteryChartPainter(
                stats: stats,
                selected: selected,
                layout: layout,
                levelColors: {
                  for (final level in studiedLevels)
                    level: masteryChartColor(context, level),
                },
                gridColor: colors.cardBorder,
                // A faint wash of the text colour reads on the light and
                // the dark surface alike.
                highlightColor: colors.ink.withValues(alpha: 0.07),
                // Built on the inherited style so the axis is in the same
                // typeface as the rest of the screen.
                labelStyle: DefaultTextStyle.of(
                  context,
                ).style.copyWith(color: colors.inkMuted, fontSize: 10),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where everything in the chart sits, shared by painting and by working
/// out which bar a touch landed on.
class _ChartLayout {
  _ChartLayout({required this.size, required this.bucketCount});

  final Size size;
  final int bucketCount;

  /// Room for the y-axis numbers on the left and the dates underneath.
  static const yAxisWidth = 28.0;
  static const xAxisHeight = 20.0;
  static const topPadding = 6.0;
  static const maxBarWidth = 24.0;
  static const gap = 2.0;

  double get plotLeft => yAxisWidth;
  double get plotBottom => size.height - xAxisHeight;
  double get plotHeight => plotBottom - topPadding;
  double get slotWidth => (size.width - yAxisWidth) / bucketCount;
  double get barWidth => math.max(2, math.min(maxBarWidth, slotWidth - gap));

  double slotLeft(int index) => plotLeft + index * slotWidth;

  int bucketAt(double x) =>
      ((x - plotLeft) / slotWidth).floor().clamp(0, bucketCount - 1);
}

class _MasteryChartPainter extends CustomPainter {
  _MasteryChartPainter({
    required this.stats,
    required this.selected,
    required this.layout,
    required this.levelColors,
    required this.gridColor,
    required this.highlightColor,
    required this.labelStyle,
  });

  final LearningStats stats;
  final int selected;
  final _ChartLayout layout;
  final Map<MasteryLevel, Color> levelColors;
  final Color gridColor;
  final Color highlightColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final buckets = stats.buckets;
    final top = _axisTop(buckets.map((b) => b.total).fold(0, math.max));
    final unit = layout.plotHeight / top;

    // The picked bar's column, behind everything. It runs down through
    // the date row, so it still shows where a tall bar fills the plot. No
    // wider than the bar plus a margin: with only a few bars the slots are
    // broad, and a highlight filling one would be a grey slab.
    final highlightWidth = math.min(layout.slotWidth, layout.barWidth + 20);
    final highlightLeft =
        layout.slotLeft(selected) + (layout.slotWidth - highlightWidth) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          highlightLeft,
          0,
          highlightLeft + highlightWidth,
          size.height,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = highlightColor,
    );

    // Three quiet gridlines: nothing, half, and the top of the axis.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final value in [0, top ~/ 2, top]) {
      final y = layout.plotBottom - value * unit;
      canvas.drawLine(
        Offset(layout.plotLeft, y),
        Offset(size.width, y),
        gridPaint,
      );
      final label = _text('$value');
      label.paint(
        canvas,
        Offset(layout.plotLeft - label.width - 6, y - label.height / 2),
      );
    }

    final barWidth = layout.barWidth;
    final radius = Radius.circular(math.min(4, barWidth / 2));
    for (var i = 0; i < buckets.length; i++) {
      final left = layout.slotLeft(i) + (layout.slotWidth - barWidth) / 2;
      final present = [
        for (final level in _stackOrder)
          if (buckets[i].counts[level]! > 0) level,
      ];
      var y = layout.plotBottom;
      for (final level in present) {
        final height = buckets[i].counts[level]! * unit;
        final isTop = level == present.last;
        // A sliver of the surface between segments keeps neighbours apart
        // without outlining them. Too thin a segment keeps its full height.
        final inset = !isTop && height > _ChartLayout.gap * 2
            ? _ChartLayout.gap
            : 0.0;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, y - height + inset, barWidth, height - inset),
            // Only the very top of the bar is rounded; it grows from a
            // square baseline.
            topLeft: isTop ? radius : Radius.zero,
            topRight: isTop ? radius : Radius.zero,
          ),
          Paint()..color = levelColors[level]!,
        );
        y -= height;
      }

      final label = _axisLabel(i);
      if (label != null) {
        final text = _text(label);
        final center = layout.slotLeft(i) + layout.slotWidth / 2;
        text.paint(
          canvas,
          Offset(
            (center - text.width / 2).clamp(0, size.width - text.width),
            layout.plotBottom + 5,
          ),
        );
      }
    }
  }

  /// The date under bar [index], or null where a label would crowd its
  /// neighbours: days are labelled a week apart, counting back from today.
  String? _axisLabel(int index) {
    final start = stats.buckets[index].start;
    final fromEnd = stats.buckets.length - 1 - index;
    return switch (stats.scale) {
      StatsScale.days => fromEnd % 7 == 0 ? dayAndMonth(start) : null,
      StatsScale.months => shortMonth(start),
      StatsScale.years => '${start.year}',
    };
  }

  /// The top of the y-axis: the tallest bar rounded up to the next tidy
  /// number that's also even, so the halfway gridline is a whole number of
  /// cards too.
  static int _axisTop(int tallest) {
    if (tallest <= 4) return 4;
    final magnitude = math.pow(10, (math.log(tallest) / math.ln10).floor());
    for (final step in [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
      final top = (step * magnitude).round();
      if (top >= tallest && top.isEven) return top;
    }
    return tallest + tallest % 2;
  }

  TextPainter _text(String text) {
    return TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_MasteryChartPainter old) =>
      old.stats != stats ||
      old.selected != selected ||
      old.layout.size != layout.size ||
      old.gridColor != gridColor;
}
