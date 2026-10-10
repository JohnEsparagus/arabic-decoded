import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/card_actions_sheet.dart';
import '../widgets/flashcard_detail_content.dart';
import '../widgets/flashcard_frame.dart';

/// A standalone page showing one flashcard's "back side" — reached by
/// tapping a word in the Dictionary tab or the Campaigns browser. Reuses
/// the exact same [FlashcardFrame] + [FlashcardDetailContent] the study
/// screen flips to, so a word looks the same everywhere it's shown. The
/// menu button opens the same actions that holding a card does.
class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.card});

  final Flashcard card;

  /// What the page is called: the meaning, for a root, word or pattern.
  /// A letter's "meaning" is a description of its sound and a sentence's
  /// is a whole sentence, neither of which fits a title bar.
  String get _title => switch (card.kind) {
    CardKind.letter => card.transliteration ?? card.arabicWord,
    CardKind.sentence => 'Sentence',
    _ => card.englishTranslation,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Card options',
            onPressed: () => showCardActions(context, card),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FlashcardFrame(
            child: Center(child: FlashcardDetailContent(card: card)),
          ),
        ),
      ),
    );
  }
}
