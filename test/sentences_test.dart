import 'dart:convert';
import 'dart:io';

import 'package:arabic_decoded/config/campaign_sources.dart';
import 'package:arabic_decoded/models/card_progress.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/repositories/local_flashcard_repository.dart';
import 'package:arabic_decoded/services/content_importer.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/utils/arabic_normalize.dart';
import 'package:arabic_decoded/utils/sentence_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An importer whose sentences.json is [sentences] instead of the bundled
/// file; every other asset is the real one.
ContentImporter _importerWith(
  DatabaseService db,
  List<Map<String, String>> sentences,
) {
  return ContentImporter(
    LocalFlashcardRepository(db),
    loadAsset: (path) async => path == sentencesSource.assetPath
        ? json.encode(sentences)
        : File(path).readAsStringSync(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('finding the dictionary word in a written one', () {
    test('a sentence splits into words and what lies between them', () {
      final pieces = splitSentence('هذا كِتَابٌ جديد.');
      expect(pieces.map((p) => p.text).join(), 'هذا كِتَابٌ جديد.');
      expect(pieces.where((p) => p.isWord).map((p) => p.text), [
        'هذا',
        'كِتَابٌ',
        'جديد',
      ]);
    });

    test('vowel marks, attached particles and the object alif come off', () {
      expect(wordKeys('كِتَاب').first, 'كتاب');
      expect(wordKeys('الكتاب'), contains('كتاب'));
      expect(wordKeys('والكتاب'), contains('كتاب'));
      expect(wordKeys('بالمدرسة'), contains('مدرسة'));
      expect(wordKeys('كتابا'), contains('كتاب'));
      expect(wordKeys('وكتابا'), contains('كتاب'));
      expect(wordKeys('كتابه'), contains('كتاب'));
      expect(wordKeys('بيتنا'), contains('بيت'));
    });

    test('"his book" is not mistaken for "writing"', () {
      // They differ only in the last letter (ه / ة), which search treats
      // as the same and word matching must not.
      expect(wordKeys('كتابه'), isNot(contains(wordKey('كِتَابَة'))));
      expect(wordKey('كِتَابَة'), 'كتابة');
      expect(wordKey('أَكَلَ'), 'اكل');
    });

    test('a short word keeps the letters that only look like particles', () {
      // "ولد" (boy) is not "و" + "لد".
      expect(wordKeys('ولد'), ['ولد']);
      expect(wordKeys('بحر'), ['بحر']);
    });

    test('the word itself always comes first', () {
      for (final word in ['الكتاب', 'ولد', 'كتابا', 'بالبيت']) {
        expect(wordKeys(word).first, word);
      }
    });
  });

  group('the corpus', () {
    late DatabaseService db;

    setUp(() => db = DatabaseService(pathOverride: inMemoryDatabasePath));

    test(
      'the bundled file loads, and is found by search and by word',
      () async {
        final importer = ContentImporter(LocalFlashcardRepository(db));
        await importer.importSentences();
        final total = await db.countSentences();
        expect(total, greaterThan(300));
        expect(await db.getSentencesVersion(), sentencesVersion);

        // Search works in either language, ignoring vowel marks and case.
        final english = await db.searchSentences(search: 'new book', limit: 10);
        expect(english.map((s) => s.arabic), contains('هذا كتاب جديد.'));
        final arabic = await db.searchSentences(
          search: normalizeArabic('كِتَاب'),
          limit: 50,
        );
        expect(arabic, isNotEmpty);
        expect(arabic.map((s) => s.arabic), everyElement(contains('كتاب')));

        // By word: every form of it, particle attached or not.
        final withBook = await db.getSentencesWithWords(['كتاب']);
        expect(withBook.map((s) => s.arabic), contains('هذا كتاب جديد.'));
        expect(
          withBook.any((s) => s.arabic.contains('الكتاب')),
          isTrue,
          reason: 'should find "الكتاب" from "كتاب"',
        );
        expect(await db.getSentencesWithWords(['zzz']), isEmpty);
        expect(await db.getSentencesWithWords([]), isEmpty);
      },
    );

    test('pages come back in order without overlapping', () async {
      await ContentImporter(LocalFlashcardRepository(db)).importSentences();
      final first = await db.searchSentences(limit: 25);
      final second = await db.searchSentences(limit: 25, offset: 25);
      expect(first, hasLength(25));
      expect(second, hasLength(25));
      expect(second.first.id, first.last.id + 1);
      expect({...first, ...second}.map((s) => s.id).toSet(), hasLength(50));
    });

    test('a search with LIKE wildcards in it is taken literally', () async {
      await _importerWith(db, [
        {'arabic': 'واحد', 'english': '100% sure'},
        {'arabic': 'اثنان', 'english': 'under_score'},
        {'arabic': 'ثلاثة', 'english': 'plain'},
      ]).importSentences();
      expect(await db.searchSentences(search: '%', limit: 10), hasLength(1));
      expect(await db.searchSentences(search: '_', limit: 10), hasLength(1));
    });

    test('it loads once per edition, not on every launch', () async {
      var loads = 0;
      final importer = ContentImporter(
        LocalFlashcardRepository(db),
        loadAsset: (path) async {
          loads++;
          return json.encode([
            {'arabic': 'جملة', 'english': 'a sentence'},
          ]);
        },
      );
      await importer.importSentences(version: 1);
      await importer.importSentences(version: 1);
      expect(loads, 1);
      expect(await db.countSentences(), 1);

      // A new edition replaces the old one outright.
      await importer.importSentences(version: 2);
      expect(loads, 2);
      expect(await db.getSentencesVersion(), 2);
    });

    test('a sentence becomes a card only when added, and stops being one '
        'when taken back out untouched', () async {
      await ContentImporter(LocalFlashcardRepository(db)).importSentences();
      expect(await db.getAllFlashcards(), isEmpty);
      final sentence = (await db.searchSentences(limit: 1)).single;
      expect(sentence.isQueued, isFalse);
      expect(sentence.cardId, isNull);

      final cardId = await db.setSentenceQueued(sentence.id, true);
      final card = (await db.getAllFlashcards()).single;
      expect(card.id, cardId);
      expect(card.kind, CardKind.sentence);
      expect(card.arabicWord, sentence.arabic);
      expect(card.englishTranslation, sentence.english);
      expect((await db.getQueuedFlashcards()).single.id, cardId);
      var listed = (await db.searchSentences(limit: 1)).single;
      expect(listed.isQueued, isTrue);
      expect(listed.cardId, cardId);

      // Adding it twice doesn't make two cards.
      expect(await db.setSentenceQueued(sentence.id, true), cardId);
      expect(await db.getAllFlashcards(), hasLength(1));

      expect(await db.setSentenceQueued(sentence.id, false), isNull);
      expect(await db.getAllFlashcards(), isEmpty);

      // Once studied it's a card for good: it's reviewed like any other,
      // whatever the other switches say, and shows as studied in the list.
      await db.setSentenceQueued(sentence.id, true);
      final studied = (await db.getAllFlashcards()).single;
      await db.updateFlashcard(studied.copyWith(isNew: false));
      final due = await db.getDueReviewFlashcards(
        includeWords: false,
        includeLetters: false,
      );
      expect(due.single.kind, CardKind.sentence);
      listed = (await db.searchSentences(limit: 1)).single;
      expect(listed.isStudied, isTrue);
      expect(await db.setSentenceQueued(sentence.id, false), studied.id);
      expect(await db.getAllFlashcards(), hasLength(1));

      // And it never comes up by itself.
      await db.resetFlashcard(studied.id!);
      expect(await db.getNewFlashcards(limit: 100), isEmpty);
    });

    test('a new edition keeps the cards made from the old one', () async {
      final importer = _importerWith(db, [
        {'arabic': 'جملة قديمة', 'english': 'an old sentence'},
      ]);
      await importer.importSentences(version: 1);
      final old = (await db.searchSentences(limit: 1)).single;
      await db.setSentenceQueued(old.id, true);

      await _importerWith(db, [
        {'arabic': 'جملة جديدة', 'english': 'a new sentence'},
      ]).importSentences(version: 2);
      expect(
        (await db.searchSentences(limit: 5)).single.english,
        'a new sentence',
      );
      expect((await db.getAllFlashcards()).single.arabicWord, 'جملة قديمة');
    });

    test('progress for a sentence added on another device makes its card '
        'here', () async {
      await ContentImporter(LocalFlashcardRepository(db)).importSentences();
      final sentence = (await db.searchSentences(limit: 1)).single;
      final now = DateTime.now();
      CardProgress progressFor(String arabic) => CardProgress(
        deckName: sentencesSource.deckName,
        arabicWord: arabic,
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
        nextReview: now.add(const Duration(days: 6)),
        introducedAt: now,
        updatedAt: now,
      );

      final changed = await db.applyRemoteProgress([
        progressFor(sentence.arabic),
        // Not in this device's corpus: nothing to make a card from.
        progressFor('ليست في المجموعة'),
      ]);
      expect(changed, 1);
      final card = (await db.getAllFlashcards()).single;
      expect(card.kind, CardKind.sentence);
      expect(card.arabicWord, sentence.arabic);
      expect(card.isNew, isFalse);
      expect(card.interval, 6);
    });

    test('ten thousand sentences stay fast', () async {
      const words = ['كتاب', 'بيت', 'ولد', 'مدرسة', 'ماء', 'شمس', 'قمر', 'بحر'];
      final corpus = [
        for (var i = 0; i < 10000; i++)
          {
            'arabic':
                'ذهب ال${words[i % 8]} إلى ${words[(i ~/ 8) % 8]} رقم $i.',
            'english': 'Sentence number $i about things.',
          },
      ];
      final watch = Stopwatch()..start();
      await _importerWith(db, corpus).importSentences();
      final loading = watch.elapsedMilliseconds;
      expect(await db.countSentences(), 10000);

      // Every launch after the first: one query, the file never opened.
      watch.reset();
      await _importerWith(db, corpus).importSentences();
      final relaunch = watch.elapsedMilliseconds;

      watch.reset();
      final page = await db.searchSentences(limit: 40, offset: 9000);
      final paging = watch.elapsedMilliseconds;
      expect(page, hasLength(40));

      watch.reset();
      final found = await db.searchSentences(search: 'number 9999', limit: 40);
      final searching = watch.elapsedMilliseconds;
      expect(found.single.english, 'Sentence number 9999 about things.');

      watch.reset();
      final withWord = await db.getSentencesWithWords(['قمر']);
      final lookup = watch.elapsedMilliseconds;
      expect(withWord, hasLength(20));

      // ignore: avoid_print
      print(
        '10k sentences: load ${loading}ms, relaunch ${relaunch}ms, '
        'page ${paging}ms, search ${searching}ms, word lookup ${lookup}ms',
      );
      // Generous ceilings (this also runs on slow CI machines); the
      // printed numbers are what to watch.
      expect(loading, lessThan(15000));
      expect(relaunch, lessThan(100));
      expect(paging, lessThan(250));
      expect(searching, lessThan(500));
      expect(lookup, lessThan(250));
    });
  });

  test('the bundled corpus matches the edition number that ships with '
      'it', () {
    // Sentences are loaded once per edition (sentencesVersion). If the
    // file changes and that number doesn't, nobody who already has the
    // app would ever get the new sentences. So: changed the file? Bump
    // sentencesVersion, then update the fingerprint here.
    const fingerprintOfEdition = (version: 2, bytes: _bytes, sum: _sum);
    final bytes = File(sentencesSource.assetPath).readAsBytesSync();
    final sum = bytes.fold<int>(
      0,
      (sum, byte) => (sum * 31 + byte) % 1000000007,
    );
    expect((
      version: sentencesVersion,
      bytes: bytes.length,
      sum: sum,
    ), fingerprintOfEdition);
  });
}

const _bytes = 50283;
const _sum = 763865031;
