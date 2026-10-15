/// Points sqflite at the right SQLite for whatever the app is running on.
/// The native and web versions can't share a file: one needs `dart:ffi`,
/// which doesn't exist in a browser, and the other needs the browser's
/// JavaScript interop, which doesn't exist anywhere else.
library;

export 'platform_database_native.dart'
    if (dart.library.js_interop) 'platform_database_web.dart';
