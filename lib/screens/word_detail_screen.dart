import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/flashcard_detail_content.dart';
import '../widgets/flashcard_frame.dart';

/// A standalone page showing one flashcard's "back side" — reached by
/// tapping a word in the Dictionary tab or the Campaigns browser. Reuses
/// the exact same [FlashcardFrame] + [FlashcardDetailContent] the study
/// screen flips to, so a word looks the same everywhere it's shown.
class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(card.englishTranslation)),
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
