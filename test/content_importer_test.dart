import 'dart:io';

import 'package:arabic_decoded/config/campaign_sources.dart';
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

    final deck = await extras.importReadOnce(extrasSource);
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
    await extras.importReadOnce(extrasSource);
    cards = await db.getFlashcardsForDeck(deck.id!);
    expect(cards.single.exampleSentence, 'Rewritten.');
    expect(cards.single.unlockAfter, 5);
    expect(cards.single.id, fact.id);
  });

  test(
    'the whole first-launch import is quick, and a relaunch quicker',
    () async {
      // On a real file, where each separate write waits on the disk: this
      // is what caught the import taking seconds when cards were inserted
      // one at a time.
      final dir = Directory.systemTemp.createTempSync('arabic_decoded_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fileDb = DatabaseService(pathOverride: '${dir.path}/test.db');
      final fileImporter = ContentImporter(LocalFlashcardRepository(fileDb));

      final watch = Stopwatch()..start();
      await fileImporter.importAll();
      final firstLaunch = watch.elapsedMilliseconds;
      final cards = (await fileDb.getAllFlashcards()).length;
      watch.reset();
      await fileImporter.importAll();
      final relaunch = watch.elapsedMilliseconds;

      // ignore: avoid_print
      print('import of $cards cards: ${firstLaunch}ms, relaunch ${relaunch}ms');
      expect(cards, greaterThan(700));
      expect((await fileDb.getAllFlashcards()).length, cards);
      // Generous ceilings for slow machines; one-at-a-time took ~4000ms.
      expect(firstLaunch, lessThan(2500));
      expect(relaunch, lessThan(500));
    },
  );

  test('the lessons and stories that ship are well-formed and point at '
      'real words', () async {
    await importer.importAll();
    final all = await db.getAllFlashcards();
    final words = {
      for (final c in all.where((c) => c.kind == CardKind.word)) c.arabicWord,
    };
    final roots = all.where((c) => c.kind == CardKind.root).length;

    for (final source in [lessonsSource, storiesSource]) {
      final cards = all
          .where(
            (c) =>
                c.kind == CardKind.info && c.englishTranslation == source.label,
          )
          .toList();
      expect(cards.length, greaterThanOrEqualTo(10), reason: source.deckName);
      for (final card in cards) {
        final where = '${source.deckName}: ${card.arabicWord}';
        expect(card.exampleSentence.length, greaterThan(120), reason: where);
        expect(card.note, isNotEmpty, reason: where);
        // Reachable: it opens up before the roots run out.
        expect(card.unlockAfter, inInclusiveRange(1, roots), reason: where);
        final examples = card.relatedWords.map(ReadOnceExample.decode);
        expect(examples, isNotEmpty, reason: where);
        for (final example in examples) {
          expect(example.meaning, isNotEmpty, reason: where);
        }
        // Stories are told with words the app teaches, so every example
        // links to a card. (Lessons also show forms that aren't cards,
        // like a verb's present tense.)
        if (source == storiesSource) {
          for (final example in examples) {
            expect(words, contains(example.arabic), reason: where);
          }
        }
      }
    }
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
    await extras.importReadOnce(extrasSource);
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
