import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../providers/sentence_providers.dart';
import '../screens/word_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/spoken_text.dart';
import 'card_actions_sheet.dart';
import 'gold_diamond.dart';
import 'sentence_text.dart';
import 'sentence_tile.dart';
import 'speak_button.dart';

/// The "back of the card" content: Arabic word, transliteration, English
/// meaning, a mnemonic tip, an example sentence, and the cards this one is
/// linked to — every section is optional and only renders if the card
/// actually has that data, so new content fields can be added to
/// [Flashcard] and shown here without touching every place that displays a
/// card.
///
/// Roots are what everything hangs off, so that's where the links go: a
/// root lists the words built from it, and a word links back to its root.
/// Both are tappable.
///
/// Used both inside the study screen's flip animation and standalone in
/// [WordDetailScreen], so the two always stay visually in sync.
class FlashcardDetailContent extends ConsumerWidget {
  const FlashcardDetailContent({super.key, required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (card.kind == CardKind.info) return _InfoContent(card: card);
    final allCards =
        ref.watch(allFlashcardsProvider).asData?.value ?? const <Flashcard>[];
    // Words and letters have a real piece of Arabic as their example,
    // shown as such; a root's is an English sentence with Arabic in it.
    final arabicExample =
        card.kind == CardKind.word || card.kind == CardKind.letter;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.kind == CardKind.sentence)
            SentenceText(
              card.arabicWord,
              fontSize: 28,
              textAlign: TextAlign.center,
            )
          else
            Text(
              card.arabicWord,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: arabicTextStyle(context, fontSize: 32, color: colors.ink),
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
          if (card.kind == CardKind.root && card.quranRank != null)
            const _QuranMark(),
          SpeakButton(text: spokenText(card)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: GoldDiamond(),
          ),
          const SizedBox(height: 10),
          Text(
            card.englishTranslation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.deepGreen,
            ),
          ),
          if (card.note != null && card.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.note!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.inkMuted),
            ),
          ],
          if (card.mnemonic != null && card.mnemonic!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MnemonicTip(text: card.mnemonic!),
          ],
          if (card.kind == CardKind.word) ..._rootLink(allCards),
          if (card.kind == CardKind.letter && card.relatedWords.length == 4)
            _LetterForms(forms: card.relatedWords),
          if (card.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              card.exampleSentence,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: arabicTextStyle(
                context,
                fontSize: arabicExample ? 22 : 18,
                fontWeight: FontWeight.w400,
                color: arabicExample ? colors.ink : colors.inkMuted,
              ),
            ),
            if (card.exampleTranslation != null &&
                card.exampleTranslation!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                card.exampleTranslation!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.inkMuted),
              ),
              SpeakButton(text: card.exampleSentence),
            ],
          ],
          if (card.kind == CardKind.root) ..._wordsFromRoot(allCards, colors),
          if (card.id != null &&
              (card.kind == CardKind.word || card.kind == CardKind.root))
            _SentencesSection(cardId: card.id!),
        ],
      ),
    );
  }

  /// The root a word is built from.
  List<Widget> _rootLink(List<Flashcard> allCards) {
    final root = allCards
        .where(
          (other) =>
              other.kind == CardKind.root &&
              other.deckId == card.deckId &&
              other.arabicWord == card.rootKey,
        )
        .firstOrNull;
    if (root == null) return const [];
    return [const SizedBox(height: 18), _RootLink(root: root)];
  }

  /// A root's words, in the order the content lists them. Anything listed
  /// that has no card of its own (plain-string words) is still shown, just
  /// not tappable.
  List<Widget> _wordsFromRoot(List<Flashcard> allCards, AppColors colors) {
    if (card.relatedWords.isEmpty) return const [];
    final wordCards = {
      for (final other in allCards)
        if (other.kind == CardKind.word &&
            other.deckId == card.deckId &&
            other.rootKey == card.arabicWord)
          other.arabicWord: other,
    };
    return [
      const SizedBox(height: 20),
      if (wordCards.isNotEmpty) ...[
        const _SectionLabel('Words from this root'),
        const SizedBox(height: 8),
      ],
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: card.relatedWords.map((word) {
          final wordCard = wordCards[word];
          if (wordCard != null) return _LinkChip(card: wordCard);
          return Chip(
            label: Text(word, textDirection: TextDirection.rtl),
            backgroundColor: colors.parchmentDark,
            side: BorderSide(color: colors.cardBorder),
          );
        }).toList(),
      ),
    ];
  }
}

/// What sets one sort of read-once card apart from another, and all of
/// them from the cards that are studied: an accent colour and an icon,
/// picked by the card's label.
({Color color, IconData icon}) readOnceStyle(
  BuildContext context,
  Flashcard card,
) {
  final colors = context.colors;
  return switch (card.englishTranslation) {
    'Lesson' => (color: colors.deepGreen, icon: Icons.school_outlined),
    'Story' => (color: colors.gold, icon: Icons.auto_stories_outlined),
    _ => (color: colors.inkMuted, icon: Icons.lightbulb_outline),
  };
}

