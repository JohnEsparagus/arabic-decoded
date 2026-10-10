import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/learning_stats.dart';
import 'database_providers.dart';

/// Which scale the stats screen is showing. Kept in a provider rather than
/// the screen's own state so it's remembered while the app stays open.
class StatsScaleNotifier extends Notifier<StatsScale> {
  @override
  StatsScale build() => StatsScale.days;

  void set(StatsScale scale) => state = scale;
}

final statsScaleProvider = NotifierProvider<StatsScaleNotifier, StatsScale>(
  StatsScaleNotifier.new,
);

/// Today at a glance, for the welcome card: the streak, and how many cards
/// have been studied so far toward the daily goal.
final todayProvider = Provider<({int streak, int studied})>((ref) {
  final log = ref.watch(reviewLogProvider).asData?.value ?? const [];
  final now = DateTime.now();
  return (streak: dayStreak(log, now), studied: reviewsToday(log, now));
});

/// The learning stats at the chosen scale, or null while the review log
/// is still loading. Recomputed only when the log or the scale changes.
final learningStatsProvider = Provider<LearningStats?>((ref) {
  final log = ref.watch(reviewLogProvider).asData?.value;
  if (log == null) return null;
  return buildLearningStats(
    log,
    scale: ref.watch(statsScaleProvider),
    now: DateTime.now(),
  );
});
