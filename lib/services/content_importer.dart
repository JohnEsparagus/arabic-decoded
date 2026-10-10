import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../config/campaign_sources.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../repositories/flashcard_repository.dart';

/// Imports flashcards from a bundled JSON asset into a named deck.
///
/// The JSON is a flat array of entries shaped like assets/data/*.json —
/// each needs at least `arabic` and `meaning`; `example`, `translit`,
/// `mnemonic` and `words` (related word forms) are all optional:
///
/// ```json
/// [
///   {
///     "arabic": "ك ت ب",
///     "meaning": "Writing",
///     "translit": "k-t-b",
///     "mnemonic": "Imagine a writer carrying books into a library.",
///     "words": ["كتاب", "كاتب", "مكتبة"],
///     "example": "A كاتب works in a مكتبة."
///   }
/// ]
/// ```
///
/// Re-running an import is safe and non-destructive: existing cards are
/// matched by [Flashcard.arabicWord] within the deck and left untouched
/// (so SM-2 review progress survives), and only new entries get inserted.
/// That's what makes this "content-management friendly" — appending new
/// words to the JSON file and relaunching picks them up without resetting
/// anyone's review history, unlike a one-time "seed if empty" pass.
class ContentImporter {
  ContentImporter(this._repository);

  final FlashcardRepository _repository;

  /// Imports every campaign in [sources] (defaults to [campaignSources]),
  /// in order. Sequential — not parallel — so decks get created in list
  /// order, which is what makes campaign progression deterministic (see
  /// [CampaignSource]'s doc comment).
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

    final existingWords = (await _repository.getFlashcardsForDeck(
      deck.id!,
    )).map((card) => card.arabicWord).toSet();

    for (final entry in entries) {
      final arabic = entry['arabic'] as String?;
      if (arabic == null || arabic.isEmpty || existingWords.contains(arabic)) {
        continue;
      }
      final words = entry['words'];
      await _repository.insertFlashcard(
        Flashcard.newCard(
          arabicWord: arabic,
          englishTranslation: entry['meaning'] as String? ?? '',
          exampleSentence: entry['example'] as String? ?? '',
          deckId: deck.id!,
          transliteration: entry['translit'] as String?,
          mnemonic: entry['mnemonic'] as String?,
          relatedWords: words is List ? words.cast<String>() : const [],
        ),
      );
    }
    return deck;
  }

  Future<List<Map<String, dynamic>>> _loadEntries(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
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
