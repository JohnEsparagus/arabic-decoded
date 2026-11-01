import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config/campaign_sources.dart';
import '../models/card_collection.dart';
import '../models/card_progress.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/review_log_entry.dart';
import '../models/sentence.dart';
import '../models/synced_extras.dart';
import '../utils/arabic_normalize.dart';
import 'platform_database.dart';

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

  /// The connection once it's being opened. Kept as the future, not the
  /// result, so that callers arriving while it's still opening wait for
  /// that one instead of each opening the file again; the browser's
  /// SQLite stalls if the same file is opened twice at once.
  Future<Database>? _db;
  String? _resolvedPath;

  /// Points sqflite at the right SQLite for this platform: the plugin on
  /// Android, iOS and macOS, the system library on Linux and Windows, and
  /// WebAssembly in a browser (see `platform_database.dart`). Without it
  /// the very first database call throws everywhere but the first three.
  /// Idempotent and cheap, so it's safe to call this both eagerly from
  /// `main()` and again here as a fallback for anything (e.g. tests) that
  /// constructs a [DatabaseService] directly.
  static void configureDatabaseFactory() => configurePlatformDatabaseFactory();

  Future<Database> get database async {
    return _db ??= _initDatabase().catchError((Object error) {
      // Don't keep handing out a failed open: let the next caller retry.
      _db = null;
      throw error;
    });
  }

  Future<Database> _initDatabase() async {
    final path =
        pathOverride ?? p.join(await getDatabasesPath(), 'arabic_decoded.db');
    _resolvedPath = path;
    return openDatabase(
      path,
      version: 13,
      // sqflite's default `singleInstance: true` caches connections keyed
      // by the literal path string. That's harmless for the app's real
      // on-disk path (only ever opened once, by the DatabaseService
      // singleton) but silently shares ONE database across every test that
      // uses `inMemoryDatabasePath` — they all pass the exact same ":memory:"
      // string. Disabling it gives each of those its own connection. The
      // app's own database keeps the default, which the browser's SQLite
      // insists on: it refuses to open one file more than once.
      singleInstance: pathOverride == null,
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
            stability REAL,
            difficulty REAL,
            quran_rank INTEGER,
            next_review INTEGER NOT NULL,
            is_new INTEGER NOT NULL DEFAULT 1,
            introduced_at INTEGER,
            transliteration TEXT,
            mnemonic TEXT,
            related_words TEXT NOT NULL DEFAULT '[]',
            updated_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 0,
            kind TEXT NOT NULL DEFAULT 'root',
            root_key TEXT,
            pattern_key TEXT,
            example_translation TEXT,
            note TEXT,
            favorite INTEGER NOT NULL DEFAULT 0,
            queued_at INTEGER,
            unlock_after INTEGER,
            FOREIGN KEY (deck_id) REFERENCES decks (id) ON DELETE CASCADE
          )
        ''');
        await _createCollectionTables(db);
        await _createReviewLogTable(db);
        await _createLibraryStateTable(db);
        await _createSentenceTables(db);
        await _createContentFilesTable(db);
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
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN transliteration TEXT',
          );
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
        if (oldVersion < 4) {
          // Sync bookkeeping — see the "Sync" section below.
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN updated_at INTEGER',
          );
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
          );
          // Progress made before sync existed has never been uploaded, so
          // flag all of it. There's no record of when those cards were
          // actually last graded; next_review minus the interval is the
          // day SM-2 scheduled them from, which is the same thing.
          await db.execute(
            'UPDATE flashcards SET dirty = 1, '
            'updated_at = next_review - interval * 86400000 '
            'WHERE is_new = 0',
          );
        }
        if (oldVersion < 5) {
          // Words and patterns became cards of their own, linked to their
          // root — see Flashcard.kind. Everything stored before this was
          // a root, which is what the default says.
          await db.execute(
            "ALTER TABLE flashcards ADD COLUMN kind TEXT NOT NULL DEFAULT 'root'",
          );
          await db.execute('ALTER TABLE flashcards ADD COLUMN root_key TEXT');
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN pattern_key TEXT',
          );
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN example_translation TEXT',
          );
          await db.execute('ALTER TABLE flashcards ADD COLUMN note TEXT');
        }
        if (oldVersion < 6) {
          // Things the user does to a card by hand — see the "Card
          // actions" and "Collections" sections below.
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN queued_at INTEGER',
          );
          await _createCollectionTables(db);
        }
        if (oldVersion < 7) {
          await _createReviewLogTable(db);
          // There's no record of what happened before the log existed,
          // only where each card stands now. So every card already being
          // studied gets the two points that are known: it started out
          // (interval of a day) when it was introduced, and it reached its
          // current interval when it was last graded. Stats for the time
          // before this are that straight-line guess; from here on they're
          // exact.
          await db.execute('''
            INSERT INTO review_log (card_id, at, interval, is_new, graded)
            SELECT id, introduced_at, 1, 0, 0 FROM flashcards
            WHERE is_new = 0 AND introduced_at IS NOT NULL
              AND updated_at IS NOT NULL AND introduced_at < updated_at
          ''');
          await db.execute('''
            INSERT INTO review_log (card_id, at, interval, is_new, graded)
            SELECT id,
                   COALESCE(updated_at, introduced_at,
                            next_review - interval * 86400000),
                   interval, 0, 0
            FROM flashcards WHERE is_new = 0
          ''');
        }
        if (oldVersion < 8) {
          // Sync bookkeeping for the review log and the library — see
          // "Syncing the extras" below. Version 7 created the log without
          // the column; a database made at 7 or later already has it.
          if (oldVersion == 7) {
            await db.execute(
              'ALTER TABLE review_log ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
            );
          }
          await _createLibraryStateTable(db);
          // Whatever is starred or collected already has never been
          // uploaded.
          await db.execute(
            '''
            UPDATE library_state SET dirty = 1, updated_at = ?
            WHERE EXISTS (SELECT 1 FROM flashcards WHERE favorite = 1)
               OR EXISTS (SELECT 1 FROM collections)
          ''',
            [DateTime.now().millisecondsSinceEpoch],
          );
        }
        if (oldVersion < 9) {
          // When a read-once card comes up — see Flashcard.unlockAfter.
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN unlock_after INTEGER',
          );
        }
        if (oldVersion < 10) {
          // Sentences moved out of `flashcards` into a corpus of their
          // own — see "Sentences" below. The cards that stood in for them
          // go, except any the user has done something with.
          await _createSentenceTables(db);
          await db.execute('''
            DELETE FROM flashcards
            WHERE kind = 'sentence' AND is_new = 1
              AND queued_at IS NULL AND favorite = 0
              AND id NOT IN (SELECT card_id FROM collection_cards)
          ''');
        }
        if (oldVersion < 11) {
          // The FSRS scheduler's state — see lib/services/scheduler.dart.
          // Cards SM-2 scheduled get theirs on their next review.
          await db.execute('ALTER TABLE flashcards ADD COLUMN stability REAL');
          await db.execute('ALTER TABLE flashcards ADD COLUMN difficulty REAL');
        }
        if (oldVersion < 12) {
          // Which roots are the Quran's most common — see Flashcard.quranRank.
          await db.execute(
            'ALTER TABLE flashcards ADD COLUMN quran_rank INTEGER',
          );
        }
        if (oldVersion < 13) {
          // Downloaded content — see ContentStore.
          await _createContentFilesTable(db);
        }
      },
    );
  }

  static Future<void> _createCollectionTables(Database db) async {
    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE collection_cards (
        collection_id INTEGER NOT NULL,
        card_id INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (collection_id, card_id),
        FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
        FOREIGN KEY (card_id) REFERENCES flashcards (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createReviewLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE review_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        at INTEGER NOT NULL,
        interval INTEGER NOT NULL,
        is_new INTEGER NOT NULL DEFAULT 0,
        graded INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (card_id) REFERENCES flashcards (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_review_log_at ON review_log (at)');
  }

  /// The sentence corpus and its index, plus a small key/value table for
  /// facts about the bundled content (which version of it is loaded).
  static Future<void> _createSentenceTables(Database db) async {
    // `search` is the sentence with its vowel marks stripped and its
    // English lowercased, so one LIKE covers a search in either language.
    await db.execute('''
      CREATE TABLE sentences (
        id INTEGER PRIMARY KEY,
        arabic TEXT NOT NULL UNIQUE,
        english TEXT NOT NULL,
        search TEXT NOT NULL
      )
    ''');
    // Which sentences each word appears in. Clustered on the word, so
    // "every sentence with this word" is one short range read however big
    // the corpus gets.
    await db.execute('''
      CREATE TABLE sentence_words (
        word TEXT NOT NULL,
        sentence_id INTEGER NOT NULL,
        PRIMARY KEY (word, sentence_id)
      ) WITHOUT ROWID
    ''');
    await db.execute(
      'CREATE TABLE content_meta (key TEXT PRIMARY KEY, value TEXT)',
    );
    // A sentence finds its flashcard by its text.
    await db.execute(
      'CREATE INDEX idx_flashcards_arabic_word ON flashcards (arabic_word)',
    );
  }

  static Future<void> _createContentFilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE content_files (
        path TEXT PRIMARY KEY,
        hash TEXT NOT NULL,
        body TEXT NOT NULL
      )
    ''');
  }

  /// A single row that says when the library (favorites and collections)
  /// was last changed and whether that change has been uploaded.
  static Future<void> _createLibraryStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE library_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        updated_at INTEGER,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('library_state', {'id': 1});
  }

  /// Wipes every deck and flashcard and recreates a fresh schema — for
  /// development use (e.g. re-testing the new-card cap or first-launch
  /// import) rather than anything a real user should be able to trigger.
  /// Closes the current connection, deletes the underlying file, and lets
  /// the next call to [database] reopen (and re-run `onCreate`) from
  /// scratch.
  Future<void> resetDatabase() async {
    final db = _db;
    final path = _resolvedPath;
    _db = null;
    if (db != null) await (await db).close();
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

  /// Inserts many cards as one write. The first launch imports around a
  /// thousand of them; one at a time, each waits on the disk separately,
  /// which is seconds of startup.
  Future<void> insertFlashcards(List<Flashcard> cards) async {
    if (cards.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final card in cards) {
      batch.insert('flashcards', card.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Saves [card] and flags it as changed-since-last-sync. This is the
  /// "the user just graded a card" write; progress arriving *from* sync
  /// goes through [applyRemoteProgress] instead, which doesn't flag it.
  Future<void> updateFlashcard(Flashcard card) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'flashcards',
      {...card.toMap(), 'updated_at': now, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [card.id],
    );
    await _logProgress(db, card.id!, at: now, graded: true);
  }

  /// Adds the card's progress as it stands right now to the review log.
  /// Called after every write that changes it, so the log always ends on
  /// the card's current state.
  ///
  /// A card's entries are told apart by their time, here and when synced,
  /// so two changes to one card in the same millisecond would look like
  /// one. The second is nudged a millisecond later instead.
  Future<void> _logProgress(
    DatabaseExecutor db,
    int cardId, {
    required int at,
    bool graded = false,
  }) {
    return db.rawInsert(
      '''
      INSERT INTO review_log (card_id, at, interval, is_new, graded)
      SELECT id,
             MAX(?, COALESCE(
               (SELECT MAX(at) + 1 FROM review_log WHERE card_id = ?), 0)),
             interval, is_new, ?
      FROM flashcards WHERE id = ?
      ''',
      [at, cardId, graded ? 1 : 0, cardId],
    );
  }

  /// Every change to any card's progress, oldest first — see
  /// [ReviewLogEntry].
  Future<List<ReviewLogEntry>> getReviewLog() async {
    final db = await database;
    final rows = await db.query('review_log', orderBy: 'at ASC, id ASC');
    return rows.map(ReviewLogEntry.fromMap).toList();
  }

  /// Moves a card from one name to another (a corrected spelling, or
  /// another deck), keeping its progress. Does nothing if there's no card
  /// at the old name, which is what makes it safe to run on every launch.
  ///
  /// If a card is already at the new name (two copies of one root being
  /// merged), the one with more progress wins and the other goes, with its
  /// review history, collections and star carried over. The kept card is
  /// flagged for sync, so its progress is uploaded under the new name.
  Future<void> moveCard({
    required String fromDeck,
    required String from,
    required String toDeck,
    required String to,
  }) async {
    final db = await database;
    Future<Map<String, Object?>?> find(String deck, String arabic) async {
      final rows = await db.rawQuery(
        '''
        SELECT f.* FROM flashcards f JOIN decks d ON d.id = f.deck_id
        WHERE d.name = ? AND f.arabic_word = ?
        ''',
        [deck, arabic],
      );
      return rows.isEmpty ? null : rows.first;
    }

    final source = await find(fromDeck, from);
    if (source == null) return;
    final target = await find(toDeck, to);
    final now = DateTime.now().millisecondsSinceEpoch;
    final studied = source['is_new'] == 0;

    if (target == null) {
      final deck = await getOrCreateDeck(toDeck);
      await db.rawUpdate(
        '''
        UPDATE flashcards
        SET deck_id = ?, arabic_word = ?,
            dirty = CASE WHEN is_new = 0 THEN 1 ELSE dirty END,
            updated_at = CASE WHEN is_new = 0 THEN COALESCE(updated_at, ?)
                              ELSE updated_at END
        WHERE id = ?
        ''',
        [deck.id, to, now, source['id']],
      );
      return;
    }

    final sourceId = source['id'] as int;
    final targetId = target['id'] as int;
    await db.transaction((txn) async {
      final sourceAhead =
          studied &&
          (target['is_new'] == 1 ||
              (source['interval'] as int) > (target['interval'] as int));
      if (sourceAhead) {
        await txn.update(
          'flashcards',
          {
            for (final column in [
              'ease_factor',
              'interval',
              'repetitions',
              'stability',
              'difficulty',
              'next_review',
              'is_new',
              'introduced_at',
            ])
              column: source[column],
            'updated_at': source['updated_at'] ?? now,
            'dirty': 1,
          },
          where: 'id = ?',
          whereArgs: [targetId],
        );
      }
      if (source['favorite'] == 1) {
        await txn.update(
          'flashcards',
          {'favorite': 1},
          where: 'id = ?',
          whereArgs: [targetId],
        );
      }
      await txn.rawUpdate(
        'UPDATE review_log SET card_id = ? WHERE card_id = ?',
        [targetId, sourceId],
      );
      await txn.rawUpdate(
        'UPDATE OR IGNORE collection_cards SET card_id = ? WHERE card_id = ?',
        [targetId, sourceId],
      );
      await txn.delete('flashcards', where: 'id = ?', whereArgs: [sourceId]);
    });
  }

  /// Marks the Quran's most common roots: [ranks] maps a root's letters
  /// ("ك ت ب") to its place in the list. Every other root is unmarked, so
  /// a root dropped from the list stops counting as Quranic. One
  /// transaction; a root's letters identify it, whichever deck it's in.
  Future<void> setQuranRanks(Map<String, int> ranks) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE flashcards SET quran_rank = NULL WHERE quran_rank IS NOT NULL',
      );
      final batch = txn.batch();
      for (final MapEntry(key: root, value: rank) in ranks.entries) {
        batch.rawUpdate(
          "UPDATE flashcards SET quran_rank = ? WHERE kind = 'root' "
          'AND arabic_word = ?',
          [rank, root],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Overwrites [card]'s content (meaning, example, links...) and nothing
  /// else: SM-2 progress and the sync flags are left exactly as they are.
  /// Used by `ContentImporter` when the bundled JSON has changed.
  Future<void> updateFlashcardContent(Flashcard card) async {
    final db = await database;
    await db.update(
      'flashcards',
      card.contentMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  /// Removes a card outright, along with its history and its place in any
  /// collection. For content that has been taken out of the bundled files.
  Future<void> deleteFlashcard(int cardId) async {
    final db = await database;
    await db.delete('flashcards', where: 'id = ?', whereArgs: [cardId]);
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
  ///
  /// Roots always come back, and so do sentences: those are only ever
  /// studied because the user asked for them. Words and patterns only with
  /// [includeWords], letters only with [includeLetters]; switched off,
  /// those cards keep their progress and simply wait until it's switched
  /// on again. Read-once cards are never reviewed.
  Future<List<Flashcard>> getDueReviewFlashcards({
    DateTime? asOf,
    bool includeWords = true,
    bool includeLetters = true,
  }) async {
    final db = await database;
    final cutoff = (asOf ?? DateTime.now()).millisecondsSinceEpoch;
    final kinds = [
      CardKind.root,
      CardKind.sentence,
      if (includeWords) ...[CardKind.word, CardKind.pattern],
      if (includeLetters) CardKind.letter,
    ];
    final rows = await db.query(
      'flashcards',
      where:
          'is_new = 0 AND next_review <= ? '
          'AND kind IN (${kinds.map((kind) => "'${kind.name}'").join(', ')})',
      whereArgs: [cutoff],
      orderBy: 'next_review ASC',
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Up to [limit] not-yet-introduced cards, in the order they should be
  /// taught. Roots come in campaign order: `deck_id` (campaigns are created
  /// in the order they're imported, so lower ids are earlier campaigns)
  /// then `id` (a campaign's own cards in their original JSON order), which
  /// naturally exhausts one campaign's roots before moving to the next —
  /// no separate "what's the current campaign" query needed.
  ///
  /// With [includeWords] on, words are mixed in: new cards alternate, a
  /// root then a word, so roots keep moving. Only words whose root has
  /// already been introduced are offered, and a pattern card is slotted in
  /// right before the first word that uses it. With it off this is just
  /// the roots.
  ///
  /// With [includeLetters] on, the alphabet comes before all of that:
  /// there's no reading a root without it.
  ///
  /// Read-once cards go at the very front as soon as enough roots have
  /// been introduced for them ([Flashcard.unlockAfter]). Because the queue
  /// is asked for again after every new card, that means one turns up
  /// right after the root that unlocks it.
  ///
  /// The Quran campaign's own roots (the ones no other campaign teaches)
  /// only come up with [quranFirst] on. With it on, every Quranic root, in
  /// whichever campaign it lives, comes before the rest, most common
  /// first.
  ///
  /// Cards the user queued by hand (see [setQueued]) aren't part of this;
  /// those come from [getQueuedFlashcards] and go ahead of these.
  ///
  /// Done in Dart over every card rather than in SQL: the rules read more
  /// plainly this way, and there are only a few hundred rows.
  Future<List<Flashcard>> getNewFlashcards({
    required int limit,
    bool includeWords = true,
    bool includeLetters = true,
    bool quranFirst = false,
  }) async {
    if (limit <= 0) return [];
    final db = await database;
    final rows = await db.query('flashcards', orderBy: 'deck_id ASC, id ASC');
    final quranDeck = await db.query(
      'decks',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [quranSource.deckName],
    );
    final quranDeckId = quranDeck.isEmpty ? null : quranDeck.first['id'];
    final cards = rows.map(Flashcard.fromMap).toList();
    bool isWaiting(Flashcard card) => card.isNew && card.queuedAt == null;

    final rootsIntroduced = cards
        .where((card) => !card.isNew && card.kind == CardKind.root)
        .length;
    final unlockedInfo =
        cards
            .where(
              (card) =>
                  isWaiting(card) &&
                  card.kind == CardKind.info &&
                  (card.unlockAfter ?? 0) <= rootsIntroduced,
            )
            .toList()
          // Earliest unlock first; cards unlocked at the same point keep
          // the order they have in the file (their ids), which a sort on
          // the unlock point alone wouldn't promise.
          ..sort((a, b) {
            final byUnlock = (a.unlockAfter ?? 0).compareTo(b.unlockAfter ?? 0);
            return byUnlock != 0 ? byUnlock : a.id!.compareTo(b.id!);
          });

    final result = <Flashcard>[
      ...unlockedInfo,
      if (includeLetters)
        ...cards.where(
          (card) => isWaiting(card) && card.kind == CardKind.letter,
        ),
    ];
    var roots = cards
        .where(
          (card) =>
              isWaiting(card) &&
              card.kind == CardKind.root &&
              (quranFirst || card.deckId != quranDeckId),
        )
        .toList();
    if (quranFirst) {
      final quranic = roots.where((card) => card.quranRank != null).toList()
        ..sort((a, b) => a.quranRank!.compareTo(b.quranRank!));
      roots = [...quranic, ...roots.where((card) => card.quranRank == null)];
    }
    if (!includeWords) return [...result, ...roots].take(limit).toList();

    // Each word, led by its pattern's card if that hasn't been introduced
    // (or queued by hand) yet.
    final lockedRoots = {
      for (final card in cards)
        if (card.isNew && card.kind == CardKind.root)
          (card.deckId, card.arabicWord),
    };
    final newPatterns = {
      for (final card in cards)
        if (isWaiting(card) && card.kind == CardKind.pattern)
          card.patternKey: card,
    };
    final wordSteps = <List<Flashcard>>[];
    for (final card in cards) {
      if (!isWaiting(card) || card.kind != CardKind.word) continue;
      if (lockedRoots.contains((card.deckId, card.rootKey))) continue;
      final pattern = newPatterns.remove(card.patternKey);
      wordSteps.add([?pattern, card]);
    }

    for (var i = 0; i < roots.length || i < wordSteps.length; i++) {
      if (i < roots.length) result.add(roots[i]);
      if (i < wordSteps.length) result.addAll(wordSteps[i]);
    }
    return result.take(limit).toList();
  }

  /// Still-new cards the user put in their queue by hand, in the order
  /// they asked for them. Any kind of card, whatever the words setting
  /// says and whether or not its root has been learned: they asked.
  Future<List<Flashcard>> getQueuedFlashcards() async {
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'is_new = 1 AND queued_at IS NOT NULL',
      orderBy: 'queued_at ASC, id ASC',
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

  // ---- Card actions -------------------------------------------------------
  //
  // What the user can do to a card by hand, from the menu that holding a
  // card brings up. The ones that change progress flag the card for sync
  // exactly like grading does.

  /// Puts a card in the queue, or takes it back out. A still-new card
  /// jumps the line for new cards (see [getQueuedFlashcards]); one that's
  /// already being reviewed is made due right now instead.
  Future<void> setQueued(int cardId, bool queued) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'flashcards',
      {'queued_at': queued ? now : null},
      where: 'id = ? AND is_new = 1',
      whereArgs: [cardId],
    );
    if (!queued) return;
    await db.update(
      'flashcards',
      {'next_review': now, 'updated_at': now, 'dirty': 1},
      where: 'id = ? AND is_new = 0',
      whereArgs: [cardId],
    );
  }

  /// "I know this one": skips the card straight to a long interval, so it
  /// counts as learned and only comes back for a check in [intervalDays].
  /// Leaves `introduced_at` alone, so mastering cards by hand doesn't eat
  /// into the day's allowance of new ones.
  Future<void> markMastered(int cardId, {int intervalDays = 180}) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await db.rawUpdate(
      '''
      UPDATE flashcards
      SET is_new = 0, interval = ?, repetitions = MAX(repetitions, 5),
          stability = ?, difficulty = COALESCE(difficulty, 3),
          next_review = ?, queued_at = NULL, updated_at = ?, dirty = 1
      WHERE id = ?
      ''',
      [
        intervalDays,
        intervalDays.toDouble(),
        today.add(Duration(days: intervalDays)).millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
        cardId,
      ],
    );
    await _logProgress(db, cardId, at: now.millisecondsSinceEpoch);
  }

  /// Marks a read-once card as read: it won't be shown again, and it's
  /// never due for review. Nothing goes in the review log and
  /// `introduced_at` stays empty, so reading one doesn't count as studying
  /// a card or use up any of the day's new ones. The change is still
  /// flagged for sync, so it isn't shown again on another device either.
  Future<void> markSeen(int cardId) async {
    final db = await database;
    await db.update(
      'flashcards',
      {
        'is_new': 0,
        'repetitions': 1,
        'next_review': DateTime(9999).millisecondsSinceEpoch,
        'queued_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  /// Puts one card back to never-studied.
  Future<void> resetFlashcard(int cardId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'flashcards',
      {
        'ease_factor': 2.5,
        'interval': 0,
        'repetitions': 0,
        'stability': null,
        'difficulty': null,
        'next_review': now,
        'is_new': 1,
        'introduced_at': null,
        'queued_at': null,
        'updated_at': now,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
    await _logProgress(db, cardId, at: now);
  }

  Future<void> setFavorite(int cardId, bool favorite) async {
    final db = await database;
    await db.update(
      'flashcards',
      {'favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [cardId],
    );
    await _touchLibrary(db);
  }

  /// Notes that the library just changed and needs uploading.
  Future<void> _touchLibrary(DatabaseExecutor db) {
    return db.update('library_state', {
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'dirty': 1,
    });
  }

  // ---- Collections -----------------------------------------------------------

  /// Every collection, oldest first, each with how many cards it holds.
  Future<List<CardCollection>> getCollections() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.id, c.name, COUNT(cc.card_id) AS card_count
      FROM collections c
      LEFT JOIN collection_cards cc ON cc.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.created_at ASC, c.id ASC
    ''');
    return rows.map(CardCollection.fromMap).toList();
  }

  Future<int> createCollection(String name) async {
    final db = await database;
    final id = await db.insert('collections', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _touchLibrary(db);
    return id;
  }

  /// Deletes the collection. The cards that were in it are untouched.
  Future<void> deleteCollection(int collectionId) async {
    final db = await database;
    await db.delete('collections', where: 'id = ?', whereArgs: [collectionId]);
    await _touchLibrary(db);
  }

  Future<void> setInCollection(
    int collectionId,
    int cardId,
    bool inCollection,
  ) async {
    final db = await database;
    if (inCollection) {
      await db.insert('collection_cards', {
        'collection_id': collectionId,
        'card_id': cardId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'collection_cards',
        where: 'collection_id = ? AND card_id = ?',
        whereArgs: [collectionId, cardId],
      );
    }
    await _touchLibrary(db);
  }

  /// A collection's cards, in the order they were added.
  Future<List<Flashcard>> getCollectionFlashcards(int collectionId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT f.* FROM flashcards f
      JOIN collection_cards cc ON cc.card_id = f.id
      WHERE cc.collection_id = ?
      ORDER BY cc.added_at ASC, cc.rowid ASC
      ''',
      [collectionId],
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// The ids of the collections [cardId] is in.
  Future<Set<int>> getCollectionIdsForCard(int cardId) async {
    final db = await database;
    final rows = await db.query(
      'collection_cards',
      columns: ['collection_id'],
      where: 'card_id = ?',
      whereArgs: [cardId],
    );
    return rows.map((row) => row['collection_id'] as int).toSet();
  }

  // ---- Sync ----------------------------------------------------------------
  //
  // Two extra columns that aren't on [Flashcard] because nothing outside
  // sync cares about them: `updated_at` (when the card was last graded)
  // and `dirty` (graded since it was last uploaded). See `SyncService`.

  /// Every card graded since it was last uploaded.
  Future<List<CardProgress>> getDirtyProgress() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT d.name AS deck_name, f.arabic_word, f.ease_factor, f.interval,
             f.stability, f.difficulty,
             f.repetitions, f.next_review, f.introduced_at, f.updated_at
      FROM flashcards f JOIN decks d ON d.id = f.deck_id
      WHERE f.dirty = 1
    ''');
    return rows.map((row) {
      final introducedAtMs = row['introduced_at'] as int?;
      return CardProgress(
        deckName: row['deck_name'] as String,
        arabicWord: row['arabic_word'] as String,
        easeFactor: (row['ease_factor'] as num).toDouble(),
        stability: (row['stability'] as num?)?.toDouble(),
        difficulty: (row['difficulty'] as num?)?.toDouble(),
        interval: row['interval'] as int,
        repetitions: row['repetitions'] as int,
        nextReview: DateTime.fromMillisecondsSinceEpoch(
          row['next_review'] as int,
        ),
        introducedAt: introducedAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(introducedAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int,
        ),
      );
    }).toList();
  }

  /// Clears the dirty flag on cards that were just uploaded. Matching on
  /// `updated_at` as well means a card graded again while the upload was
  /// in flight stays dirty and goes up next time.
  Future<void> markProgressSynced(List<CardProgress> uploaded) async {
    final db = await database;
    final batch = db.batch();
    for (final progress in uploaded) {
      batch.rawUpdate(
        '''
        UPDATE flashcards SET dirty = 0
        WHERE arabic_word = ?
          AND deck_id = (SELECT id FROM decks WHERE name = ?)
          AND updated_at = ?
        ''',
        [
          progress.arabicWord,
          progress.deckName,
          progress.updatedAt.millisecondsSinceEpoch,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Overwrites local progress with [remote] wherever the remote copy is
  /// newer (or the card has never been graded here), and returns how many
  /// cards actually changed. Rows for cards this device doesn't have are
  /// skipped.
  Future<int> applyRemoteProgress(List<CardProgress> remote) async {
    if (remote.isEmpty) return 0;
    final db = await database;
    // A sentence is only a card on the devices where it was added. If
    // progress for one arrives here first, make its card from the corpus
    // so there's something for the progress to land on.
    final sentences = remote
        .where((progress) => progress.deckName == sentencesSource.deckName)
        .toList();
    if (sentences.isNotEmpty) {
      final deck = await getOrCreateDeck(
        sentencesSource.deckName,
        description: sentencesSource.description,
      );
      final adding = db.batch();
      for (final progress in sentences) {
        adding.rawInsert(_insertSentenceCard, [
          deck.id,
          DateTime.now().millisecondsSinceEpoch,
          progress.arabicWord,
          deck.id,
        ]);
      }
      await adding.commit(noResult: true);
    }
    final batch = db.batch();
    for (final progress in remote) {
      final updatedAt = progress.updatedAt.millisecondsSinceEpoch;
      batch.rawUpdate(
        '''
        UPDATE flashcards
        SET ease_factor = ?, interval = ?, repetitions = ?, next_review = ?,
            stability = ?, difficulty = ?,
            is_new = ?, introduced_at = ?, updated_at = ?, dirty = 0
        WHERE arabic_word = ?
          AND deck_id = (SELECT id FROM decks WHERE name = ?)
          AND (updated_at IS NULL OR updated_at < ?)
        ''',
        [
          progress.easeFactor,
          progress.interval,
          progress.repetitions,
          progress.nextReview.millisecondsSinceEpoch,
          progress.stability,
          progress.difficulty,
          // Only a card that was reset by hand is uploaded with no
          // interval and no repetitions: even one failed first try has an
          // interval of a day. That card is new again here too.
          progress.interval == 0 && progress.repetitions == 0 ? 1 : 0,
          progress.introducedAt?.millisecondsSinceEpoch,
          updatedAt,
          progress.arabicWord,
          progress.deckName,
          updatedAt,
        ],
      );
    }
    final counts = await batch.commit();
    // Whatever just changed gets a log entry dated when it was graded on
    // the other device, unless the log already reaches that far: the card
    // didn't change, was graded here, or its real entry has already come
    // down with the synced review log. (These stand-ins are marked synced
    // so they aren't uploaded as if they were the real thing.)
    await db.execute('''
      INSERT INTO review_log (card_id, at, interval, is_new, graded, synced)
      SELECT f.id, f.updated_at, f.interval, f.is_new, 0, 1 FROM flashcards f
      WHERE f.updated_at IS NOT NULL AND f.kind != 'info' AND NOT EXISTS (
        SELECT 1 FROM review_log r
        WHERE r.card_id = f.id AND r.at >= f.updated_at
      )
    ''');
    return counts.fold<int>(0, (sum, count) => sum + (count as int));
  }

  /// Puts every card back to never-studied while keeping the cards
  /// themselves — used when a different account signs in on this device,
  /// so one person's progress isn't uploaded into another's account.
  Future<void> clearProgress() async {
    final db = await database;
    await db.update('flashcards', {
      'ease_factor': 2.5,
      'interval': 0,
      'repetitions': 0,
      'stability': null,
      'difficulty': null,
      'next_review': DateTime.now().millisecondsSinceEpoch,
      'is_new': 1,
      'introduced_at': null,
      'queued_at': null,
      'updated_at': null,
      'dirty': 0,
    });
    // The history and the library are the previous account's too.
    await db.delete('review_log');
    await db.delete('collections');
    await db.update('flashcards', {'favorite': 0});
    await db.update('library_state', {'updated_at': null, 'dirty': 0});
  }

  // ---- Syncing the extras ---------------------------------------------------
  //
  // The review log and the library (favorites + collections) sync too, each
  // in the way that suits it. The log only ever grows, so each entry is
  // uploaded once (`synced`) and other devices' entries are added to it.
  // The library is small and changes rarely, so it travels whole, with
  // `library_state` saying when it last changed and whether that's been
  // uploaded.

  /// Up to [limit] review-log entries that haven't been uploaded yet.
  Future<List<SyncedReview>> getUnsyncedReviews({int limit = 500}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT r.id, d.name AS deck_name, f.arabic_word, r.at, r.interval,
             r.is_new, r.graded
      FROM review_log r
      JOIN flashcards f ON f.id = r.card_id
      JOIN decks d ON d.id = f.deck_id
      WHERE r.synced = 0
      ORDER BY r.id ASC LIMIT ?
      ''',
      [limit],
    );
    return [
      for (final row in rows)
        SyncedReview(
          id: row['id'] as int,
          deckName: row['deck_name'] as String,
          arabicWord: row['arabic_word'] as String,
          at: DateTime.fromMillisecondsSinceEpoch(row['at'] as int),
          interval: row['interval'] as int,
          isNew: (row['is_new'] as int) != 0,
          graded: (row['graded'] as int) != 0,
        ),
    ];
  }

  Future<void> markReviewsSynced(List<SyncedReview> uploaded) async {
    if (uploaded.isEmpty) return;
    final db = await database;
    final ids = uploaded.map((review) => review.id).join(', ');
    await db.execute('UPDATE review_log SET synced = 1 WHERE id IN ($ids)');
  }

  /// Adds review-log entries made on other devices, and returns how many
  /// were new here. An entry this device already has (same card, same
  /// moment) is left alone, except that a stand-in for it (see
  /// [applyRemoteProgress]) learns whether it was really a graded review.
  /// Entries for cards this device doesn't have are skipped.
  Future<int> applyRemoteReviews(List<SyncedReview> remote) async {
    if (remote.isEmpty) return 0;
    final db = await database;
    final batch = db.batch();
    for (final review in remote) {
      final at = review.at.millisecondsSinceEpoch;
      const card = '''
        (SELECT f.id FROM flashcards f JOIN decks d ON d.id = f.deck_id
         WHERE f.arabic_word = ? AND d.name = ?)
      ''';
      if (review.graded) {
        batch.rawUpdate(
          'UPDATE review_log SET graded = 1 WHERE at = ? AND card_id = $card',
          [at, review.arabicWord, review.deckName],
        );
      }
      batch.rawInsert(
        '''
        INSERT INTO review_log (card_id, at, interval, is_new, graded, synced)
        SELECT f.id, ?, ?, ?, ?, 1
        FROM flashcards f JOIN decks d ON d.id = f.deck_id
        WHERE f.arabic_word = ? AND d.name = ? AND NOT EXISTS (
          SELECT 1 FROM review_log r WHERE r.card_id = f.id AND r.at = ?
        )
        ''',
        [
          at,
          review.interval,
          review.isNew ? 1 : 0,
          review.graded ? 1 : 0,
          review.arabicWord,
          review.deckName,
          at,
        ],
      );
    }
    final before = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM review_log'),
    )!;
    await batch.commit(noResult: true);
    final after = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM review_log'),
    )!;
    return after - before;
  }

  /// The library as it stands, if it has changes that haven't been
  /// uploaded; null if there's nothing to send.
  Future<LibrarySnapshot?> getDirtyLibrary() async {
    final db = await database;
    final state = (await db.query('library_state')).single;
    if (state['dirty'] == 0 || state['updated_at'] == null) return null;

    final favorites = await db.rawQuery('''
      SELECT d.name AS deck, f.arabic_word AS word
      FROM flashcards f JOIN decks d ON d.id = f.deck_id
      WHERE f.favorite = 1 ORDER BY f.id
    ''');
    final collections = await db.query(
      'collections',
      orderBy: 'created_at ASC, id ASC',
    );
    final cards = await db.rawQuery('''
      SELECT cc.collection_id, d.name AS deck, f.arabic_word AS word,
             cc.added_at
      FROM collection_cards cc
      JOIN flashcards f ON f.id = cc.card_id
      JOIN decks d ON d.id = f.deck_id
      ORDER BY cc.added_at ASC, cc.rowid ASC
    ''');
    return LibrarySnapshot(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        state['updated_at'] as int,
      ),
      data: {
        'favorites': [
          for (final row in favorites)
            {'deck': row['deck'], 'word': row['word']},
        ],
        'collections': [
          for (final collection in collections)
            {
              'name': collection['name'],
              'created_at': collection['created_at'],
              'cards': [
                for (final row in cards)
                  if (row['collection_id'] == collection['id'])
                    {
                      'deck': row['deck'],
                      'word': row['word'],
                      'added_at': row['added_at'],
                    },
              ],
            },
        ],
      },
    );
  }

  /// Clears the library's dirty flag once [uploaded] has gone up. Matching
  /// on its timestamp means a change made while the upload was in flight
  /// stays dirty and goes up next time.
  Future<void> markLibrarySynced(LibrarySnapshot uploaded) async {
    final db = await database;
    await db.update(
      'library_state',
      {'dirty': 0},
      where: 'updated_at = ?',
      whereArgs: [uploaded.updatedAt.millisecondsSinceEpoch],
    );
  }

  /// Replaces the local library with [remote] if that's the newer of the
  /// two (or there's nothing local), and returns whether it did. Anything
  /// in it that names a card this device doesn't have is skipped.
  Future<bool> applyRemoteLibrary(LibrarySnapshot remote) async {
    final db = await database;
    final remoteAt = remote.updatedAt.millisecondsSinceEpoch;
    final localAt = (await db.query('library_state')).single['updated_at'];
    if (localAt != null && (localAt as int) >= remoteAt) return false;

    const cardId = '''
      (SELECT f.id FROM flashcards f JOIN decks d ON d.id = f.deck_id
       WHERE f.arabic_word = ? AND d.name = ?)
    ''';
    await db.transaction((txn) async {
      await txn.update('flashcards', {'favorite': 0});
      await txn.delete('collections');
      for (final favorite in remote.data['favorites'] as List? ?? const []) {
        await txn.rawUpdate(
          'UPDATE flashcards SET favorite = 1 WHERE id = $cardId',
          [favorite['word'], favorite['deck']],
        );
      }
      for (final collection
          in remote.data['collections'] as List? ?? const []) {
        final id = await txn.insert('collections', {
          'name': collection['name'],
          'created_at': collection['created_at'],
        });
        for (final card in collection['cards'] as List? ?? const []) {
          await txn.rawInsert(
            '''
            INSERT OR IGNORE INTO collection_cards
              (collection_id, card_id, added_at)
            SELECT ?, $cardId, ? WHERE $cardId IS NOT NULL
            ''',
            [
              id,
              card['word'],
              card['deck'],
              card['added_at'],
              card['word'],
              card['deck'],
            ],
          );
        }
      }
      await txn.update('library_state', {'updated_at': remoteAt, 'dirty': 0});
    });
    return true;
  }

  // ---- Sentences -----------------------------------------------------------
  //
  // The corpus is built to grow into the thousands, so nothing here ever
  // reads all of it: the explorer pages through it, a word looks its
  // sentences up through the `sentence_words` index, and a sentence only
  // gets a row in `flashcards` when the user adds it to their queue.

  /// Makes a sentence's flashcard from its corpus row, unless it has one.
  /// Arguments: deck id, next_review, the sentence's Arabic, deck id.
  static const _insertSentenceCard = '''
    INSERT INTO flashcards
      (arabic_word, english_translation, example_sentence, deck_id,
       next_review, kind)
    SELECT s.arabic, s.english, '', ?, ?, 'sentence'
    FROM sentences s
    WHERE s.arabic = ? AND NOT EXISTS (
      SELECT 1 FROM flashcards f
      WHERE f.arabic_word = s.arabic AND f.deck_id = ?
    )
  ''';

  /// A sentence together with its flashcard's state, if it has one.
  static const _selectSentences = '''
    SELECT s.id, s.arabic, s.english,
           f.id AS card_id, f.is_new, f.queued_at
    FROM sentences s
    LEFT JOIN flashcards f
      ON f.arabic_word = s.arabic AND f.kind = 'sentence'
  ''';

  // ---- Downloaded content ---------------------------------------------------

  Future<({String hash, String body})?> getContentFile(String path) async {
    final db = await database;
    final rows = await db.query(
      'content_files',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (rows.isEmpty) return null;
    return (
      hash: rows.single['hash'] as String,
      body: rows.single['body'] as String,
    );
  }

  /// Saves downloaded files all together, or not at all.
  Future<void> saveContentFiles(
    Map<String, ({String hash, String body})> files,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final MapEntry(key: path, value: file) in files.entries) {
        await txn.insert('content_files', {
          'path': path,
          'hash': file.hash,
          'body': file.body,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearContentFiles() async {
    final db = await database;
    await db.delete('content_files');
  }

  /// Which edition of the corpus is loaded, or null if none is.
  Future<String?> getSentencesVersion() async {
    final db = await database;
    final rows = await db.query(
      'content_meta',
      where: 'key = ?',
      whereArgs: ['sentences_version'],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Replaces the whole corpus with [sentences] and records it as
  /// [version]. Each entry comes with the keys it's indexed under (see
  /// `sentenceKeys`). One transaction, written in batches, so even ten
  /// thousand sentences load in one go and a crash halfway leaves the old
  /// corpus in place. Flashcards made from sentences aren't touched.
  Future<void> replaceSentences(
    List<({String arabic, String english, String search, Set<String> keys})>
    sentences, {
    required String version,
  }) async {
    final db = await database;
    // Rows go in many to a statement: one statement per row is most of the
    // cost of a big load, in a browser especially. Each statement stays
    // under 999 values, the most an older Android SQLite allows.
    final sentenceRows = [
      for (final (index, sentence) in sentences.indexed)
        [index + 1, sentence.arabic, sentence.english, sentence.search],
    ];
    final wordRows = [
      for (final (index, sentence) in sentences.indexed)
        for (final key in sentence.keys) [key, index + 1],
    ];
    await db.transaction((txn) async {
      await txn.delete('sentence_words');
      await txn.delete('sentences');
      await _insertMany(
        txn,
        'INSERT OR IGNORE INTO sentences (id, arabic, english, search)',
        sentenceRows,
      );
      await _insertMany(
        txn,
        'INSERT OR IGNORE INTO sentence_words (word, sentence_id)',
        wordRows,
      );
      await txn.insert('content_meta', {
        'key': 'sentences_version',
        'value': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Inserts [rows] (each a list of values, in the order [insert] names
  /// the columns) a few hundred to a statement.
  static Future<void> _insertMany(
    Transaction txn,
    String insert,
    List<List<Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    final columns = rows.first.length;
    final perStatement = 999 ~/ columns;
    final placeholder = '(${List.filled(columns, '?').join(', ')})';
    final batch = txn.batch();
    for (var start = 0; start < rows.length; start += perStatement) {
      final chunk = rows.sublist(
        start,
        (start + perStatement).clamp(0, rows.length),
      );
      batch.rawInsert(
        '$insert VALUES ${List.filled(chunk.length, placeholder).join(', ')}',
        [for (final row in chunk) ...row],
      );
    }
    await batch.commit(noResult: true);
  }

  /// One page of the corpus in its own order: [limit] sentences starting
  /// [offset] in, narrowed to those containing [search] if that's given.
  /// [search] must already be folded the way the `search` column is.
  Future<List<Sentence>> searchSentences({
    String search = '',
    required int limit,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      $_selectSentences
      ${search.isEmpty ? '' : "WHERE s.search LIKE ? ESCAPE '!'"}
      ORDER BY s.id LIMIT ? OFFSET ?
      ''',
      [if (search.isNotEmpty) '%${_escapeLike(search)}%', limit, offset],
    );
    return rows.map(Sentence.fromMap).toList();
  }

  /// Up to [limit] sentences that contain any of the words [keys] (word
  /// cards' Arabic, reduced with `wordKey`).
  Future<List<Sentence>> getSentencesWithWords(
    List<String> keys, {
    int limit = 20,
  }) async {
    if (keys.isEmpty) return [];
    final db = await database;
    final rows = await db.rawQuery(
      '''
      $_selectSentences
      WHERE s.id IN (
        SELECT sentence_id FROM sentence_words
        WHERE word IN (${List.filled(keys.length, '?').join(', ')})
      )
      ORDER BY s.id LIMIT ?
      ''',
      [...keys, limit],
    );
    return rows.map(Sentence.fromMap).toList();
  }

  Future<int> countSentences() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sentences'),
    )!;
  }

  /// Puts a sentence in the study queue, making its flashcard if this is
  /// the first time, or takes it back out. Taking out a sentence that was
  /// never studied removes its card again, so the cards table only ever
  /// holds sentences the user is actually doing something with. One
  /// that's already being studied is made due now instead, as for any
  /// other card (see [setQueued]). Returns the card's id, or null if the
  /// card was removed or there's no such sentence.
  Future<int?> setSentenceQueued(int sentenceId, bool queued) async {
    final db = await database;
    final row = await db.query(
      'sentences',
      columns: ['arabic'],
      where: 'id = ?',
      whereArgs: [sentenceId],
    );
    if (row.isEmpty) return null;
    final arabic = row.single['arabic'] as String;
    final deck = await getOrCreateDeck(
      sentencesSource.deckName,
      description: sentencesSource.description,
    );
    if (queued) {
      await db.rawInsert(_insertSentenceCard, [
        deck.id,
        DateTime.now().millisecondsSinceEpoch,
        arabic,
        deck.id,
      ]);
    }
    final cards = await db.query(
      'flashcards',
      columns: ['id', 'is_new', 'favorite'],
      where: 'arabic_word = ? AND deck_id = ?',
      whereArgs: [arabic, deck.id],
    );
    if (cards.isEmpty) return null;
    final cardId = cards.single['id'] as int;
    await setQueued(cardId, queued);
    final inCollection = await db.query(
      'collection_cards',
      where: 'card_id = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    final untouched =
        cards.single['is_new'] == 1 &&
        cards.single['favorite'] == 0 &&
        inCollection.isEmpty;
    if (!queued && untouched) {
      await deleteFlashcard(cardId);
      return null;
    }
    return cardId;
  }

  /// Makes [text] safe inside a LIKE pattern that uses `!` as its escape.
  static String _escapeLike(String text) =>
      text.replaceAllMapped(RegExp('[!%_]'), (match) => '!${match.group(0)}');

  // ---- Search ------------------------------------------------------------

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
    return rows.map(Flashcard.fromMap).where((card) {
      final matchesArabic = normalizeArabic(
        card.arabicWord,
      ).contains(normalizedQuery);
      final matchesEnglish = card.englishTranslation.toLowerCase().contains(
        lowerQuery,
      );
      return matchesArabic || matchesEnglish;
    }).toList();
  }
}
