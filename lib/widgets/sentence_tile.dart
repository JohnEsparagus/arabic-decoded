import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sentence.dart';
import '../providers/sentence_providers.dart';
import '../theme/app_theme.dart';
import 'sentence_text.dart';
import 'speak_button.dart';

/// One sentence of the corpus: the Arabic with its words marked by how
/// well they're known, the English, and a button that puts it in the
/// study queue (or takes it back out).
///
/// [dense] drops the card around it, for use inside another card.
class SentenceTile extends ConsumerWidget {
  const SentenceTile({super.key, required this.sentence, this.dense = false});

  final Sentence sentence;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SentenceText(sentence.arabic, fontSize: dense ? 19 : 22),
              const SizedBox(height: 2),
              Text(
                sentence.english,
                style: TextStyle(
                  color: colors.inkMuted,
                  fontSize: dense ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
        SpeakButton(text: sentence.arabic),
        // Once it's being studied there's nothing left to add.
        if (sentence.isStudied)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Tooltip(
              message: 'In your reviews',
              child: Icon(Icons.check, color: colors.inkMuted),
            ),
          )
        else
          IconButton(
            icon: Icon(
              sentence.isQueued ? Icons.check_circle : Icons.add_circle_outline,
            ),
            color: colors.deepGreen,
            visualDensity: VisualDensity.compact,
            tooltip: sentence.isQueued
                ? 'In your queue. Tap to remove'
                : 'Add to my queue',
            onPressed: () => toggleSentenceQueued(ref, sentence),
          ),
      ],
    );
    if (dense) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: content,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
        child: content,
      ),
    );
  }
}
