import 'dart:async';
import 'dart:js_interop';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:web/web.dart' as web;

/// In a browser, SQLite runs as WebAssembly and keeps the database in the
/// browser's own storage (IndexedDB), so it survives reloads and works
/// offline, just like the file on a phone. `web/sqlite3.wasm` is put there
/// by `dart run sqflite_common_ffi_web:setup` (which also writes a
/// `sqflite_sw.js` for the shared worker; that isn't used, see below).
///
/// It runs on the page itself rather than in a worker. In a shared worker
/// the first launch's import stalled partway through, and in a dedicated
/// worker it took three times as long (every query is a message there and
/// back), for queries that take a millisecond or two on the page.
void configurePlatformDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

/// Makes this tab the only one using the database, and says whether that
/// worked. Each tab holds its own copy of the database in memory and saves
/// it back to browser storage, so two tabs writing at once could overwrite
/// each other's work. A browser lock (held for as long as the tab is open)
/// lets just one in; any other tab is told the app is open elsewhere.
Future<bool> claimDatabase() {
  final claimed = Completer<bool>();
  web.window.navigator.locks.request(
    'arabic-decoded-database',
    web.LockOptions(ifAvailable: true),
    ((web.Lock? lock) {
      claimed.complete(lock != null);
      // Never finishes, so the lock is held until the tab closes.
      return lock == null ? null : Completer<JSAny?>().future.toJS;
    }).toJS,
  );
  return claimed.future;
}
