import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/stats_providers.dart';
import '../providers/study_session_provider.dart';
import '../theme/app_theme.dart';
import 'flashcard_frame.dart';

/// The first thing on the Home tab each time the app is opened: what's
/// waiting today (reviews due, new cards) and how far along everything is,
/// with one button to start the session.
class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionProvider);
    final allCards = ref.watch(allFlashcardsProvider).asData?.value;
    if (session.loading || allCards == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Roots are the core, so they're always shown. Letters and words
    // only join in for someone who has them switched on.
    final learningAlphabet = ref.watch(studyAlphabetProvider);
    final kinds = [
      if (learningAlphabet) CardKind.letter,
      CardKind.root,
      if (ref.watch(studyWordsProvider)) CardKind.word,
    ];
    final cards = allCards.where((card) => kinds.contains(card.kind)).toList();
    final learned = cards.where((card) => !card.isNew).length;
    final reviews = session.reviewQueue.length;
    final newCards = session.newQueue.length;
    final nothingToStudy = reviews == 0 && newCards == 0;

    // The button sits outside the scrolling part so it's always on screen,
    // however short the window is.
    return FlashcardFrame(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _summary(
                    context,
                    learned: learned,
                    reviews: reviews,
                    newCards: newCards,
                    kinds: kinds,
                    cards: cards,
                    // Offered to someone who hasn't started and hasn't
                    // already chosen it: the one moment it's useful.
                    onLearnAlphabet:
                        !learningAlphabet &&
                            allCards.every((card) => card.isNew)
                        ? () =>
                              ref.read(studyAlphabetProvider.notifier).set(true)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(nothingToStudy ? 'Continue' : 'Start studying'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _summary(
    BuildContext context, {
    required int learned,
    required int reviews,
    required int newCards,
    required List<CardKind> kinds,
    required List<Flashcard> cards,
    required VoidCallback? onLearnAlphabet,
  }) {
    final colors = context.colors;
    return [
      Text(
        'أَهْلًا',
        textDirection: TextDirection.rtl,
        style: arabicTextStyle(context, fontSize: 40, color: colors.ink),
      ),
      Text(
        learned == 0 ? 'Welcome' : 'Welcome back',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.deepGreen,
        ),
      ),
      const SizedBox(height: 16),
      const _TodayRow(),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _CountTile(count: reviews, label: 'to review'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CountTile(count: newCards, label: 'new today'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      _ProgressRow(
        label: 'Overall progress',
        learned: learned,
        total: cards.length,
        emphasized: true,
      ),
      for (final kind in kinds.length > 1 ? kinds : const <CardKind>[])
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _ProgressRow(
            label: switch (kind) {
              CardKind.root => 'Roots',
              CardKind.word => 'Words',
              CardKind.pattern => 'Patterns',
              CardKind.letter => 'Letters',
              CardKind.sentence => 'Sentences',
              CardKind.info => 'Extras',
            },
            learned: cards
                .where((card) => card.kind == kind && !card.isNew)
                .length,
            total: cards.where((card) => card.kind == kind).length,
          ),
        ),
      if (onLearnAlphabet != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextButton(
            onPressed: onLearnAlphabet,
            child: const Text(
              'New to the Arabic script? Start with the alphabet',
            ),
          ),
        ),
    ];
  }
}

/// The streak, and how far along today's goal is.
class _TodayRow extends ConsumerWidget {
  const _TodayRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final today = ref.watch(todayProvider);
    final goal = ref.watch(dailyGoalProvider);
    final reached = today.studied >= goal;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department,
              size: 20,
              color: today.streak > 0 ? colors.gold : colors.inkMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                today.streak == 0
                    ? 'Study today to start a streak'
                    : '${today.streak}-day streak',
                style: TextStyle(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              reached
                  ? 'Goal reached · ${today.studied} today'
                  : '${today.studied} of $goal today',
              style: TextStyle(color: colors.inkMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal == 0 ? 0 : (today.studied / goal).clamp(0, 1),
            minHeight: 8,
            color: reached ? colors.deepGreen : colors.gold,
            backgroundColor: colors.parchmentDark,
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.parchmentDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            Text(label, style: TextStyle(color: colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.learned,
    required this.total,
    this.emphasized = false,
  });

  final String label;
  final int learned;
  final int total;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final weight = emphasized ? FontWeight.w600 : FontWeight.w400;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: colors.ink, fontWeight: weight),
              ),
            ),
            Text(
              '$learned of $total learned',
              style: TextStyle(color: colors.inkMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : learned / total,
            minHeight: emphasized ? 10 : 6,
            color: emphasized ? colors.deepGreen : colors.gold,
            backgroundColor: colors.parchmentDark,
          ),
        ),
      ],
    );
  }
}
