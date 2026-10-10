import 'package:arabic_decoded/models/card_progress.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/services/progress_remote.dart';
import 'package:arabic_decoded/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stands in for the `card_progress` table: one map of rows per user,
/// keyed the same way the real table's primary key is, and applying the
/// same "ignore an update older than what's stored" rule as its trigger.
class _FakeBackend {
  final Map<String, Map<String, CardProgress>> _rows = {};

  ProgressRemote forUser(String userId) =>
      _FakeRemote(_rows.putIfAbsent(userId, () => {}));

  List<CardProgress> rowsOf(String userId) =>
      (_rows[userId] ?? {}).values.toList();
}

class _FakeRemote implements ProgressRemote {
  _FakeRemote(this._rows);

  final Map<String, CardProgress> _rows;

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
}

class _OfflineRemote implements ProgressRemote {
  @override
  Future<List<CardProgress>> fetchAll() => throw Exception('offline');

  @override
  Future<void> upsert(List<CardProgress> progress) =>
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

    expect(changed, 1);
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
