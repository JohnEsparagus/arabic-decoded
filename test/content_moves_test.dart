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
  setUp(() => db = DatabaseService(pathOverride: inMemoryDatabasePath));

  Future<int> deckId(String name) async => (await db.getOrCreateDeck(name)).id!;

  Future<Flashcard> addCard(String deck, String arabic) async {
    final id = await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: arabic,
        englishTranslation: arabic,
        exampleSentence: '',
        deckId: await deckId(deck),
      ),
    );
    return (await db.getAllFlashcards()).singleWhere((c) => c.id == id);
  }

  Future<Flashcard?> cardAt(String deck, String arabic) async {
    final id = await deckId(deck);
    return (await db.getAllFlashcards())
        .where((c) => c.deckId == id && c.arabicWord == arabic)
        .firstOrNull;
  }

  test(
    'a renamed card keeps its progress and goes up under its new name',
    () async {
      final old = await addCard('Daily Actions', 'ج ا ء');
      await db.updateFlashcard(old.copyWith(isNew: false, interval: 12));
      await db.markProgressSynced(await db.getDirtyProgress());

      await db.moveCard(
        fromDeck: 'Daily Actions',
        from: 'ج ا ء',
        toDeck: 'Daily Actions',
        to: 'ج ي ء',
      );
      expect(await cardAt('Daily Actions', 'ج ا ء'), isNull);
      final moved = (await cardAt('Daily Actions', 'ج ي ء'))!;
      expect(moved.id, old.id);
      expect(moved.interval, 12);
      expect((await db.getDirtyProgress()).single.arabicWord, 'ج ي ء');

      // Running it again (every launch does) changes nothing.
      await db.moveCard(
        fromDeck: 'Daily Actions',
        from: 'ج ا ء',
        toDeck: 'Daily Actions',
        to: 'ج ي ء',
      );
      expect(await db.getAllFlashcards(), hasLength(1));
    },
  );

  test(
    'merging two copies keeps the better-known one and its history',
    () async {
      final first = await addCard('Daily Actions', 'و ص ل');
      final second = await addCard('Abstract Concepts', 'و ص ل');
      await db.updateFlashcard(second.copyWith(isNew: false, interval: 30));
      await db.setFavorite(second.id!, true);
      final collection = await db.createCollection('Mine');
      await db.setInCollection(collection, second.id!, true);

      await db.moveCard(
        fromDeck: 'Abstract Concepts',
        from: 'و ص ل',
        toDeck: 'Daily Actions',
        to: 'و ص ل',
      );
      final kept = (await db.getAllFlashcards()).single;
      expect(kept.id, first.id);
      expect(kept.interval, 30);
      expect(kept.isNew, isFalse);
      expect(kept.isFavorite, isTrue);
      expect((await db.getReviewLog()).map((e) => e.cardId), [first.id]);
      expect(
        (await db.getCollectionFlashcards(collection)).single.id,
        first.id,
      );
    },
  );

  test('when the copy staying put is further along, it keeps its own '
      'progress', () async {
    final first = await addCard('Daily Actions', 'و ص ل');
    final second = await addCard('Abstract Concepts', 'و ص ل');
    await db.updateFlashcard(first.copyWith(isNew: false, interval: 40));
    await db.updateFlashcard(second.copyWith(isNew: false, interval: 3));

    await db.moveCard(
      fromDeck: 'Abstract Concepts',
      from: 'و ص ل',
      toDeck: 'Daily Actions',
      to: 'و ص ل',
    );
    expect((await db.getAllFlashcards()).single.interval, 40);
  });

  test('an install from before the fixes comes through the import with '
      'every bit of progress, and no duplicates', () async {
    // Lay out the cards the way the old content had them, with progress on
    // each, then run the real import.
    final old = {
      'Daily Actions': ['ج ا ء', 'ق ا م', 'م ش ى', 'و ص ل'],
      'Home & Daily Life': ['ب ن ى', 'س ت ع م ل', 'اِسْتَعْمَلَ'],
      'Money & Work': ['ش ر ى', 'ع ط ي', 'ح ت ا ج'],
      'Abstract Concepts': ['و ص ل', 'صِلَة'],
    };
    for (final MapEntry(key: deck, value: cards) in old.entries) {
      for (final arabic in cards) {
        final card = await addCard(deck, arabic);
        await db.updateFlashcard(card.copyWith(isNew: false, interval: 9));
      }
    }

    final importer = ContentImporter(LocalFlashcardRepository(db));
    await importer.importAll();
    final all = await db.getAllFlashcards();

    // Nothing at an old name, nothing twice in a deck.
    for (final move in contentMoves) {
      expect(
        await cardAt(move.fromDeck, move.from),
        isNull,
        reason: '${move.fromDeck} ${move.from}',
      );
    }
    final keys = all.map((c) => '${c.deckId}/${c.arabicWord}').toList();
    expect(keys.toSet().length, keys.length);

    // Everything that had progress still has it, at its new name.
    for (final (deck, arabic) in [
      ('Daily Actions', 'ج ي ء'),
      ('Daily Actions', 'ق و م'),
      ('Daily Actions', 'م ش ي'),
      ('Daily Actions', 'و ص ل'),
      ('Daily Actions', 'صِلَة'),
      ('Home & Daily Life', 'ب ن ي'),
      ('Absolute Core', 'ع م ل'),
      ('Absolute Core', 'اِسْتَعْمَلَ'),
      ('Money & Work', 'ش ر ي'),
      ('Money & Work', 'ع ط و'),
      ('Money & Work', 'ح و ج'),
    ]) {
      final card = await cardAt(deck, arabic);
      expect(card, isNotNull, reason: '$deck $arabic');
      expect(card!.interval, 9, reason: '$deck $arabic');
    }
    // And the moved words now belong to the root they moved to.
    expect((await cardAt('Absolute Core', 'اِسْتَعْمَلَ'))!.rootKey, 'ع م ل');
    expect((await cardAt('Daily Actions', 'صِلَة'))!.rootKey, 'و ص ل');
    // 215 in the campaigns, and the 50 Quranic roots no campaign teaches.
    expect(all.where((c) => c.kind == CardKind.root).length, 265);
  });
}
