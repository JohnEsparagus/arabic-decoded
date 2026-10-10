import 'package:arabic_decoded/models/card_progress.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/models/synced_extras.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/services/progress_remote.dart';
import 'package:arabic_decoded/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stands in for the backend's tables: per user, a map of progress rows
/// keyed the same way the real table's primary key is, the review log and
/// the library. It applies the same rules the real thing does: an update
/// older than what's stored is ignored, and a review that's already there
/// isn't added twice.
class _FakeBackend {
  final Map<String, _FakeRemote> _users = {};

  _FakeRemote forUser(String userId) =>
      _users.putIfAbsent(userId, _FakeRemote.new);

  List<CardProgress> rowsOf(String userId) =>
      forUser(userId)._rows.values.toList();
}

class _FakeRemote implements ProgressRemote {
  final Map<String, CardProgress> _rows = {};
  final List<SyncedReview> reviews = [];
  LibrarySnapshot? library;

  /// Set to make the review log and library fail, as they would against a
  /// backend that doesn't have their tables yet.
  bool extrasBroken = false;

  @override
  Future<List<CardProgress>> fetchAll() async => _rows.values.toList();

  @override
  Future<void> upsert(List<CardProgress> progress) async {
    for (final p in progress) {
      final key = '${p.deckName}/${p.arabicWord}';
      final existing = _rows[key];
      if (existing != null && p.updatedAt.isBefore(existing.updatedAt)) {
        continue;
      }
      _rows[key] = p;
    }
  }

  @override
  Future<List<SyncedReview>> fetchReviews({
    required int afterId,
    required int limit,
  }) async {
    if (extrasBroken) throw Exception('no such table');
    return reviews.where((r) => r.id > afterId).take(limit).toList();
  }

  @override
  Future<void> addReviews(List<SyncedReview> added) async {
    if (extrasBroken) throw Exception('no such table');
    for (final r in added) {
      final exists = reviews.any(
        (e) =>
            e.deckName == r.deckName &&
            e.arabicWord == r.arabicWord &&
            e.at == r.at,
      );
      if (exists) continue;
      reviews.add(
        SyncedReview(
          id: reviews.length + 1,
          deckName: r.deckName,
          arabicWord: r.arabicWord,
          at: r.at,
          interval: r.interval,
          isNew: r.isNew,
          graded: r.graded,
        ),
      );
    }
  }

  @override
  Future<LibrarySnapshot?> fetchLibrary() async {
    if (extrasBroken) throw Exception('no such table');
    return library;
  }

  @override
  Future<void> upsertLibrary(LibrarySnapshot uploaded) async {
    if (extrasBroken) throw Exception('no such table');
    final existing = library;
    if (existing != null && uploaded.updatedAt.isBefore(existing.updatedAt)) {
      return;
    }
    library = uploaded;
  }
}

class _OfflineRemote implements ProgressRemote {
  @override
  Future<List<CardProgress>> fetchAll() => throw Exception('offline');

  @override
  Future<void> upsert(List<CardProgress> progress) =>
      throw Exception('offline');

  @override
  Future<List<SyncedReview>> fetchReviews({
    required int afterId,
    required int limit,
  }) => throw Exception('offline');

  @override
  Future<void> addReviews(List<SyncedReview> reviews) =>
      throw Exception('offline');

  @override
  Future<LibrarySnapshot?> fetchLibrary() => throw Exception('offline');

  @override
  Future<void> upsertLibrary(LibrarySnapshot library) =>
      throw Exception('offline');
}

const _deck = 'Test Campaign';

/// A fresh "device": its own database with [words] imported as new cards.
Future<DatabaseService> _device(List<String> words) async {
  final db = DatabaseService(pathOverride: inMemoryDatabasePath);
  final deck = await db.getOrCreateDeck(_deck);
  for (final word in words) {
    await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: word,
        englishTranslation: '$word-meaning',
        exampleSentence: '',
        deckId: deck.id!,
      ),
    );
  }
  return db;
}

Future<Flashcard> _card(DatabaseService db, String word) async {
  return (await db.getAllFlashcards()).firstWhere((c) => c.arabicWord == word);
}

/// Grades [word] the way the study session does: no longer new, with the
/// given SM-2 interval.
Future<void> _grade(DatabaseService db, String word, {int interval = 1}) async {
  final card = await _card(db, word);
  await db.updateFlashcard(
    card.copyWith(
      isNew: false,
      interval: interval,
      repetitions: card.repetitions + 1,
      introducedAt: card.introducedAt ?? DateTime.now(),
      nextReview: DateTime.now().add(Duration(days: interval)),
    ),
  );
}

CardProgress _remoteRow(String word, {required DateTime updatedAt}) {
  return CardProgress(
    deckName: _deck,
    arabicWord: word,
    easeFactor: 2.6,
    interval: 42,
    repetitions: 5,
    nextReview: updatedAt.add(const Duration(days: 42)),
    introducedAt: updatedAt.subtract(const Duration(days: 60)),
    updatedAt: updatedAt,
  );
}

