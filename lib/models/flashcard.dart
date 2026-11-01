import 'dart:convert';

/// What a [Flashcard] teaches. A root (ك ت ب) is the starting point; a
/// word (كِتَاب) is built from a root and usually a pattern; a pattern
/// (فِعَال) is the vowel-and-affix shape words are poured into. A letter
/// (ب) is one of the alphabet's 28, for someone who can't read the script
/// yet. A sentence is a whole one to read and understand.
///
/// [info] is the odd one out: not something to memorise but something to
/// read once (a story, a fact, a word of encouragement). It's never
/// graded or reviewed; it's shown at a set point along the way and then
/// it's done. See [Flashcard.unlockAfter].
enum CardKind {
  root,
  word,
  pattern,
  letter,
  sentence,
  info;

  static CardKind fromName(String? name) => CardKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => CardKind.root,
  );
}

/// An ordered list of roots that spans the campaigns. Each is stored as a
/// rank on the root's own card, so a root is one card however many lists
/// it's on.
enum RootList {
  quran('quran_rank'),
  frequency('frequency_rank');

  const RootList(this.column);

  final String column;
}

/// One worked example on a read-once card: a word, how it's said and what
/// it means. A card's examples are kept in [Flashcard.relatedWords], which
/// holds plain strings, so each one is packed into a single string there.
class ReadOnceExample {
  const ReadOnceExample({
    required this.arabic,
    required this.translit,
    required this.meaning,
  });

  final String arabic;
  final String translit;
  final String meaning;

  /// Tab-separated: a character none of the three parts would contain.
  String encode() => '$arabic\t$translit\t$meaning';

  factory ReadOnceExample.decode(String packed) {
    final parts = packed.split('\t');
    return ReadOnceExample(
      arabic: parts[0],
      translit: parts.length > 1 ? parts[1] : '',
      meaning: parts.length > 2 ? parts[2] : '',
    );
  }
}

/// A single spaced-repetition flashcard belonging to a [Deck].
///
/// The scheduling fields (`interval`, `repetitions`, `next_review`,
/// `stability`, `difficulty`) are owned by the scheduler (see
/// `lib/services/scheduler.dart`) — nothing else should mutate them
/// directly. `ease_factor` is left over from the SM-2 scheduler the app
/// used before; it's only read to convert a card SM-2 last scheduled.
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
///
/// [kind], [rootKey] and [patternKey] are what link cards to each other:
/// a word's [rootKey] is the [arabicWord] of its root card (in the same
/// deck), and its [patternKey] is the [patternKey] of a pattern card. A
/// pattern card carries its own key there, so "every word with this
/// pattern" is one comparison.
class Flashcard {
  final int? id;
  final String arabicWord;
  final String englishTranslation;
  final String exampleSentence;
  final int deckId;
  final double easeFactor;
  final int interval;
  final int repetitions;

  /// FSRS's state for the card: how many days its memory lasts, and how
  /// hard it is (1-10). Null until it's graded under FSRS.
  final double? stability;
  final double? difficulty;
  final DateTime nextReview;
  final bool isNew;
  final DateTime? introducedAt;
  final String? transliteration;
  final String? mnemonic;
  final List<String> relatedWords;
  final CardKind kind;
  final String? rootKey;
  final String? patternKey;

  /// English translation of [exampleSentence], when that is a real Arabic
  /// sentence (word cards) rather than an English one with Arabic in it.
  final String? exampleTranslation;

  /// A short extra line under the meaning, e.g. a verb's present tense.
  final String? note;

  /// For an [CardKind.info] card: how many roots have to have been
  /// introduced before it's shown. Null or 0 shows it straight away.
  final int? unlockAfter;

  /// Starred by the user. Like [queuedAt], this is read from the database
  /// but never written back by [toMap]: each has its own setter on
  /// `DatabaseService`, so saving a card that was loaded a while ago (the
  /// one being graded, say) can't undo a star added in the meantime.
  final bool isFavorite;

  /// When the user asked for this still-new card to be put in their queue,
  /// ahead of whatever would have come next. Null if they haven't.
  final DateTime? queuedAt;

  /// When the card was last graded, which the scheduler needs to know how
  /// long it has been. Read from the database like [isFavorite]; the write
  /// that grades a card stamps it.
  final DateTime? lastReviewedAt;

  /// For a root that's among the Quran's most common, its place in that
  /// list (1 = the most common); null otherwise. Set by the importer from
  /// assets/data/quran.json and, like [isFavorite], never written back by
  /// [toMap].
  final int? quranRank;

  /// The same for the frequency list.
  final int? frequencyRank;

