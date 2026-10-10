import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../theme/app_theme.dart';

/// The "back of the card" content: Arabic word, transliteration, English
/// meaning, a mnemonic tip, an example sentence, and related word forms —
/// every section is optional and only renders if the card actually has
/// that data, so new content fields can be added to [Flashcard] and shown
/// here without touching every place that displays a card.
///
/// Used both inside the study screen's flip animation and standalone in
/// [WordDetailScreen], so the two always stay visually in sync.
class FlashcardDetailContent extends StatelessWidget {
  const FlashcardDetailContent({super.key, required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.arabicWord,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: arabicTextStyle(fontSize: 32, color: colors.ink),
          ),
          if (card.transliteration != null &&
              card.transliteration!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.transliteration!,
              style: TextStyle(
                color: colors.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text('✦', style: TextStyle(color: colors.gold, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            card.englishTranslation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.deepGreen,
            ),
          ),
          if (card.mnemonic != null && card.mnemonic!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MnemonicTip(text: card.mnemonic!),
          ],
          if (card.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              card.exampleSentence,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: arabicTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: colors.inkMuted,
              ),
            ),
          ],
          if (card.relatedWords.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: card.relatedWords
                  .map(
                    (word) => Chip(
                      label: Text(word, textDirection: TextDirection.rtl),
                      backgroundColor: colors.parchmentDark,
                      side: BorderSide(color: colors.cardBorder),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MnemonicTip extends StatelessWidget {
  const _MnemonicTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.goldSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.goldSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(color: colors.ink, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
