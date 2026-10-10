import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/repositories/local_flashcard_repository.dart';
import 'package:arabic_decoded/services/content_importer.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/services/sm2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late ContentImporter importer;

  setUp(() {
    db = DatabaseService(pathOverride: inMemoryDatabasePath);
    importer = ContentImporter(LocalFlashcardRepository(db));
  });

  Future<List<Flashcard>> importCore() async {
    await importer.importPatterns();
    final deck = await importer.importAsset(
      assetPath: 'assets/data/campaign_1_absolute_core.json',
      deckName: 'Absolute Core',
    );
    return db.getFlashcardsForDeck(deck.id!);
  }

  test('words become cards linked to their root and pattern', () async {
    final cards = await importCore();

    final root = cards.singleWhere((card) => card.arabicWord == 'ك ت ب');
    expect(root.kind, CardKind.root);
    expect(root.relatedWords, contains('كِتَاب'));

    final word = cards.singleWhere((card) => card.arabicWord == 'كِتَاب');
    expect(word.kind, CardKind.word);
    expect(word.englishTranslation, 'book');
    expect(word.rootKey, root.arabicWord);
    expect(word.exampleSentence, isNotEmpty);
    expect(word.exampleTranslation, isNotEmpty);

    // Every pattern a word names has a card to link to.
    final patternKeys = (await db.getAllFlashcards())
        .where((card) => card.kind == CardKind.pattern)
        .map((card) => card.patternKey)
        .toSet();
    expect(patternKeys, contains(word.patternKey));
    for (final card in cards.where((card) => card.patternKey != null)) {
      expect(patternKeys, contains(card.patternKey), reason: card.arabicWord);
    }
  });

  test('re-importing changes nothing and keeps progress', () async {
    final before = await importCore();
    final root = before.singleWhere((card) => card.arabicWord == 'ك ت ب');
    final result = computeSM2(
      easeFactor: root.easeFactor,
      interval: root.interval,
      repetitions: root.repetitions,
      quality: Grade.good.quality,
    );
    await db.updateFlashcard(
      root.copyWith(
        interval: result.interval,
        repetitions: result.repetitions,
        nextReview: result.nextReview,
        isNew: false,
      ),
    );

    final after = await importCore();
    expect(after.length, before.length);
    final rootAfter = after.singleWhere((card) => card.arabicWord == 'ك ت ب');
    expect(rootAfter.isNew, isFalse);
    expect(rootAfter.repetitions, 1);
  });

  test('a content change refreshes the card without resetting it', () async {
    final cards = await importCore();
    final root = cards.singleWhere((card) => card.arabicWord == 'ك ت ب');
    // Stand in for an install from before words were cards: the root holds
    // the old unvowelled word list and has already been studied.
    await db.updateFlashcard(
      root.copyWith(relatedWords: ['كتاب'], repetitions: 3, isNew: false),
    );

    final rootAfter = (await importCore()).singleWhere(
      (card) => card.arabicWord == 'ك ت ب',
    );
    expect(rootAfter.relatedWords, contains('كِتَاب'));
    expect(rootAfter.repetitions, 3);
    expect(rootAfter.isNew, isFalse);
  });

  test('the alphabet imports as 28 letter cards that come first when '
      'switched on', () async {
    await importCore();
    final deck = await importer.importAlphabet();
    final letters = await db.getFlashcardsForDeck(deck.id!);
    expect(letters, hasLength(28));
    expect(letters.map((card) => card.kind), everyElement(CardKind.letter));

    final ba = letters.singleWhere((card) => card.arabicWord == 'ب');
    expect(ba.transliteration, 'bāʾ');
    expect(ba.relatedWords, hasLength(4)); // alone, start, middle, end
    expect(ba.exampleSentence, 'بَاب');

    var queue = await db.getNewFlashcards(limit: 30);
    expect(
      queue.take(28).map((card) => card.kind),
      everyElement(CardKind.letter),
    );
    expect(queue.first.arabicWord, 'ا');
    expect(queue[28].kind, CardKind.root);

    queue = await db.getNewFlashcards(limit: 30, includeLetters: false);
    expect(queue.map((card) => card.kind), isNot(contains(CardKind.letter)));

    // Same for reviews: a learnt letter only comes back while it's on.
    await db.updateFlashcard(ba.copyWith(isNew: false));
    expect(await db.getDueReviewFlashcards(), hasLength(1));
    expect(await db.getDueReviewFlashcards(includeLetters: false), isEmpty);
  });

  test('sentences import as cards that only enter the queue when asked '
      'for', () async {
    await importCore();
    final deck = await importer.importSentences();
    final sentences = await db.getFlashcardsForDeck(deck.id!);
    expect(sentences.length, greaterThan(300));
    expect(sentences.map((c) => c.kind), everyElement(CardKind.sentence));

    var queue = await db.getNewFlashcards(limit: 1000);
    expect(queue.map((c) => c.kind), isNot(contains(CardKind.sentence)));

    await db.setQueued(sentences.first.id!, true);
    expect((await db.getQueuedFlashcards()).single.id, sentences.first.id);

    // Once studied, it's reviewed whatever the other switches say.
    await db.updateFlashcard(sentences.first.copyWith(isNew: false));
    final due = await db.getDueReviewFlashcards(
      includeWords: false,
      includeLetters: false,
    );
    expect(due.single.kind, CardKind.sentence);
  });

  test('read-once cards follow their file: added, changed and deleted '
      'with it', () async {
    var file = '''[
      {"title": "Welcome", "body": "Start here."},
      {"title": "Why three letters?", "label": "Did you know?",
       "body": "Most words grow from a root.", "after_roots": 10}
    ]''';
    final extras = ContentImporter(
      LocalFlashcardRepository(db),
      loadAsset: (_) async => file,
    );

    final deck = await extras.importExtras();
    var cards = await db.getFlashcardsForDeck(deck.id!);
    expect(cards.map((c) => c.kind), everyElement(CardKind.info));
    final fact = cards.singleWhere((c) => c.arabicWord == 'Why three letters?');
    expect(fact.englishTranslation, 'Did you know?');
    expect(fact.unlockAfter, 10);

    // Reading one, then editing the other and dropping the one that was
    // read: the file is what's left, read or not.
    final welcome = cards.singleWhere((c) => c.arabicWord == 'Welcome');
    await db.markSeen(welcome.id!);
    file = '''[
      {"title": "Why three letters?", "body": "Rewritten.", "after_roots": 5}
    ]''';
    await extras.importExtras();
    cards = await db.getFlashcardsForDeck(deck.id!);
    expect(cards.single.exampleSentence, 'Rewritten.');
    expect(cards.single.unlockAfter, 5);
    expect(cards.single.id, fact.id);
  });

  test('a read-once card turns up once enough roots are introduced, is '
      'read once, and is never reviewed', () async {
    final cards = await importCore();
    final roots = cards.where((c) => c.kind == CardKind.root).toList();
    final extras = ContentImporter(
      LocalFlashcardRepository(db),
      loadAsset: (_) async => '''[
        {"title": "After two", "body": "…", "after_roots": 2},
        {"title": "At the start", "body": "…"}
      ]''',
    );
    await extras.importExtras();
    Future<List<String>> upNext() async => [
      for (final c in await db.getNewFlashcards(limit: 3, includeWords: false))
        c.arabicWord,
    ];

    expect(await upNext(), [
      'At the start',
      roots[0].arabicWord,
      roots[1].arabicWord,
    ]);
    final start = (await db.getNewFlashcards(limit: 1)).single;
    await db.markSeen(start.id!);
    expect((await upNext()).first, roots[0].arabicWord);

    await db.updateFlashcard(roots[0].copyWith(isNew: false));
    expect((await upNext()).first, roots[1].arabicWord);
    await db.updateFlashcard(roots[1].copyWith(isNew: false));
    expect((await upNext()).first, 'After two');

    // Reading isn't studying: nothing in the history, nothing used from
    // the day's new cards, and nothing to review later.
    final afterTwo = (await db.getNewFlashcards(limit: 1)).single;
    await db.markSeen(afterTwo.id!);
    expect((await upNext()).first, roots[2].arabicWord);
    expect(await db.getReviewLog(), hasLength(2));
    expect(await db.countIntroducedSince(DateTime(2000)), 0);
    final due = await db.getDueReviewFlashcards(asOf: DateTime(9000));
    expect(due.map((c) => c.kind), everyElement(CardKind.root));
  });

  test('words of known roots alternate with new roots, when switched '
      'on', () async {
    final cards = await importCore();
    final roots = cards.where((card) => card.kind == CardKind.root).toList();

    // Nothing learnt: no word has a known root, so it's all roots.
    var queue = await db.getNewFlashcards(limit: 500);
    expect(queue.map((card) => card.kind), everyElement(CardKind.root));

    // Learn the first root. Now: the next root, then one of its words led
    // by its not-yet-seen pattern, then the root after that.
    await db.updateFlashcard(roots.first.copyWith(isNew: false));
    queue = await db.getNewFlashcards(limit: 500);
    expect(queue.take(4).map((card) => card.kind), [
      CardKind.root,
      CardKind.pattern,
      CardKind.word,
      CardKind.root,
    ]);
    expect(queue[1].patternKey, queue[2].patternKey);
    expect(
      queue
          .where((card) => card.kind == CardKind.word)
          .map((card) => card.rootKey),
      everyElement(roots.first.arabicWord),
    );

    // With words switched off it's roots only, for new cards and reviews.
    final word = queue[2];
    queue = await db.getNewFlashcards(limit: 500, includeWords: false);
    expect(queue.map((card) => card.kind), everyElement(CardKind.root));
    await db.updateFlashcard(word.copyWith(isNew: false));
    final due = await db.getDueReviewFlashcards(includeWords: false);
    expect(due.map((card) => card.kind), everyElement(CardKind.root));
    expect(await db.getDueReviewFlashcards(), hasLength(due.length + 1));
  });
}
