import 'dart:io';

import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resetDatabase wipes all data and leaves the DB usable', () async {
    final dir = Directory.systemTemp.createTempSync('arabic_decoded_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = DatabaseService(pathOverride: p.join(dir.path, 'test.db'));

    final deck = await db.getOrCreateDeck('Test Campaign');
    await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: 'كتاب',
        englishTranslation: 'book',
        exampleSentence: '',
        deckId: deck.id!,
      ),
    );
    expect(await db.getDecks(), hasLength(1));
    expect(await db.getAllFlashcards(), hasLength(1));

    await db.resetDatabase();

    expect(await db.getDecks(), isEmpty);
    expect(await db.getAllFlashcards(), isEmpty);

    // The database should still be usable afterwards, not left broken.
    final freshDeck = await db.getOrCreateDeck('Fresh Start');
    expect(freshDeck.id, isNotNull);
    expect(await db.getDecks(), hasLength(1));
  });
}
