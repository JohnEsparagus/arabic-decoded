import 'dart:convert';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/services.dart' show rootBundle;

import '../config/campaign_sources.dart';
import '../models/content_manifest.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../repositories/flashcard_repository.dart';
import '../utils/arabic_normalize.dart';
import '../utils/sentence_tokens.dart';

/// Imports flashcards from a bundled JSON asset into a named deck.
///
/// The JSON is a flat array of roots shaped like assets/data/*.json — each
/// needs at least `arabic` and `meaning`; `translit`,
/// `mnemonic` and `words` are all optional:
///
/// ```json
/// [
///   {
///     "arabic": "ك ت ب",
///     "meaning": "Writing",
///     "translit": "k-t-b",
///     "mnemonic": "Imagine a writer carrying books into a library.",
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

  /// The content manifest, which lists the campaigns and renames.
  Future<ContentManifest> _manifest() async =>
      ContentManifest.parse(await _loadAsset(contentManifestPath));

  /// Imports every campaign the manifest lists,
  /// in order, then everything that isn't a campaign. Sequential — not parallel — so decks get
  /// created in list order, which is what makes campaign progression
  /// deterministic (see [CampaignSource]'s doc comment).
  Future<List<Deck>> importAll() async {
    final manifest = await _manifest();
    // Renamed and moved cards go to their new names first, so the import
    // below finds them there instead of making new ones.
    for (final move in manifest.moves) {
      await _repository.moveCard(
        fromDeck: move.fromDeck,
        from: move.from,
        toDeck: move.toDeck,
        to: move.to,
      );
    }
    final decks = <Deck>[];
    for (final source in manifest.campaigns) {
      decks.add(
        await importAsset(
          assetPath: source.assetPath,
          deckName: source.deckName,
          deckDescription: source.description,
        ),
      );
    }
    decks.add(await importQuran());
    decks.add(await importPatterns());
    decks.add(await importAlphabet());
    for (final source in readOnceSources) {
      await importReadOnce(source);
    }
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
    await _storeRoots(deck, await _loadEntries(assetPath));
    return deck;
  }

  /// Imports assets/data/quran.json: an ordered list of the Quran's most
  /// common roots. An entry is either a reference to a root another
  /// campaign teaches, or a whole root entry like a campaign's for one
  /// that no campaign has:
  ///
  /// ```json
  /// [
  ///   {"arabic": "أ ل ه", "meaning": "God, deity", "words": [...]},
  ///   {"root": "ق و ل"}
  /// ]
  /// ```
  ///
  /// The whole entries become this deck's cards; then every root on the
  /// list, wherever it lives, is marked with its place in it. So there's
  /// still just one card per root, and progress on it counts in both its
  /// campaign and the Quran list.
  Future<Deck> importQuran([CampaignSource source = quranSource]) async {
    final deck = await _repository.getOrCreateDeck(
      source.deckName,
      description: source.description,
    );
    final entries = await _loadEntries(source.assetPath);
    await _storeRoots(deck, [
      for (final entry in entries)
        if (entry['arabic'] != null) entry,
    ]);
    await _repository.setQuranRanks({
      for (final (index, entry) in entries.indexed)
        (entry['arabic'] ?? entry['root']) as String: index + 1,
    });
    return deck;
  }

  /// Turns campaign-style root entries (each with its words) into cards in
  /// [deck], and stores them.
  Future<void> _storeRoots(
    Deck deck,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
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
          // A root's own card has its English mnemonic; its words carry
          // the real Arabic examples.
          exampleSentence: '',
          deckId: deck.id!,
          transliteration: entry['translit'] as String?,
          mnemonic: entry['mnemonic'] as String?,
          relatedWords: relatedWords,
        ),
      );
      cards.addAll(wordCards);
    }
    await _store(deck, cards);
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

  /// Not part of [importAll]: the corpus is big, and nothing on the first
  /// screen needs it, so it loads in the background once the app is up
  /// (see `sentenceCorpusProvider`).
  ///
  /// Loads assets/data/sentences.json into the sentence corpus, if this
  /// edition of it isn't the one already
  /// loaded. On every launch after the first that's one small query and
  /// nothing else: the file isn't even opened.
  ///
  /// ```json
  /// [{"arabic": "هذا كتاب جديد.", "english": "This is a new book."}]
  /// ```
  ///
  /// The file is the whole corpus: loading a new edition replaces the old
  /// one. Sentences the user has added to their queue are flashcards by
  /// then, and stay whatever happens to the file.
  ///
  /// An edition is the file's hash in the manifest, so it changes by itself
  /// whenever the file does; [edition] overrides that for tests.
  Future<void> importSentences({String? edition}) async {
    final current =
        edition ?? (await _manifest()).files[sentencesSource.assetPath] ?? '';
    if (await _repository.getSentencesVersion() == current) return;
    final entries = await _loadEntries(sentencesSource.assetPath);
    await _repository.replaceSentences(version: current, [
      for (final entry in entries)
        if (entry['arabic'] case final String arabic when arabic.isNotEmpty)
          (
            arabic: arabic,
            english: entry['english'] as String? ?? '',
            search:
                '${normalizeArabic(arabic)}\n'
                '${(entry['english'] as String? ?? '').toLowerCase()}',
            keys: sentenceKeys(arabic),
          ),
    ]);
  }

  /// Imports one file of read-once cards (lessons, stories, anything)
  /// into its deck. These are read rather than learned: each is shown in
  /// the study session once `after_roots` roots have been introduced,
  /// with a single "Continue" button instead of grades.
  ///
  /// ```json
  /// [
  ///   {
  ///     "title": "The doer",
  ///     "body": "A long ā after the first letter gives the one who...",
  ///     "after_roots": 6,
  ///     "arabic": "فَاعِل",
  ///     "translit": "fāʿil",
  ///     "examples": [
  ///       {"arabic": "كَاتِب", "translit": "kātib", "meaning": "writer"}
  ///     ]
  ///   }
  /// ]
  /// ```
  ///
  /// Only `title` is required, and it's what identifies a card, so it has
  /// to be unique within the file. `after_roots` is 0 if left out (shown
  /// at the very start); `label` overrides the file's own; `arabic` is a
  /// headline in Arabic script. An example whose `arabic` is a word the
  /// app teaches links to that word's card.
  ///
  /// The deck mirrors the file: adding an entry adds a card, and deleting
  /// one removes it, whether or not it has been read.
  Future<Deck> importReadOnce(ReadOnceSource source) async {
    final deck = await _repository.getOrCreateDeck(source.deckName);
    final entries = await _loadEntries(source.assetPath);
    await _store(deck, prune: true, [
      for (final entry in entries)
        Flashcard.newCard(
          arabicWord: entry['title'] as String,
          englishTranslation: entry['label'] as String? ?? source.label,
          exampleSentence: entry['body'] as String? ?? '',
          deckId: deck.id!,
          kind: CardKind.info,
          unlockAfter: entry['after_roots'] as int?,
          note: entry['arabic'] as String?,
          transliteration: entry['translit'] as String?,
          relatedWords: [
            for (final example in entry['examples'] as List? ?? const [])
              ReadOnceExample(
                arabic: example['arabic'] as String,
                translit: example['translit'] as String? ?? '',
                meaning: example['meaning'] as String? ?? '',
              ).encode(),
          ],
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
    // New cards are gathered up and written together; see
    // `DatabaseService.insertFlashcards` for why that matters.
    final added = <Flashcard>[];
    for (final card in cards) {
      final stored = existing[card.arabicWord];
      if (stored == null) {
        added.add(card);
        existing[card.arabicWord] = card;
      } else if (!mapEquals(stored.contentMap(), card.contentMap())) {
        await _repository.updateFlashcardContent(card.copyWith(id: stored.id));
      }
    }
    await _repository.insertFlashcards(added);
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
