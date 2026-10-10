import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'progress_remote.dart';

/// Keeps one signed-in user's on-device progress and their [ProgressRemote]
/// copy in step.
///
/// The local SQLite database stays the thing the app actually reads and
/// writes — studying never waits on the network, and works offline. This
/// just reconciles the two afterwards: cards graded here are flagged dirty
/// (see [DatabaseService.updateFlashcard]) and uploaded, and anything
/// newer on the remote is copied down. Conflicts are settled per card by
/// whichever side was graded most recently.
///
/// Two more things ride along with every sync: the review history, and the
/// library (favorites and collections). A problem with either never holds
/// card progress back — see [_run].
class SyncService {
  SyncService({
    required this._db,
    required this._remote,
    required this._prefs,
    required this.userId,
  });

  final DatabaseService _db;
  final ProgressRemote _remote;
  final SharedPreferences _prefs;
  final String userId;

  /// Whose progress is currently sitting in the local database. Unset
  /// until someone signs in for the first time, i.e. while it's still
  /// anonymous "guest" progress.
  static const _ownerKey = 'sync.progress_owner';

  /// Marks whatever progress is on this device as nobody's, so the next
  /// account to sign in adopts it instead of clearing it.
  static Future<void> forgetOwner(SharedPreferences prefs) async {
    await prefs.remove(_ownerKey);
    await prefs.remove(_reviewCursorKey);
  }

  /// The highest server id among the review-log entries already fetched,
  /// so each sync only asks for what's been added since.
  static const _reviewCursorKey = 'sync.review_log_cursor';

  /// How many review-log entries go in one request, either way.
  static const _reviewPageSize = 500;

  Future<int>? _running;
  bool _again = false;
  bool _pullAgain = false;

  /// Pulls anything newer from the remote, then uploads local changes.
  /// Returns how many things changed locally as a result (cards, review
  /// history entries, the library), so callers know whether anything on
  /// screen needs refreshing.
  ///
  /// Calls made while a sync is already running don't start a second one
  /// in parallel — they share the running one, which then goes round once
  /// more to pick up whatever prompted the extra call.
  Future<int> sync() => _enqueue(pull: true);

  /// Uploads local changes without pulling first — the cheap version run
  /// after each graded card.
  Future<void> push() => _enqueue(pull: false);

  Future<int> _enqueue({required bool pull}) {
    final running = _running;
    if (running != null) {
      _again = true;
      _pullAgain = _pullAgain || pull;
      return running;
    }
    return _running = _run(pull: pull).whenComplete(() => _running = null);
  }

  Future<int> _run({required bool pull}) async {
    var changed = 0;
    var pullThisRound = pull;
    do {
      _again = false;
      _pullAgain = false;
      // Taking over a device from another account wipes what was here, so
      // that always needs a pull to fill it back in.
      if (await _claimLocalProgress()) {
        changed++;
        pullThisRound = true;
      }
      // The extras go either side of card progress, and a failure in
      // them is held until progress is done: studying comes first, and a
      // backend that doesn't have their tables yet shouldn't stop it
      // syncing. The error still surfaces, so the next sync retries.
      Object? extrasError;
      if (pullThisRound) {
        try {
          // Before progress, so the real log entries are in place by the
          // time applyRemoteProgress looks for cards whose history is
          // missing.
          changed += await _pullReviews();
          if (await _pullLibrary()) changed++;
        } catch (error) {
          extrasError = error;
        }
        changed += await _db.applyRemoteProgress(await _remote.fetchAll());
      }
      final dirty = await _db.getDirtyProgress();
      await _remote.upsert(dirty);
      await _db.markProgressSynced(dirty);
      if (extrasError == null) {
        try {
          await _pushReviews();
          await _pushLibrary();
        } catch (error) {
          extrasError = error;
        }
      }
      if (extrasError != null) throw extrasError;
      pullThisRound = _pullAgain;
    } while (_again);
    return changed;
  }

  /// Fetches review-log entries added since the last sync, a page at a
  /// time, and returns how many were new to this device.
  Future<int> _pullReviews() async {
    var added = 0;
    var cursor = _prefs.getInt(_reviewCursorKey) ?? 0;
    while (true) {
      final page = await _remote.fetchReviews(
        afterId: cursor,
        limit: _reviewPageSize,
      );
      if (page.isEmpty) break;
      added += await _db.applyRemoteReviews(page);
      cursor = page.last.id;
      await _prefs.setInt(_reviewCursorKey, cursor);
      if (page.length < _reviewPageSize) break;
    }
    return added;
  }

  Future<void> _pushReviews() async {
    while (true) {
      final batch = await _db.getUnsyncedReviews(limit: _reviewPageSize);
      if (batch.isEmpty) break;
      await _remote.addReviews(batch);
      await _db.markReviewsSynced(batch);
    }
  }

  /// Takes the remote library if it's newer than the local one. Returns
  /// whether anything changed here.
  Future<bool> _pullLibrary() async {
    final remote = await _remote.fetchLibrary();
    return remote != null && await _db.applyRemoteLibrary(remote);
  }

  Future<void> _pushLibrary() async {
    final library = await _db.getDirtyLibrary();
    if (library == null) return;
    await _remote.upsertLibrary(library);
    await _db.markLibrarySynced(library);
  }

  /// Decides what the progress already on this device means for [userId],
  /// and returns whether it had to be cleared.
  ///
  /// Guest progress (nobody has signed in here before) is kept, so it
  /// gets merged into the account — studying before signing up shouldn't
  /// be thrown away. Progress left behind by a *different* account is
  /// cleared instead, so it isn't uploaded into this one.
  Future<bool> _claimLocalProgress() async {
    final owner = _prefs.getString(_ownerKey);
    if (owner == userId) return false;
    final cleared = owner != null;
    if (cleared) await _db.clearProgress();
    await _prefs.setString(_ownerKey, userId);
    // Whoever the cursor belonged to, this account's history starts from
    // the top.
    await _prefs.remove(_reviewCursorKey);
    return cleared;
  }
}
