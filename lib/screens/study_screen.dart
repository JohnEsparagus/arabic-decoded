import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/study_session_provider.dart';
import '../services/sm2.dart';
import '../theme/app_theme.dart';
import '../widgets/card_actions_sheet.dart';
import '../widgets/flashcard_detail_content.dart';
import '../widgets/flashcard_frame.dart';

/// The flip-card + SM-2 grading UI for the global study session: due
/// reviews first, then new cards (capped per day, pulled in campaign
/// order). Body content only (no Scaffold/AppBar) so it can be embedded
/// directly in the Campaign tab.
class StudySessionView extends ConsumerWidget {
  const StudySessionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionProvider);
    final notifier = ref.read(studySessionProvider.notifier);

    if (session.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final card = session.current;
    if (card == null) {
      return _SessionComplete(reviewedCount: session.reviewedCount);
    }

    // A read-once card has nothing to recall, so nothing to flip or
    // grade: it's shown whole, with one way forward.
    if (card.kind == CardKind.info) {
      return Column(
        children: [
          Expanded(
            child: FlashcardFrame(
              accent: readOnceStyle(context, card).color,
              child: Center(child: FlashcardDetailContent(card: card)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: notifier.dismiss,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _PhaseLabel(phase: session.phase),
        const SizedBox(height: 4),
        Text(
          '${session.reviewedCount} seen',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            onTap: notifier.flip,
            onLongPress: () => showCardActions(context, card),
            child: FlipCard(card: card, revealed: session.revealed),
          ),
        ),
        const SizedBox(height: 16),
        if (!session.revealed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: notifier.flip,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Show answer'),
            ),
          )
        else
          _GradeButtons(onGrade: notifier.grade),
      ],
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.phase});

  final StudyPhase phase;

  @override
  Widget build(BuildContext context) {
    final isReview = phase == StudyPhase.review;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isReview
            ? colors.deepGreen.withValues(alpha: 0.12)
            : colors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isReview ? 'Review' : 'New card',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isReview ? colors.deepGreen : const Color(0xFF8A6A1D),
        ),
      ),
    );
  }
}

/// A card that turns over to show its back: the Arabic alone on the front,
/// [FlashcardDetailContent] on the back. Also used by [PracticeScreen].
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.card, required this.revealed});

  final Flashcard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(card.id),
      tween: Tween(begin: 0, end: revealed ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        final angle = value * pi;
        final showBack = value > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: FlashcardFrame(
                    child: Center(child: FlashcardDetailContent(card: card)),
                  ),
                )
              : FlashcardFrame(child: _CardFront(card: card)),
        );
      },
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    // A word and a pattern can be spelled the same (فَاعِل is both), so
    // the front says which kind of card is being asked about.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          card.kind.name.toUpperCase(),
          style: TextStyle(
            color: context.colors.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          card.arabicWord,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: arabicTextStyle(
            context,
            // A whole sentence needs room that a single word doesn't.
            fontSize: card.kind == CardKind.sentence ? 30 : 56,
            color: context.colors.ink,
          ),
        ),
      ],
    );
  }
}

class _GradeButtons extends StatelessWidget {
  const _GradeButtons({required this.onGrade});

  final void Function(Grade grade) onGrade;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GradeButton(
            label: 'Again',
            color: const Color(0xFFB3432D),
            onPressed: () => onGrade(Grade.again),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GradeButton(
            label: 'Hard',
            color: const Color(0xFFBE8A3A),
            onPressed: () => onGrade(Grade.hard),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GradeButton(
            label: 'Good',
            color: context.colors.deepGreen,
            onPressed: () => onGrade(Grade.good),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GradeButton(
            label: 'Easy',
            color: const Color(0xFF2E6E8E),
            onPressed: () => onGrade(Grade.easy),
          ),
        ),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label),
    );
  }
}

class _SessionComplete extends StatelessWidget {
  const _SessionComplete({required this.reviewedCount});

  final int reviewedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: colors.deepGreen, size: 64),
          const SizedBox(height: 16),
          Text(
            reviewedCount == 0
                ? 'Nothing to study right now.'
                : 'All done! Reviewed $reviewedCount card${reviewedCount == 1 ? '' : 's'}.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.ink),
            textAlign: TextAlign.center,
          ),
          if (reviewedCount == 0) ...[
            const SizedBox(height: 8),
            Text(
              'Come back tomorrow for more new cards, or check the '
              'Campaigns tab to see what\'s ahead.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