/// A read-once card: a lesson, a story, or anything else there is to tell.
/// Laid out as a page to read, not a card to recall: a labelled badge in
/// its accent colour, a title, an optional Arabic headline, the text, and
/// any worked examples. An example that's a word the app teaches opens
/// that word.
class _InfoContent extends ConsumerWidget {
  const _InfoContent({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final style = readOnceStyle(context, card);
    final examples = card.relatedWords.map(ReadOnceExample.decode).toList();
    final words = {
      for (final other
          in ref.watch(allFlashcardsProvider).asData?.value ??
              const <Flashcard>[])
        if (other.kind == CardKind.word) other.arabicWord: other,
    };

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card.englishTranslation.isNotEmpty)
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 16, color: colors.ink),
                      const SizedBox(width: 6),
                      _SectionLabel(card.englishTranslation),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            card.arabicWord,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
          if (card.note != null && card.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              card.note!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: arabicTextStyle(
                context,
                fontSize: 30,
                color: colors.deepGreen,
              ),
            ),
            if (card.transliteration != null)
              Text(
                card.transliteration!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
          const SizedBox(height: 14),
          // A short rule in the accent colour, in place of the diamond the
          // study cards have.
          Center(child: Container(width: 44, height: 3, color: style.color)),
          const SizedBox(height: 16),
          Text(
            card.exampleSentence,
            style: TextStyle(
              color: colors.ink,
              height: 1.5,
              fontSize: 16,
              fontFamilyFallback: arabicFallback(context),
            ),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final example in examples)
                      _ExampleRow(
                        example: example,
                        card: words[example.arabic],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One example on a read-once card: what it means on the left, the Arabic
/// on the right. With a [card] behind it, tapping opens that card.
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example, required this.card});

  final ReadOnceExample example;
  final Flashcard? card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = this.card;
    return InkWell(
      onTap: card == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WordDetailScreen(card: card)),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(example.meaning, style: TextStyle(color: colors.ink)),
                  if (example.translit.isNotEmpty)
                    Text(
                      example.translit,
                      style: TextStyle(
                        color: colors.inkMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              example.arabic,
              textDirection: TextDirection.rtl,
              style: arabicTextStyle(context, fontSize: 22, color: colors.ink),
            ),
            if (card != null)
              Icon(Icons.chevron_right, size: 18, color: colors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// How a letter is written depending on where it falls in a word, laid
/// out right to left the way it would be read.
class _LetterForms extends StatelessWidget {
  const _LetterForms({required this.forms});

  /// Alone, then at the start, middle and end of a word.
  final List<String> forms;

  static const _positions = ['Alone', 'Start', 'Middle', 'End'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (index, form) in forms.indexed)
            Column(
              children: [
                Text(
                  form,
                  textDirection: TextDirection.rtl,
                  style: arabicTextStyle(
                    context,
                    fontSize: 30,
                    color: colors.ink,
                  ),
                ),
                Text(
                  _positions[index],
                  style: TextStyle(color: colors.inkMuted, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A closed "Sentences" heading that opens to the sentences this card's
/// word appears in. Closed by default so the card stays uncluttered, and
/// so nothing is looked up until someone actually wants to see them.
class _SentencesSection extends StatefulWidget {
  const _SentencesSection({required this.cardId});

  final int cardId;

  @override
  State<_SentencesSection> createState() => _SentencesSectionState();
}

class _SentencesSectionState extends State<_SentencesSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SectionLabel('Sentences'),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Consumer(
              builder: (context, ref, _) {
                final sentences = ref.watch(
                  sentencesForCardProvider(widget.cardId),
                );
                return sentences.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, stack) => Text(
                    'Could not load sentences.',
                    style: TextStyle(color: colors.inkMuted),
                  ),
                  data: (sentences) => sentences.isEmpty
                      ? Text(
                          'No sentences with this word yet.',
                          style: TextStyle(color: colors.inkMuted),
                        )
                      : Column(
                          children: [
                            for (final sentence in sentences)
                              SentenceTile(sentence: sentence, dense: true),
                          ],
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Says that a root is one of the Quran's most common.
class _QuranMark extends StatelessWidget {
  const _QuranMark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: colors.gold),
          const SizedBox(width: 5),
          Text(
            'Common in the Quran',
            style: TextStyle(color: colors.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.colors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

/// A word's way back to its root: the root's letters and meaning in one
/// tappable row, opening the root's own page.
class _RootLink extends StatelessWidget {
  const _RootLink({required this.root});

  final Flashcard root;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(14);
    return Material(
      color: colors.parchmentDark,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => WordDetailScreen(card: root))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SectionLabel('From the root'),
                    Text(
                      root.englishTranslation,
                      style: TextStyle(color: colors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                root.arabicWord,
                textDirection: TextDirection.rtl,
                style: arabicTextStyle(
                  context,
                  fontSize: 24,
                  color: colors.deepGreen,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: colors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable link to another card: its Arabic with the meaning
/// underneath, opening that card's own detail page.
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(14);
    return Material(
      color: colors.parchmentDark,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => WordDetailScreen(card: card))),
        onLongPress: () => showCardActions(context, card),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.arabicWord,
                  textDirection: TextDirection.rtl,
                  style: arabicTextStyle(
                    context,
                    fontSize: 20,
                    color: colors.ink,
                  ),
                ),
                Text(
                  card.englishTranslation,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
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
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.lightbulb_outline, size: 18, color: colors.ink),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: colors.ink,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
