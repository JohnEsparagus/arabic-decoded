import 'dart:convert';
import 'dart:io';

import 'package:arabic_decoded/config/campaign_sources.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/repositories/local_flashcard_repository.dart';
import 'package:arabic_decoded/services/content_importer.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late List<Flashcard> all;

  final quranList =
      (json.decode(File(quranSource.assetPath).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  String rootOf(Map<String, dynamic> entry) =>
      (entry['arabic'] ?? entry['root']) as String;

  setUp(() async {
    db = DatabaseService(pathOverride: inMemoryDatabasePath);
    await ContentImporter(LocalFlashcardRepository(db)).importAll();
    all = await db.getAllFlashcards();
  });

  List<Flashcard> quranRoots() =>
      all.where((c) => c.quranRank != null).toList()
        ..sort((a, b) => a.quranRank!.compareTo(b.quranRank!));

  test('every root on the Quran list is one card, in list order', () {
    final roots = quranRoots();
    expect(roots.map((c) => c.arabicWord), quranList.map(rootOf));
    expect(roots.map((c) => c.kind), everyElement(CardKind.root));
    // Only roots are ranked.
    expect(
      all.where((c) => c.quranRank != null && c.kind != CardKind.root),
      isEmpty,
    );
  });

  test('no root is taught twice, anywhere', () {
    final roots = all.where((c) => c.kind == CardKind.root);
    final letters = roots.map((c) => c.arabicWord).toList();
    expect(letters.toSet().length, letters.length);
  });

  test('a root learnt in its campaign is learnt on the Quran list', () async {
    // ق و ل is taught in Absolute Core and is near the top of the list.
    final qwl = all.singleWhere((c) => c.arabicWord == 'ق و ل');
    expect(qwl.quranRank, isNotNull);
    await db.updateFlashcard(qwl.copyWith(isNew: false, interval: 5));
    all = await db.getAllFlashcards();
    final onList = quranRoots().singleWhere((c) => c.arabicWord == 'ق و ل');
    expect(onList.id, qwl.id);
    expect(onList.isNew, isFalse);
  });

  test('off, the Quran-only roots stay out of new cards; on, the list '
      'comes first, most common first', () async {
    final quranDeck = await db.getOrCreateDeck(quranSource.deckName);

    var queue = await db.getNewFlashcards(
      limit: 1000,
      includeWords: false,
      includeLetters: false,
    );
    expect(queue.where((c) => c.deckId == quranDeck.id), isEmpty);
    expect(queue.first.arabicWord, 'ك ت ب'); // Absolute Core, as before

    queue = await db.getNewFlashcards(
      limit: 1000,
      includeWords: false,
      includeLetters: false,
      quranFirst: true,
    );
    final expected = quranList.map(rootOf).toList();
    expect(queue.take(expected.length).map((c) => c.arabicWord), expected);
    // The rest of the roots follow, in campaign order.
    expect(queue[expected.length].quranRank, isNull);
    // And a root already learnt isn't offered again.
    final first = queue.first;
    await db.updateFlashcard(first.copyWith(isNew: false));
    queue = await db.getNewFlashcards(
      limit: 3,
      includeWords: false,
      includeLetters: false,
      quranFirst: true,
    );
    expect(queue.first.arabicWord, expected[1]);
  });

  test('a root taken off the list stops counting as Quranic', () async {
    await db.setRootRanks(RootList.quran, {'ق و ل': 1});
    all = await db.getAllFlashcards();
    expect(quranRoots().map((c) => c.arabicWord), ['ق و ل']);
  });

  group('the frequency list', () {
    final list =
        (json.decode(File(frequencySource.assetPath).readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();

    List<Flashcard> ranked() =>
        all.where((c) => c.frequencyRank != null).toList()
          ..sort((a, b) => a.frequencyRank!.compareTo(b.frequencyRank!));

    test('every root on it is one card, in list order, each with a '
        'mnemonic', () {
      expect(ranked().map((c) => c.arabicWord), list.map(rootOf));
      expect(ranked().map((c) => c.kind), everyElement(CardKind.root));
      for (final card in ranked()) {
        expect(card.mnemonic, isNotEmpty, reason: card.arabicWord);
        expect(card.transliteration, isNotEmpty, reason: card.arabicWord);
      }
    });

    test('a root it shares with a campaign is the same card', () {
      final root = all.singleWhere((c) => c.arabicWord == 'ك ت ب');
      expect(root.frequencyRank, 1);
    });

    test('its own roots only reach the queue when picked', () async {
      final deck = await db.getOrCreateDeck(frequencySource.deckName);
      for (final quranFirst in [false, true]) {
        final queue = await db.getNewFlashcards(
          limit: 2000,
          quranFirst: quranFirst,
        );
        expect(queue.where((c) => c.deckId == deck.id), isEmpty);
      }
      final picked = all.singleWhere((c) => c.arabicWord == 'ض ر ب');
      await db.setQueued(picked.id!, true);
      expect((await db.getQueuedFlashcards()).single.id, picked.id);
    });
  });
}
