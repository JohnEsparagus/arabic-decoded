import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_providers.dart';
import 'providers/settings_providers.dart';
import 'screens/root_shell.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set up sqflite_common_ffi for desktop *before* anything can touch the
  // database — DatabaseService's constructor does this too, but doing it
  // here as well removes any doubt about ordering relative to Riverpod's
  // lazy provider initialization.
  DatabaseService.configureDatabaseFactory();
  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: 'https://dyuqjlvfogxwcyzdftbg.supabase.co',
    publishableKey: 'sb_publishable_pD-obz9gdGRJ78r2WL5zSQ_6gFZtTe0',
  );
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const ArabicDecodedApp(),
    ),
  );
}

class ArabicDecodedApp extends ConsumerWidget {
  const ArabicDecodedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'Arabic Decoded',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const RootShell(),
    );
  }
}
