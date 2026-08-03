import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../utils/arabic_normalize.dart';

/// Owns the single sqflite [Database] connection and all reads/writes for
/// decks and flashcards. Deliberately a thin wrapper around raw SQL rather
/// than an ORM — the schema is tiny and unlikely to grow much, so a query
/// builder would be more ceremony than it's worth.
///
/// Content is populated separately by [ContentImporter] — this class only
/// knows how to store and query rows.
class DatabaseService {
  /// [pathOverride] lets tests point this at an isolated database (e.g.
  /// [inMemoryDatabasePath]) instead of the app's real on-disk file.
  DatabaseService({this.pathOverride}) {
    configureDatabaseFactory();
  }

  static final DatabaseService instance = DatabaseService();

  final String? pathOverride;
  Database? _db;
  String? _resolvedPath;

  /// The plain `sqflite` package only ships plugin implementations for
  /// Android/iOS/macOS. This project also has Linux/Windows desktop
  /// scaffolding, so on those platforms this points sqflite at
  /// `sqflite_common_ffi` instead — otherwise the very first database call
  /// throws on desktop. Idempotent and cheap, so it's safe to call this
  /// both eagerly from `main()` and again here as a fallback for anything
  /// (e.g. tests) that constructs a [DatabaseService] directly.
  static void configureDatabaseFactory() {
    if (kIsWeb) return;
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // sqflite has no web backend (it would need a separate
      // IndexedDB-backed package); fail with a message that actually says
      // why, instead of the generic "databaseFactory not initialized"
      // error that shows up otherwise.
      throw StateError(
        'Arabic Decoded needs SQLite storage, which isn\'t supported when '
        'running in a browser. Run this app on Android, iOS, or as a '
        'desktop app (e.g. `flutter run -d linux`) instead of `-d chrome`.',
      );
    }
    final path =
        pathOverride ?? p.join(await getDatabasesPath(), 'arabic_decoded.db');
    _resolvedPath = path;
    return openDatabase(
      path,
      version: 3,
      // sqflite's default `singleInstance: true` caches connections keyed
      // by the literal path string. That's harmless for the app's real
      // on-disk path (only ever opened once, by the DatabaseService
      // singleton) but silently shares ONE database across every test that
      // uses `inMemoryDatabasePath` — they all pass the exact same ":memory:"
      // string. Disabling it gives each DatabaseService its own connection.
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE decks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT
          )
        ''');
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
        await db.execute(
          'CREATE INDEX idx_flashcards_deck_id ON flashcards (deck_id)',
        );
        await db.execute(
          'CREATE INDEX idx_flashcards_next_review ON flashcards (next_review)',
        );
        await db.execute(
          'CREATE INDEX idx_flashcards_is_new ON flashcards (is_new)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Added optional "richer back side" fields — see Flashcard.
          await db.execute('ALTER TABLE flashcards ADD COLUMN transliteration TEXT');
          await db.execute('ALTER TABLE flashcards ADD COLUMN mnemonic TEXT');
          await db.execute(
            "ALTER TABLE flashcards ADD COLUMN related_words TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 3) {
          // New/review split for the SRS queue — see Flashcard.isNew.
          // Existing cards already have real SM-2 progress, so treat them
          // as already-introduced rather than dumping them back into the
          // "new" pile.
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN is_new INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN introduced_at INTEGER',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_flashcards_is_new ON flashcards (is_new)',
          );
        }
      },
    );
  }

  /// Wipes every deck and flashcard and recreates a fresh schema — for
  /// development use (e.g. re-testing the new-card cap or first-launch
  /// import) rather than anything a real user should be able to trigger.
  /// Closes the current connection, deletes the underlying file, and lets
  /// the next call to [database] reopen (and re-run `onCreate`) from
  /// scratch.
  Future<void> resetDatabase() async {
    if (kIsWeb) return;
    final db = _db;
    final path = _resolvedPath;
    _db = null;
    if (db != null) await db.close();
    if (path != null) await databaseFactory.deleteDatabase(path);
  }

  // ---- Decks -------------------------------------------------------------

  Future<int> insertDeck(Deck deck) async {
    final db = await database;
    return db.insert('decks', deck.toMap());
  }

  Future<List<Deck>> getDecks() async {
    final db = await database;
    final rows = await db.query('decks', orderBy: 'name COLLATE NOCASE');
    return rows.map(Deck.fromMap).toList();
  }

  /// Returns the deck named [name], creating it (with [description]) if it
  /// doesn't exist yet. Deck names are treated as unique identifiers here.
  Future<Deck> getOrCreateDeck(String name, {String? description}) async {
    final db = await database;
    final rows = await db.query(
      'decks',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isNotEmpty) return Deck.fromMap(rows.first);

    final id = await insertDeck(Deck(name: name, description: description));
    return Deck(id: id, name: name, description: description);
  }

  // ---- Flashcards ----------------------------------------------------------

  Future<int> insertFlashcard(Flashcard card) async {
    final db = await database;
    return db.insert('flashcards', card.toMap());
  }

  Future<void> updateFlashcard(Flashcard card) async {
    final db = await database;
    await db.update(
      'flashcards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<List<Flashcard>> getFlashcardsForDeck(int deckId) async {
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'next_review ASC',
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Every flashcard across every deck, alphabetical by Arabic word — the
  /// default "browse everything" view for the dictionary tab.
  Future<List<Flashcard>> getAllFlashcards() async {
    final db = await database;
    final rows = await db.query('flashcards', orderBy: 'arabic_word ASC');
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Already-introduced cards due for review on or before [asOf] (defaults
  /// to now), soonest-due first. Deliberately global across every
  /// campaign/deck — once a card has been introduced it just lives in one
  /// shared review rotation, regardless of which campaign it came from.
  Future<List<Flashcard>> getDueReviewFlashcards({DateTime? asOf}) async {
    final db = await database;
    final cutoff = (asOf ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.query(
      'flashcards',
      where: 'is_new = 0 AND next_review <= ?',
      whereArgs: [cutoff],
      orderBy: 'next_review ASC',
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Up to [limit] not-yet-introduced cards, in campaign order. Ordering by
  /// `deck_id` (campaigns are created in the order they're imported, so
  /// lower ids are earlier campaigns) then `id` (a campaign's own cards in
  /// their original JSON order) means this naturally exhausts one
  /// campaign's new cards before moving to the next — no separate
  /// "what's the current campaign" query needed.
  Future<List<Flashcard>> getNewFlashcards({required int limit}) async {
    if (limit <= 0) return [];
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'is_new = 1',
      orderBy: 'deck_id ASC, id ASC',
      limit: limit,
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// How many cards have been introduced (stopped being new) since
  /// [cutoff] — used to enforce the daily new-card cap.
  Future<int> countIntroducedSince(DateTime cutoff) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM flashcards WHERE introduced_at >= ?',
      [cutoff.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Basic Arabic-aware search across every flashcard's word/translation.
  ///
  /// The dataset here is small (a personal word list, not a dictionary), so
  /// this simply loads all flashcards and filters in memory using
  /// [normalizeArabic] — that keeps the normalization rules in one place
  /// instead of duplicating them into SQL, at the cost of not scaling to a
  /// huge deck. If decks ever grow into the tens of thousands of cards,
  /// storing a precomputed normalized column would be the next step.
  Future<List<Flashcard>> searchFlashcards(String query) async {
    final normalizedQuery = normalizeArabic(query);
    final lowerQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty && lowerQuery.isEmpty) return [];

    final db = await database;
    final rows = await db.query('flashcards', orderBy: 'arabic_word ASC');
    return rows
        .map(Flashcard.fromMap)
        .where((card) {
          final matchesArabic = normalizeArabic(
            card.arabicWord,
          ).contains(normalizedQuery);
          final matchesEnglish = card.englishTranslation
              .toLowerCase()
              .contains(lowerQuery);
          return matchesArabic || matchesEnglish;
        })
        .toList();
  }
}
