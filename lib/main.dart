import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/root_shell.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

void main() {
  // Set up sqflite_common_ffi for desktop *before* anything can touch the
  // database — DatabaseService's constructor does this too, but doing it
  // here as well removes any doubt about ordering relative to Riverpod's
  // lazy provider initialization.
  DatabaseService.configureDatabaseFactory();
  runApp(const ProviderScope(child: ArabicDecodedApp()));
}

class ArabicDecodedApp extends StatelessWidget {
  const ArabicDecodedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arabic Decoded',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootShell(),
    );
  }
}