  const Flashcard({
    this.id,
    required this.arabicWord,
    required this.englishTranslation,
    required this.exampleSentence,
    required this.deckId,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.stability,
    this.difficulty,
    required this.nextReview,
    this.isNew = true,
    this.introducedAt,
    this.transliteration,
    this.mnemonic,
    this.relatedWords = const [],
    this.kind = CardKind.root,
    this.rootKey,
    this.patternKey,
    this.exampleTranslation,
    this.note,
    this.unlockAfter,
    this.isFavorite = false,
    this.queuedAt,
    this.lastReviewedAt,
    this.quranRank,
    this.frequencyRank,
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
    CardKind kind = CardKind.root,
    String? rootKey,
    String? patternKey,
    String? exampleTranslation,
    String? note,
    int? unlockAfter,
  }) {
    return Flashcard(
      id: id,
      arabicWord: arabicWord,
      englishTranslation: englishTranslation,
      exampleSentence: exampleSentence,
      deckId: deckId,
      unlockAfter: unlockAfter,
      nextReview: DateTime.now(),
      transliteration: transliteration,
      mnemonic: mnemonic,
      relatedWords: relatedWords,
      kind: kind,
      rootKey: rootKey,
      patternKey: patternKey,
      exampleTranslation: exampleTranslation,
      note: note,
    );
  }

  factory Flashcard.fromMap(Map<String, Object?> map) {
    final relatedWordsJson = map['related_words'] as String?;
    final introducedAtMs = map['introduced_at'] as int?;
    final queuedAtMs = map['queued_at'] as int?;
    return Flashcard(
      id: map['id'] as int?,
      arabicWord: map['arabic_word'] as String,
      englishTranslation: map['english_translation'] as String,
      exampleSentence: map['example_sentence'] as String,
      deckId: map['deck_id'] as int,
      easeFactor: (map['ease_factor'] as num).toDouble(),
      interval: map['interval'] as int,
      repetitions: map['repetitions'] as int,
      stability: (map['stability'] as num?)?.toDouble(),
      difficulty: (map['difficulty'] as num?)?.toDouble(),
      quranRank: map['quran_rank'] as int?,
      frequencyRank: map['frequency_rank'] as int?,
      lastReviewedAt: map['updated_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
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
      kind: CardKind.fromName(map['kind'] as String?),
      rootKey: map['root_key'] as String?,
      patternKey: map['pattern_key'] as String?,
      exampleTranslation: map['example_translation'] as String?,
      note: map['note'] as String?,
      unlockAfter: map['unlock_after'] as int?,
      isFavorite: (map['favorite'] as int? ?? 0) != 0,
      queuedAt: queuedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(queuedAtMs),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'arabic_word': arabicWord,
      'deck_id': deckId,
      'ease_factor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'stability': stability,
      'difficulty': difficulty,
      'next_review': nextReview.millisecondsSinceEpoch,
      'is_new': isNew ? 1 : 0,
      'introduced_at': introducedAt?.millisecondsSinceEpoch,
      ...contentMap(),
    };
  }

  /// Just the columns that come from the bundled content, none of the
  /// SM-2 progress — what a content refresh is allowed to overwrite.
  Map<String, Object?> contentMap() {
    return {
      'english_translation': englishTranslation,
      'example_sentence': exampleSentence,
      'transliteration': transliteration,
      'mnemonic': mnemonic,
      'related_words': json.encode(relatedWords),
      'kind': kind.name,
      'root_key': rootKey,
      'pattern_key': patternKey,
      'example_translation': exampleTranslation,
      'note': note,
      'unlock_after': unlockAfter,
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
    double? stability,
    double? difficulty,
    DateTime? nextReview,
    bool? isNew,
    DateTime? introducedAt,
    String? transliteration,
    String? mnemonic,
    List<String>? relatedWords,
    CardKind? kind,
    String? rootKey,
    String? patternKey,
    String? exampleTranslation,
    String? note,
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
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      nextReview: nextReview ?? this.nextReview,
      isNew: isNew ?? this.isNew,
      introducedAt: introducedAt ?? this.introducedAt,
      transliteration: transliteration ?? this.transliteration,
      mnemonic: mnemonic ?? this.mnemonic,
      relatedWords: relatedWords ?? this.relatedWords,
      kind: kind ?? this.kind,
      rootKey: rootKey ?? this.rootKey,
      patternKey: patternKey ?? this.patternKey,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      note: note ?? this.note,
      unlockAfter: unlockAfter,
      isFavorite: isFavorite,
      queuedAt: queuedAt,
      lastReviewedAt: lastReviewedAt,
      quranRank: quranRank,
      frequencyRank: frequencyRank,
    );
  }
}