void main() {
  late SharedPreferences prefs;
  late _FakeBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = _FakeBackend();
  });

  SyncService syncFor(
    DatabaseService db,
    String userId, {
    SharedPreferences? p,
  }) {
    return SyncService(
      db: db,
      remote: backend.forUser(userId),
      prefs: p ?? prefs,
      userId: userId,
    );
  }

  test('progress made on one device shows up on another', () async {
    final phone = await _device(['a', 'b']);
    await _grade(phone, 'a', interval: 6);
    await syncFor(phone, 'user-1').sync();

    expect(backend.rowsOf('user-1').map((r) => r.arabicWord), ['a']);

    // A second device has its own preferences as well as its own database.
    SharedPreferences.setMockInitialValues({});
    final laptop = await _device(['a', 'b']);
    final changed = await syncFor(laptop, 'user-1').sync();

    // The card's progress, and the review-log entry that goes with it.
    expect(changed, 2);
    final a = await _card(laptop, 'a');
    expect(a.isNew, isFalse);
    expect(a.interval, 6);
    expect(a.introducedAt, isNotNull);
    expect((await _card(laptop, 'b')).isNew, isTrue);
  });

  test('uploaded cards are not uploaded again', () async {
    final db = await _device(['a']);
    await _grade(db, 'a');
    expect(await db.getDirtyProgress(), hasLength(1));

    await syncFor(db, 'user-1').sync();
    expect(await db.getDirtyProgress(), isEmpty);
  });

  test('progress made before signing in is merged into the account', () async {
    final db = await _device(['a', 'b']);
    // Studied as a guest: nobody has ever signed in on this device.
    await _grade(db, 'a');
    // Meanwhile the account already has progress for a different card.
    await backend.forUser('user-1').upsert([
      _remoteRow('b', updatedAt: DateTime.now()),
    ]);

    await syncFor(db, 'user-1').sync();

    expect((await _card(db, 'a')).isNew, isFalse);
    expect((await _card(db, 'b')).interval, 42);
    expect(backend.rowsOf('user-1').map((r) => r.arabicWord).toSet(), {
      'a',
      'b',
    });
  });

  test('a conflict is won by whichever side was graded last', () async {
    final db = await _device(['older', 'newer']);
    await _grade(db, 'older', interval: 1);
    await _grade(db, 'newer', interval: 1);

    final now = DateTime.now();
    await backend.forUser('user-1').upsert([
      // Graded on another device after this one: remote wins.
      _remoteRow('older', updatedAt: now.add(const Duration(hours: 1))),
      // Graded on another device before this one: local wins.
      _remoteRow('newer', updatedAt: now.subtract(const Duration(hours: 1))),
    ]);

    await syncFor(db, 'user-1').sync();

    expect((await _card(db, 'older')).interval, 42);
    expect((await _card(db, 'newer')).interval, 1);
    final remote = {
      for (final row in backend.rowsOf('user-1')) row.arabicWord: row,
    };
    expect(remote['older']!.interval, 42);
    expect(remote['newer']!.interval, 1);
    expect(await db.getDirtyProgress(), isEmpty);
  });

  test('signing in as someone else does not leak the last user\'s progress, '
      'and switching back restores it', () async {
    final db = await _device(['a']);
    await _grade(db, 'a', interval: 6);
    await syncFor(db, 'user-1').sync();

    final changed = await syncFor(db, 'user-2').sync();

    expect(changed, greaterThan(0));
    expect((await _card(db, 'a')).isNew, isTrue);
    expect(backend.rowsOf('user-2'), isEmpty);

    await syncFor(db, 'user-1').sync();
    expect((await _card(db, 'a')).interval, 6);
  });

  test('a failed sync keeps changes queued for the next attempt', () async {
    final db = await _device(['a']);
    await _grade(db, 'a');

    final offline = SyncService(
      db: db,
      remote: _OfflineRemote(),
      prefs: prefs,
      userId: 'user-1',
    );
    await expectLater(offline.sync(), throwsException);
    expect(await db.getDirtyProgress(), hasLength(1));

    // The service is still usable afterwards, not stuck "running".
    await expectLater(offline.push(), throwsException);

    await syncFor(db, 'user-1').sync();
    expect(backend.rowsOf('user-1'), hasLength(1));
    expect(await db.getDirtyProgress(), isEmpty);
  });

  test('remote progress for a card this device does not have is skipped, '
      'not an error', () async {
    final db = await _device(['a']);
    await backend.forUser('user-1').upsert([
      _remoteRow('not-imported-here', updatedAt: DateTime.now()),
    ]);

    expect(await syncFor(db, 'user-1').sync(), 0);
    expect((await _card(db, 'a')).isNew, isTrue);
  });

  /// A second device: its own database and its own preferences.
  Future<(DatabaseService, SyncService)> secondDevice(
    List<String> words,
    String userId,
  ) async {
    final db = await _device(words);
    SharedPreferences.setMockInitialValues({});
    final otherPrefs = await SharedPreferences.getInstance();
    return (db, syncFor(db, userId, p: otherPrefs));
  }

  test('review history follows the account to another device, once', () async {
    final phone = await _device(['a', 'b']);
    await _grade(phone, 'a', interval: 6);
    await _grade(phone, 'b');
    await phone.markMastered((await _card(phone, 'b')).id!);
    final phoneSync = syncFor(phone, 'user-1');
    await phoneSync.sync();
    expect(backend.forUser('user-1').reviews, hasLength(3));

    final (laptop, laptopSync) = await secondDevice(['a', 'b'], 'user-1');
    await laptopSync.sync();

    // The same three entries, graded or not as they were on the phone,
    // with no stand-ins added alongside them for the progress that came
    // down in the same sync.
    final log = await laptop.getReviewLog();
    expect(log.map((e) => e.interval), [6, 1, 180]);
    expect(log.map((e) => e.graded), [true, true, false]);

    // Syncing again, either side, neither re-downloads nor re-uploads.
    await laptopSync.sync();
    await phoneSync.sync();
    expect(await laptop.getReviewLog(), hasLength(3));
    expect(await phone.getReviewLog(), hasLength(3));
    expect(backend.forUser('user-1').reviews, hasLength(3));
  });

  test('favorites and collections follow the account, newest change '
      'winning', () async {
    final phone = await _device(['a', 'b', 'c']);
    await phone.setFavorite((await _card(phone, 'a')).id!, true);
    final travel = await phone.createCollection('Travel');
    await phone.setInCollection(travel, (await _card(phone, 'c')).id!, true);
    await phone.setInCollection(travel, (await _card(phone, 'b')).id!, true);
    final phoneSync = syncFor(phone, 'user-1');
    await phoneSync.sync();

    final (laptop, laptopSync) = await secondDevice(['a', 'b', 'c'], 'user-1');
    await laptopSync.sync();
    expect((await _card(laptop, 'a')).isFavorite, isTrue);
    expect((await _card(laptop, 'b')).isFavorite, isFalse);
    final copied = (await laptop.getCollections()).single;
    expect(copied.name, 'Travel');
    expect(
      (await laptop.getCollectionFlashcards(
        copied.id,
      )).map((c) => c.arabicWord),
      ['c', 'b'],
    );

    // A later change on the laptop replaces what the phone has.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await laptop.deleteCollection(copied.id);
    await laptop.setFavorite((await _card(laptop, 'b')).id!, true);
    await laptopSync.sync();
    await phoneSync.sync();
    expect(await phone.getCollections(), isEmpty);
    expect((await _card(phone, 'a')).isFavorite, isTrue);
    expect((await _card(phone, 'b')).isFavorite, isTrue);
  });

  test('a backend without the extras still syncs card progress', () async {
    final phone = await _device(['a']);
    await _grade(phone, 'a', interval: 6);
    await phone.setFavorite((await _card(phone, 'a')).id!, true);
    backend.forUser('user-1').extrasBroken = true;
    final sync = syncFor(phone, 'user-1');

    await expectLater(sync.sync(), throwsException);
    expect(backend.rowsOf('user-1').single.interval, 6);
    expect(await phone.getDirtyProgress(), isEmpty);

    // Nothing was lost: once the backend catches up, the extras go too.
    backend.forUser('user-1').extrasBroken = false;
    await sync.sync();
    expect(backend.forUser('user-1').reviews, hasLength(1));
    expect(backend.forUser('user-1').library, isNotNull);
  });

  test('another account taking over the device does not inherit the '
      'library or the history', () async {
    final db = await _device(['a']);
    await _grade(db, 'a');
    await db.setFavorite((await _card(db, 'a')).id!, true);
    await db.createCollection('Mine');
    await syncFor(db, 'user-1').sync();

    await syncFor(db, 'user-2').sync();
    expect(await db.getReviewLog(), isEmpty);
    expect(await db.getCollections(), isEmpty);
    expect((await _card(db, 'a')).isFavorite, isFalse);
    expect(backend.forUser('user-2').reviews, isEmpty);
    expect(backend.forUser('user-2').library, isNull);

    // And the first account gets everything back when it returns.
    await syncFor(db, 'user-1').sync();
    expect(await db.getReviewLog(), hasLength(1));
    expect((await db.getCollections()).single.name, 'Mine');
    expect((await _card(db, 'a')).isFavorite, isTrue);
  });

  test('CardProgress survives a round trip through its remote row', () {
    final original = _remoteRow(
      'ك ت ب',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1790000000123),
    );
    final restored = CardProgress.fromRemote(
      original.toRemote(userId: 'user-1'),
    );

    expect(restored.deckName, original.deckName);
    expect(restored.arabicWord, original.arabicWord);
    expect(restored.easeFactor, original.easeFactor);
    expect(restored.interval, original.interval);
    expect(restored.repetitions, original.repetitions);
    expect(restored.nextReview, original.nextReview);
    expect(restored.introducedAt, original.introducedAt);
    expect(restored.updatedAt, original.updatedAt);
  });
}
