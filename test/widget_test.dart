import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:arabic_decoded/main.dart';
import 'package:arabic_decoded/providers/database_providers.dart';
import 'package:arabic_decoded/services/database_service.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'Campaign tab studies cards, Dictionary browses + opens word detail, '
    'Campaigns tab browses the same deck as a root grid',
    (WidgetTester tester) async {
      // sqflite's internal locking uses real Timers, which the default
      // fake-async test zone can't resolve — pumping (and the real-time
      // waits between pumps) needs to happen inside `runAsync` so the
      // import -> read -> render chain can actually complete.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseServiceProvider.overrideWithValue(
                DatabaseService(pathOverride: inMemoryDatabasePath),
              ),
            ],
            child: const ArabicDecodedApp(),
          ),
        );
        await _settle(tester);

        // Campaign tab is selected by default and shows its flip-card
        // study session, front-side-up.
        expect(find.text('Campaign'), findsWidgets); // app bar + nav label
        expect(find.text('Show answer'), findsOneWidget);

        // Switch to the Dictionary tab: it should already have the words
        // imported by the Campaign tab available to browse. "Taking" (أ خ
        // ذ, from the Absolute Core campaign) sorts first alphabetically
        // across every campaign's roots, so it's guaranteed to be built
        // without scrolling — ListView.separated only builds what's near
        // the viewport.
        await tester.tap(find.text('Dictionary'));
        await _settle(tester);
        expect(find.text('Taking'), findsOneWidget);

        // Tapping a word opens its detail view (the flashcard back side),
        // showing detail-only content that plain dictionary rows don't:
        // the transliteration and the mnemonic tip (its 💡 marker is our
        // own widget chrome, not user-editable prose, so it's a stable
        // thing to assert on regardless of what the mnemonic text says).
        await tester.tap(find.text('Taking'));
        await _settle(tester);
        expect(find.text('ʾ-kh-dh'), findsOneWidget);
        expect(find.text('💡'), findsOneWidget);
        await tester.pageBack();
        await _settle(tester);

        // Switch to the Campaigns tab: same underlying decks, shown as
        // sections with a grid of compact root cards each. Absolute Core
        // is the first campaign, so its section renders without scrolling.
        // (Asserting on the deck name rather than a root count, since more
        // than one campaign happens to share the same root count.)
        await tester.tap(find.text('Campaigns'));
        await _settle(tester);
        expect(find.text('Absolute Core'), findsOneWidget);
      });
    },
  );
}
