import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/card_actions.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/flashcard_detail_content.dart';
import '../widgets/pattern_divider.dart';
import 'word_detail_screen.dart';

/// Reached from the sidebar, once as Lessons and once as Stories: every
/// read-once card carrying [label], in the order they open up. Each one
/// turns up by itself in the study session when its moment comes; this is
/// where to find it again afterwards, or to read one that has opened up
/// without waiting for it. Ones still ahead are listed too, with how far
/// off they are.
class ReadOnceListScreen extends ConsumerWidget {
  const ReadOnceListScreen({
    super.key,
    required this.label,
    required this.title,
    required this.blurb,
  });

  final String label;
  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final allCards = ref.watch(allFlashcardsProvider).asData?.value;
    final cards =
        allCards
            ?.where(
              (card) =>
                  card.kind == CardKind.info &&
                  card.englishTranslation == label,
            )
            .toList()
          ?..sort((a, b) {
            final byUnlock = (a.unlockAfter ?? 0).compareTo(b.unlockAfter ?? 0);
            return byUnlock != 0 ? byUnlock : a.id!.compareTo(b.id!);
          });
    final rootsLearnt =
        allCards
            ?.where((card) => card.kind == CardKind.root && !card.isNew)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: cards == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: cards.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              blurb,
                              style: TextStyle(color: colors.inkMuted),
                            ),
                          );
                        }
                        return _ReadOnceRow(
                          card: cards[index - 1],
                          rootsLearnt: rootsLearnt,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnceRow extends ConsumerWidget {
  const _ReadOnceRow({required this.card, required this.rootsLearnt});

  final Flashcard card;
  final int rootsLearnt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final style = readOnceStyle(context, card);
    final toGo = (card.unlockAfter ?? 0) - rootsLearnt;
    // Read already counts as open: it may have been unlocked on another
    // device, or the roots reset since.
    final open = toGo <= 0 || !card.isNew;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        enabled: open,
        leading: Icon(
          open ? style.icon : Icons.lock_outline,
          color: open ? style.color : colors.inkMuted,
        ),
        title: Text(card.arabicWord),
        subtitle: Text(
          open
              ? (card.transliteration ?? '')
              : 'Opens after $toGo more root${toGo == 1 ? '' : 's'}',
        ),
        trailing: !open
            ? null
            : card.isNew
            ? _NewBadge(color: style.color)
            : Icon(Icons.chevron_right, color: colors.inkMuted),
        onTap: () async {
          final navigator = Navigator.of(context);
          // Reading it here is reading it: it won't interrupt a study
          // session later to be read again.
          if (card.isNew) await CardActions(ref).markSeen(card);
          navigator.push(
            MaterialPageRoute(builder: (_) => WordDetailScreen(card: card)),
          );
        },
      ),
    );
  }
}

/// Marks a card that has opened up and hasn't been read yet.
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          'New',
          style: TextStyle(
            color: context.colors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
