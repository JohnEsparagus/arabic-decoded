import 'dart:convert';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/services.dart' show rootBundle;

import '../config/campaign_sources.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../repositories/flashcard_repository.dart';

/// Imports flashcards from a bundled JSON asset into a named deck.
///
/// The JSON is a flat array of roots shaped like assets/data/*.json — each
/// needs at least `arabic` and `meaning`; `example`, `translit`,
/// `mnemonic` and `words` are all optional:
///
/// ```json
/// [
///   {
///     "arabic": "ك ت ب",
///     "meaning": "Writing",
///     "translit": "k-t-b",
///     "mnemonic": "Imagine a writer carrying books into a library.",
///     "example": "A كاتب works in a مكتبة.",
///     "words": [
///       {
///         "arabic": "كِتَاب",
///         "translit": "kitāb",
///         "meaning": "book",
///         "pattern": "fi3al",
///         "example": {"ar": "هذا كتاب جديد.", "en": "This is a new book."}
///       }
///     ]
///   }
/// ]
/// ```
///
/// Each entry in `words` becomes a card of its own in the same deck,
/// linked back to its root and (through `pattern`, an id from
/// patterns.json) to its pattern. A word can also be a bare string, which
/// just lists it on the root without making a card.
///
/// Re-running an import is safe and non-destructive: existing cards are
/// matched by [Flashcard.arabicWord] within the deck, so SM-2 review
/// progress survives. New entries get inserted, and an existing card whose
/// content has changed in the JSON has just its content brought up to
/// date. That's what makes this "content-management friendly" — editing
/// the JSON file and relaunching picks the change up without resetting
/// anyone's review history, unlike a one-time "seed if empty" pass.
class ContentImporter {
  /// [loadAsset] is how a file's text is read; it defaults to the app's
  /// bundled assets, and exists so tests can hand in content of their own.
  ContentImporter(
    this._repository, {
    Future<String> Function(String)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  final FlashcardRepository _repository;
  final Future<String> Function(String assetPath) _loadAsset;

  /// Imports every campaign in [sources] (defaults to [campaignSources]),
  /// in order, then everything that isn't a campaign. Sequential — not parallel — so decks get
  /// created in list order, which is what makes campaign progression
  /// deterministic (see [CampaignSource]'s doc comment).
  Future<List<Deck>> importAll([
    List<CampaignSource> sources = campaignSources,
  ]) async {
    final decks = <Deck>[];
    for (final source in sources) {
      decks.add(
        await importAsset(
          assetPath: source.assetPath,
          deckName: source.deckName,
          deckDescription: source.description,
        ),
      );
    }
    decks.add(await importPatterns());
    decks.add(await importAlphabet());
    decks.add(await importSentences());
    decks.add(await importExtras());
    return decks;
  }

  Future<Deck> importAsset({
    required String assetPath,
    required String deckName,
    String? deckDescription,
  }) async {
    final deck = await _repository.getOrCreateDeck(
      deckName,
      description: deckDescription,
    );
    final entries = await _loadEntries(assetPath);
    if (entries.isEmpty) return deck;

    final cards = <Flashcard>[];
    for (final entry in entries) {
      final arabic = entry['arabic'] as String?;
      if (arabic == null || arabic.isEmpty) continue;

      final relatedWords = <String>[];
      final wordCards = <Flashcard>[];
      final words = entry['words'];
      for (final word in words is List ? words : const []) {
        if (word is String) {
          relatedWords.add(word);
        } else if (word is Map<String, dynamic>) {
          final wordArabic = word['arabic'] as String?;
          if (wordArabic == null || wordArabic.isEmpty) continue;
          final example = word['example'];
          relatedWords.add(wordArabic);
          wordCards.add(
            Flashcard.newCard(
              arabicWord: wordArabic,
              englishTranslation: word['meaning'] as String? ?? '',
              exampleSentence: example is Map ? example['ar'] as String : '',
              exampleTranslation: example is Map
                  ? example['en'] as String?
                  : null,
              deckId: deck.id!,
              transliteration: word['translit'] as String?,
              kind: CardKind.word,
              rootKey: arabic,
              patternKey: word['pattern'] as String?,
              note: word['note'] as String?,
            ),
          );
        }
      }
      cards.add(
        Flashcard.newCard(
          arabicWord: arabic,
          englishTranslation: entry['meaning'] as String? ?? '',
          exampleSentence: entry['example'] as String? ?? '',
          deckId: deck.id!,
          transliteration: entry['translit'] as String?,
          mnemonic: entry['mnemonic'] as String?,
          relatedWords: relatedWords,
        ),
      );
      cards.addAll(wordCards);
    }
    await _store(deck, cards);
    return deck;
  }

  /// Imports assets/data/patterns.json into the [patternsSource] deck, one
  /// card per pattern. Its `id` is what words refer to as their `pattern`.
  Future<Deck> importPatterns([CampaignSource source = patternsSource]) async {
    final deck = await _repository.getOrCreateDeck(
      source.deckName,
      description: source.description,
    );
    final entries = await _loadEntries(source.assetPath);
    await _store(deck, [
      for (final entry in entries)
        Flashcard.newCard(
          arabicWord: entry['arabic'] as String,
          englishTranslation: entry['meaning'] as String? ?? '',
          exampleSentence: '',
          deckId: deck.id!,
          transliteration: entry['translit'] as String?,
          mnemonic: entry['explanation'] as String?,
          kind: CardKind.pattern,
          patternKey: entry['id'] as String,
        ),
    ]);
    return deck;
  }

  /// Imports assets/data/alphabet.json into the [alphabetSource] deck, one
  /// card per letter. A letter's four written forms (alone, then at the
  /// start, middle and end of a word) go in [Flashcard.relatedWords], in
  /// that order, and a word that uses it is its example.
  Future<Deck> importAlphabet([CampaignSource source = alphabetSource]) async {
    final deck = await _repository.getOrCreateDeck(
      source.deckName,
      description: source.description,
    );
    final entries = await _loadEntries(source.assetPath);
    await _store(deck, [
      for (final entry in entries)
        Flashcard.newCard(
          arabicWord: entry['arabic'] as String,
          englishTranslation: entry['sound'] as String? ?? '',
          exampleSentence: (entry['example'] as Map)['ar'] as String,
          exampleTranslation:
              '${(entry['example'] as Map)['translit']} · '
              '${(entry['example'] as Map)['en']}',
          deckId: deck.id!,
          transliteration: entry['name'] as String?,
          mnemonic: entry['tip'] as String?,
          relatedWords: (entry['forms'] as List).cast<String>(),
          kind: CardKind.letter,
          note: entry['joins_next'] == false
              ? 'Never joins to the letter after it'
              : null,
        ),
    ]);
    return deck;
  }

  /// Imports assets/data/sentences.json into the [sentencesSource] deck,
  /// one card per sentence:
  ///
  /// ```json
  /// [{"arabic": "هذا كتاب جديد.", "english": "This is a new book."}]
  /// ```
  ///
  /// `translit` and `note` are optional. The file is the whole corpus:
  /// replace it and sentences that are gone from it disappear from the
  /// app too, except ones the user has already studied.
  Future<Deck> importSentences([
    CampaignSource source = sentencesSource,
  ]) async {
    final deck = await _repository.getOrCreateDeck(
      source.deckName,
      description: source.description,
    );
    final entries = await _loadEntries(source.assetPath);
    await _store(deck, prune: true, [
      for (final entry in entries)
        Flashcard.newCard(
          arabicWord: entry['arabic'] as String,
          englishTranslation: entry['english'] as String? ?? '',
          exampleSentence: '',
          deckId: deck.id!,
          transliteration: entry['translit'] as String?,
          note: entry['note'] as String?,
          kind: CardKind.sentence,
        ),
    ]);
    return deck;
  }

  /// Imports assets/data/extras.json into the [extrasSource] deck: cards
  /// about anything at all, to be read once rather than learned. Each is
  /// shown in the study session once `after_roots` roots have been
  /// introduced, with a single "Continue" button instead of grades:
  ///
  /// ```json
  /// [
  ///   {
  ///     "title": "Why three letters?",
  ///     "label": "Did you know?",
  ///     "body": "Almost every Arabic word grows from a root of three...",
  ///     "after_roots": 10
  ///   }
  /// ]
  /// ```
  ///
  /// `title` is what identifies a card, so it has to be unique; `label`
  /// (the small heading above it) and `after_roots` (0 if left out: shown
  /// at the very start) are optional. Adding an entry adds a card, and
  /// deleting one removes it, whether or not it has been read.
  Future<Deck> importExtras([CampaignSource source = extrasSource]) async {
    final deck = await _repository.getOrCreateDeck(
      source.deckName,
      description: source.description,
    );
    final entries = await _loadEntries(source.assetPath);
    await _store(deck, prune: true, [
      for (final entry in entries)
        Flashcard.newCard(
          arabicWord: entry['title'] as String,
          englishTranslation: entry['label'] as String? ?? '',
          exampleSentence: entry['body'] as String? ?? '',
          deckId: deck.id!,
          kind: CardKind.info,
          unlockAfter: entry['after_roots'] as int?,
        ),
    ]);
    return deck;
  }

  /// Inserts the [cards] the deck doesn't have yet, and refreshes the
  /// content of the ones it does when that has changed.
  ///
  /// With [prune], cards the deck has that aren't in [cards] any more are
  /// deleted, so the deck mirrors its file. A card someone has studied is
  /// kept even then (it's their progress); a read-once card has no
  /// progress worth keeping and always goes.
  Future<void> _store(
    Deck deck,
    List<Flashcard> cards, {
    bool prune = false,
  }) async {
    final existing = {
      for (final card in await _repository.getFlashcardsForDeck(deck.id!))
        card.arabicWord: card,
    };
    for (final card in cards) {
      final stored = existing[card.arabicWord];
      if (stored == null) {
        await _repository.insertFlashcard(card);
        existing[card.arabicWord] = card;
      } else if (!mapEquals(stored.contentMap(), card.contentMap())) {
        await _repository.updateFlashcardContent(card.copyWith(id: stored.id));
      }
    }
    if (!prune) return;
    final wanted = {for (final card in cards) card.arabicWord};
    for (final stored in existing.values) {
      if (stored.id == null || wanted.contains(stored.arabicWord)) continue;
      if (stored.isNew || stored.kind == CardKind.info) {
        await _repository.deleteFlashcard(stored.id!);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadEntries(String assetPath) async {
    try {
      final raw = await _loadAsset(assetPath);
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      // Missing/empty/malformed source file: import nothing rather than
      // crashing the deck it belongs to.
      return [];
    }
  }
}
