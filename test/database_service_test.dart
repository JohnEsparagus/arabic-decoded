import 'dart:io';

import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('upgrading a pre-sync database queues existing progress for upload '
      'without touching it', () async {
    final dir = Directory.systemTemp.createTempSync('arabic_decoded_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.db');

    // A version 3 database, as it looked before sync existed: one card
    // that's been studied and one that hasn't.
    DatabaseService.configureDatabaseFactory();
    final nextReview = DateTime(2026, 10, 20).millisecondsSinceEpoch;
    final old = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE decks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, description TEXT)',
        );
        await db.execute('''
          CREATE TABLE flashcards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            arabic_word TEXT NOT NULL,
            english_translation TEXT NOT NULL,
            example_sentence TEXT NOT NULL,
            deck_id INTEGER NOT NULL,
            ease_factor REAL NOT NULL DEFAULT 2.5,
            interval INTEGER NOT NULL DEFAULT 0,
            repetitions INTEGER NOT NULL DEFAULT 0,
            next_review INTEGER NOT NULL,
            is_new INTEGER NOT NULL DEFAULT 1,
            introduced_at INTEGER,
            transliteration TEXT,
            mnemonic TEXT,
            related_words TEXT NOT NULL DEFAULT '[]',
            FOREIGN KEY (deck_id) REFERENCES decks (id) ON DELETE CASCADE
          )
        ''');
        await db.insert('decks', {'name': 'Absolute Core'});
        await db.insert('flashcards', {
          'arabic_word': 'studied',
          'english_translation': '',
          'example_sentence': '',
          'deck_id': 1,
          'ease_factor': 2.6,
          'interval': 6,
          'repetitions': 2,
          'next_review': nextReview,
          'is_new': 0,
          'introduced_at': 1,
        });
        await db.insert('flashcards', {
          'arabic_word': 'unstudied',
          'english_translation': '',
          'example_sentence': '',
          'deck_id': 1,
          'next_review': nextReview,
        });
      },
    );
    await old.close();

    final db = DatabaseService(pathOverride: path);

    final dirty = await db.getDirtyProgress();
    expect(dirty.map((d) => d.arabicWord), ['studied']);
    expect(dirty.single.deckName, 'Absolute Core');
    expect(dirty.single.interval, 6);
    // Dated to when it was last graded: six days before it's next due.
    expect(dirty.single.updatedAt, DateTime(2026, 10, 14));

    final studied = (await db.getAllFlashcards()).firstWhere(
      (c) => c.arabicWord == 'studied',
    );
    expect(studied.easeFactor, 2.6);
    expect(studied.repetitions, 2);
    expect(studied.isNew, isFalse);
  });
}
