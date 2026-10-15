import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The plain `sqflite` package only ships plugin implementations for
/// Android/iOS/macOS. On Linux and Windows this points it at
/// `sqflite_common_ffi` instead, which uses the system's SQLite library.
/// Elsewhere there's nothing to do.
void configurePlatformDatabaseFactory() {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

/// Only one copy of the app can be running on a phone or desktop, so
/// there's nobody to share the database with. (See the web version.)
Future<bool> claimDatabase() async => true;
