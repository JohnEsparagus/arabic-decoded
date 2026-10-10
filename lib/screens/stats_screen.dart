import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stats_providers.dart';
import '../theme/app_theme.dart';
import '../utils/date_labels.dart';
import '../utils/learning_stats.dart';
import '../utils/mastery_level.dart';
import '../widgets/mastery_chart.dart';
import '../widgets/pattern_divider.dart';

/// Reached from the sidebar: where the user's learning stands and how it
/// got there. Three headline numbers, then a chart of how many cards were
/// at each mastery level by day, month or year, starting from when the
/// user first studied.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(learningStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learning stats')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _Headlines(stats: stats),
                        const SizedBox(height: 16),
                        // Keyed by scale so switching it starts the new
                        // chart on its latest bar.
                        _ProgressCard(key: ValueKey(stats.scale), stats: stats),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Headlines extends StatelessWidget {
  const _Headlines({required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final now = stats.latest;
    return Row(
      children: [
        Expanded(
          child: _StatTile(value: now.total, label: 'Learned'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: now.counts[MasteryLevel.mastered]!,
            label: 'Mastered',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(value: stats.dayStreak, label: 'Day streak'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            Text(label, style: TextStyle(color: colors.inkMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// The chart, the scale switch above it, and underneath the numbers for
/// whichever bar is picked (the latest, until one is touched).
class _ProgressCard extends ConsumerStatefulWidget {
  const _ProgressCard({super.key, required this.stats});

  final LearningStats stats;

  @override
  ConsumerState<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends ConsumerState<_ProgressCard> {
  late int _selected = widget.stats.buckets.length - 1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stats = widget.stats;
    final bucket = stats.buckets[_selected];
    final period = switch (stats.scale) {
      StatsScale.days => fullDate(bucket.start),
      StatsScale.months => monthAndYear(bucket.start),
      StatsScale.years => '${bucket.start.year}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<StatsScale>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: StatsScale.days, label: Text('Days')),
                  ButtonSegment(
                    value: StatsScale.months,
                    label: Text('Months'),
                  ),
                  ButtonSegment(value: StatsScale.years, label: Text('Years')),
                ],
                selected: {stats.scale},
                onSelectionChanged: (selection) =>
                    ref.read(statsScaleProvider.notifier).set(selection.single),
              ),
            ),
            const SizedBox(height: 18),
            Text(period, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${_count(bucket.total, 'card')} learned · '
              '${_count(bucket.reviews, 'review')}',
              style: TextStyle(color: colors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            MasteryChart(
              stats: stats,
              selected: _selected,
              onSelected: (index) => setState(() => _selected = index),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final level in studiedLevels)
                  _LegendItem(level: level, count: bucket.counts[level]!),
              ],
            ),
            if (stats.latest.total == 0) ...[
              const SizedBox(height: 14),
              Text(
                'Study a few cards and your progress will show up here.',
                style: TextStyle(color: colors.inkMuted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}

/// A level's colour, name and count. The name and number are in the usual
/// text colour; only the dot carries the level's colour.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.level, required this.count});

  final MasteryLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: masteryChartColor(context, level),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          masteryLabel(level),
          style: TextStyle(color: colors.inkMuted, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(
            color: colors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
