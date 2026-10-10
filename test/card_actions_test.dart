import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/utils/mastery_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService db;
  late List<Flashcard> cards;

  Future<Flashcard> reload(Flashcard card) async =>
      (await db.getAllFlashcards()).singleWhere((c) => c.id == card.id);

  setUp(() async {
    db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');
    await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: 'ك ت ب',
        englishTranslation: 'Writing',
        exampleSentence: '',
        deckId: deck.id!,
      ),
    );
    for (final word in ['كِتَاب', 'كَاتِب']) {
      await db.insertFlashcard(
        Flashcard.newCard(
          arabicWord: word,
          englishTranslation: word,
          exampleSentence: '',
          deckId: deck.id!,
          kind: CardKind.word,
          rootKey: 'ك ت ب',
        ),
      );
    }
    cards = await db.getFlashcardsForDeck(deck.id!);
    cards.sort((a, b) => a.id!.compareTo(b.id!));
  });

  test('a queued word is offered even with words off and its root '
      'unlearned, and not twice', () async {
    final word = cards[2];
    await db.setQueued(word.id!, true);

    final queued = await db.getQueuedFlashcards();
    expect(queued.map((card) => card.id), [word.id]);
    final upNext = await db.getNewFlashcards(limit: 10, includeWords: false);
    expect(upNext.map((card) => card.id), [cards[0].id]);

    await db.setQueued(word.id!, false);
    expect(await db.getQueuedFlashcards(), isEmpty);
  });

  test('"review now" makes a learnt card due', () async {
    final root = cards[0];
    await db.markMastered(root.id!);
    expect(await db.getDueReviewFlashcards(), isEmpty);

    await db.setQueued(root.id!, true);
    expect((await db.getDueReviewFlashcards()).map((c) => c.id), [root.id]);
  });

  test('mastered skips ahead without using up the day\'s new cards, and '
      'reset undoes it', () async {
    final root = cards[0];
    await db.markMastered(root.id!);

    var stored = await reload(root);
    expect(stored.isNew, isFalse);
    expect(masteryLevelOf(stored), MasteryLevel.mastered);
    expect(await db.countIntroducedSince(DateTime(2000)), 0);
    // Knowing the root is what makes its words available.
    final upNext = await db.getNewFlashcards(limit: 10);
    expect(upNext.map((card) => card.kind), everyElement(CardKind.word));
    // It's progress, so it's flagged for sync.
    expect((await db.getDirtyProgress()).single.arabicWord, root.arabicWord);

    await db.resetFlashcard(root.id!);
    stored = await reload(root);
    expect(stored.isNew, isTrue);
    expect(stored.interval, 0);
    expect(masteryLevelOf(stored), MasteryLevel.unlearned);
  });

  test('a reset arrives on another device as a new card', () async {
    final root = cards[0];
    await db.markMastered(root.id!);
    await db.resetFlashcard(root.id!);
    final uploaded = await db.getDirtyProgress();

    final other = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await other.getOrCreateDeck('Test Campaign');
    await other.insertFlashcard(
      Flashcard.newCard(
        arabicWord: 'ك ت ب',
        englishTranslation: 'Writing',
        exampleSentence: '',
        deckId: deck.id!,
      ),
    );
    final theirs = (await other.getAllFlashcards()).single;
    await other.updateFlashcard(theirs.copyWith(isNew: false, interval: 6));
    // Their copy was graded before the reset happened.
    await (await other.database).update('flashcards', {'updated_at': 1});

    expect(await other.applyRemoteProgress(uploaded), 1);
    expect((await other.getAllFlashcards()).single.isNew, isTrue);
  });

  test('favorites survive a card being saved from a stale copy', () async {
    final word = cards[1];
    await db.setFavorite(word.id!, true);
    // `word` was loaded before the star; saving it is what grading does.
    await db.updateFlashcard(word.copyWith(isNew: false));

    expect((await reload(word)).isFavorite, isTrue);
  });

  test('collections hold cards in the order added, and go without taking '
      'the cards with them', () async {
    final id = await db.createCollection('Books');
    await db.setInCollection(id, cards[2].id!, true);
    await db.setInCollection(id, cards[1].id!, true);
    await db.setInCollection(id, cards[1].id!, true); // adding twice is fine

    expect((await db.getCollections()).single.cardCount, 2);
    expect((await db.getCollectionFlashcards(id)).map((card) => card.id), [
      cards[2].id,
      cards[1].id,
    ]);
    expect(await db.getCollectionIdsForCard(cards[1].id!), {id});

    await db.setInCollection(id, cards[2].id!, false);
    expect((await db.getCollections()).single.cardCount, 1);

    await db.deleteCollection(id);
    expect(await db.getCollections(), isEmpty);
    expect(await db.getAllFlashcards(), hasLength(3));
  });
}
