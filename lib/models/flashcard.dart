import 'dart:convert';

/// A single spaced-repetition flashcard belonging to a [Deck].
///
/// The `ease_factor`, `interval`, `repetitions` and `next_review` fields are
/// owned by the SM-2 engine (see `lib/services/sm2.dart`) — nothing else
/// should mutate them directly.
///
/// [isNew] distinguishes cards that have never been studied from cards in
/// the SM-2 review rotation: new cards don't show up in the due-for-review
/// queue and are introduced separately, gated by a daily cap (see
/// `lib/providers/study_session_provider.dart`). [introducedAt] is set the
/// moment a card is first graded, i.e. when it stops being new.
///
/// [transliteration], [mnemonic] and [relatedWords] are optional "richer
/// back side" content — nothing renders them unless they're present, so new
/// content sources can leave them out entirely.
class Flashcard {
  final int? id;
  final String arabicWord;
  final String englishTranslation;
  final String exampleSentence;
  final int deckId;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;
  final bool isNew;
  final DateTime? introducedAt;
  final String? transliteration;
  final String? mnemonic;
  final List<String> relatedWords;

  const Flashcard({
    this.id,
    required this.arabicWord,
    required this.englishTranslation,
    required this.exampleSentence,
    required this.deckId,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    required this.nextReview,
    this.isNew = true,
    this.introducedAt,
    this.transliteration,
    this.mnemonic,
    this.relatedWords = const [],
  });

  /// A brand-new card, due immediately, with default SM-2 parameters. Stays
  /// out of the review queue until it's introduced for the first time.
  factory Flashcard.newCard({
    int? id,
    required String arabicWord,
    required String englishTranslation,
    required String exampleSentence,
    required int deckId,
    String? transliteration,
    String? mnemonic,
    List<String> relatedWords = const [],
  }) {
    return Flashcard(
      id: id,
      arabicWord: arabicWord,
      englishTranslation: englishTranslation,
      exampleSentence: exampleSentence,
      deckId: deckId,
      nextReview: DateTime.now(),
      transliteration: transliteration,
      mnemonic: mnemonic,
      relatedWords: relatedWords,
    );
  }

  factory Flashcard.fromMap(Map<String, Object?> map) {
    final relatedWordsJson = map['related_words'] as String?;
    final introducedAtMs = map['introduced_at'] as int?;
    return Flashcard(
      id: map['id'] as int?,
      arabicWord: map['arabic_word'] as String,
      englishTranslation: map['english_translation'] as String,
      exampleSentence: map['example_sentence'] as String,
      deckId: map['deck_id'] as int,
      easeFactor: (map['ease_factor'] as num).toDouble(),
      interval: map['interval'] as int,
      repetitions: map['repetitions'] as int,
      nextReview: DateTime.fromMillisecondsSinceEpoch(
        map['next_review'] as int,
      ),
      isNew: (map['is_new'] as int) != 0,
      introducedAt: introducedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(introducedAtMs),
      transliteration: map['transliteration'] as String?,
      mnemonic: map['mnemonic'] as String?,
      relatedWords: relatedWordsJson == null || relatedWordsJson.isEmpty
          ? const []
          : (json.decode(relatedWordsJson) as List).cast<String>(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'arabic_word': arabicWord,
      'english_translation': englishTranslation,
      'example_sentence': exampleSentence,
      'deck_id': deckId,
      'ease_factor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'next_review': nextReview.millisecondsSinceEpoch,
      'is_new': isNew ? 1 : 0,
      'introduced_at': introducedAt?.millisecondsSinceEpoch,
      'transliteration': transliteration,
      'mnemonic': mnemonic,
      'related_words': json.encode(relatedWords),
    };
  }

  Flashcard copyWith({
    int? id,
    String? arabicWord,
    String? englishTranslation,
    String? exampleSentence,
    int? deckId,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReview,
    bool? isNew,
    DateTime? introducedAt,
    String? transliteration,
    String? mnemonic,
    List<String>? relatedWords,
  }) {
    return Flashcard(
      id: id ?? this.id,
      arabicWord: arabicWord ?? this.arabicWord,
      englishTranslation: englishTranslation ?? this.englishTranslation,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      deckId: deckId ?? this.deckId,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReview: nextReview ?? this.nextReview,
      isNew: isNew ?? this.isNew,
      introducedAt: introducedAt ?? this.introducedAt,
      transliteration: transliteration ?? this.transliteration,
      mnemonic: mnemonic ?? this.mnemonic,
      relatedWords: relatedWords ?? this.relatedWords,
    );
  }
}
