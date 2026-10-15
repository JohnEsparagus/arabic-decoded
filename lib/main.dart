import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_providers.dart';
import 'providers/settings_providers.dart';
import 'screens/root_shell.dart';
import 'services/database_service.dart';
import 'services/platform_database.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set up SQLite for desktop and the web *before* anything can touch the
  // database — DatabaseService's constructor does this too, but doing it
  // here as well removes any doubt about ordering relative to Riverpod's
  // lazy provider initialization.
  DatabaseService.configureDatabaseFactory();
  // In a browser, only one tab at a time may use the database.
  if (!await claimDatabase()) {
    runApp(const _OpenInAnotherTab());
    return;
  }
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
    final arabicFont = ref.watch(arabicFontProvider);
    return MaterialApp(
      title: 'Arabic Decoded',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        brightness: Brightness.light,
        arabicFont: arabicFont,
      ),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        arabicFont: arabicFont,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // On a wide screen (a desktop browser or window) the app keeps to a
      // phone-to-tablet width in the middle instead of stretching cards
      // across the whole display.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      ),
      home: const RootShell(),
    );
  }
}

/// What a second browser tab shows instead of the app (see
/// `claimDatabase`).
class _OpenInAnotherTab extends StatelessWidget {
  const _OpenInAnotherTab();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arabic Decoded',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Arabic Decoded is already open in another tab.\n\n'
                'Carry on there, or close it and reload this one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.ink, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
