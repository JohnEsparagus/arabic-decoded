import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sentence_providers.dart';
import '../theme/app_theme.dart';
import '../utils/mastery_level.dart';
import '../utils/sentence_tokens.dart';

/// An Arabic sentence with each word the user is studying underlined in
/// the colour of how well they know it (the same colours as the stats
/// chart). Words the app doesn't teach, or that haven't been started, are
/// left plain.
///
/// The colour is an underline rather than the text colour so the sentence
/// stays as readable as any other, and so it isn't colour alone doing the
/// telling: an underlined word is one being learned.
class SentenceText extends ConsumerWidget {
  const SentenceText(
    this.sentence, {
    super.key,
    this.fontSize = 22,
    this.textAlign = TextAlign.start,
  });

  final String sentence;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(wordMasteryProvider);
    final base = arabicTextStyle(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: context.colors.ink,
    );

    MasteryLevel? levelOf(String word) {
      for (final key in wordKeys(word)) {
        final level = levels[key];
        if (level != null && level != MasteryLevel.unlearned) return level;
      }
      return null;
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final piece in splitSentence(sentence))
            if (piece.isWord && levelOf(piece.text) != null)
              TextSpan(
                text: piece.text,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: masteryChartColor(
                    context,
                    levelOf(piece.text)!,
                  ),
                  decorationThickness: 2.5,
                ),
              )
            else
              TextSpan(text: piece.text),
        ],
      ),
      style: base,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
    );
  }
}

/// The key to [SentenceText]'s underlines: each level's colour and name.
class MasteryLegend extends StatelessWidget {
  const MasteryLegend({super.key});

  static const _levels = [
    MasteryLevel.weak,
    MasteryLevel.learning,
    MasteryLevel.strong,
    MasteryLevel.mastered,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final level in _levels)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 3,
                color: masteryChartColor(context, level),
              ),
              const SizedBox(width: 5),
              Text(
                masteryLabel(level),
                style: TextStyle(color: colors.inkMuted, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}
