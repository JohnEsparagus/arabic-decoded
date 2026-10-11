import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:arabic_decoded/main.dart';
import 'package:arabic_decoded/providers/database_providers.dart';
import 'package:arabic_decoded/providers/settings_providers.dart';
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
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseServiceProvider.overrideWithValue(
                DatabaseService(pathOverride: inMemoryDatabasePath),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const ArabicDecodedApp(),
          ),
        );
        await _settle(tester);

        // Home tab is selected by default and opens on the welcome card:
        // nothing studied yet, so nothing to review and a day's worth of
        // new cards waiting.
        expect(find.text('Home'), findsWidgets); // app bar + nav label
        expect(find.text('Welcome'), findsOneWidget);
        expect(find.text('to review'), findsOneWidget);
        expect(find.text('Overall progress'), findsOneWidget);
        expect(find.text('Study today to start a streak'), findsOneWidget);
        expect(find.text('0 of 20 today'), findsOneWidget);
        expect(find.textContaining('Start with the alphabet'), findsOneWidget);

        // Starting drops into the flip-card study session, front-side-up.
        await tester.tap(find.text('Start studying'));
        await _settle(tester);
        expect(find.text('Show answer'), findsOneWidget);

        // The sidebar opens from the menu button and leads to the stats.
        // Nothing has been studied, so the headline numbers are all zero.
        await tester.tap(find.byTooltip('Open navigation menu'));
        await _settle(tester);
        for (final item in [
          'Account',
          'Lessons',
          'Stories',
          'Sentences',
          'Settings',
          'About',
          'Dev updates',
        ]) {
          expect(find.text(item), findsOneWidget);
        }
        await tester.tap(find.text('Learning stats'));
        await _settle(tester);
        expect(find.text('Day streak'), findsOneWidget);
        expect(find.text('Mastered'), findsNWidgets(2)); // tile + legend
        await tester.tap(find.text('Years'));
        await _settle(tester);
        expect(find.text('${DateTime.now().year}'), findsOneWidget);
        await tester.pageBack();
        await _settle(tester);

        // Lessons are all listed, locked until enough roots are learnt.
        await tester.tap(find.byTooltip('Open navigation menu'));
        await _settle(tester);
        await tester.tap(find.text('Lessons'));
        await _settle(tester);
        expect(find.text('Three letters, one idea'), findsOneWidget);
        expect(find.text('Opens after 3 more roots'), findsOneWidget);
        await tester.pageBack();
        await _settle(tester);

        // The sentence explorer lists the corpus a page at a time, and a
        // tap on + puts a sentence in the queue.
        await tester.tap(find.byTooltip('Open navigation menu'));
        await _settle(tester);
        await tester.tap(find.text('Sentences'));
        await _settle(tester);
        expect(find.textContaining(' sentences'), findsOneWidget);
        expect(find.text('The student wrote a letter.'), findsOneWidget);
        expect(find.byTooltip('In your queue. Tap to remove'), findsNothing);
        await tester.tap(find.byTooltip('Add to my queue').first);
        await _settle(tester);
        expect(find.byTooltip('In your queue. Tap to remove'), findsOneWidget);
        await tester.tap(find.byTooltip('In your queue. Tap to remove'));
        await _settle(tester);
        expect(find.byTooltip('In your queue. Tap to remove'), findsNothing);
        await tester.pageBack();
        await _settle(tester);

        // Switch to the Dictionary tab: it should already have the words
        // imported by the Campaign tab available to browse. "Taking" (أ خ
        // ذ, from the Absolute Core campaign) sorts first alphabetically
        // across every campaign's roots, so it's guaranteed to be built
        // without scrolling — ListView.separated only builds what's near
        // the viewport.
        await tester.tap(find.text('Dictionary'));
        await _settle(tester);
        expect(find.text('Taking'), findsOneWidget);

        // Holding a card brings up its actions. Starring it from there
        // shows up on the row straight away.
        // (Held by hand rather than with `longPress`: inside `runAsync`
        // the hold timer runs on the real clock, which pumping alone
        // doesn't move.)
        final hold = await tester.startGesture(
          tester.getCenter(find.text('Taking')),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        await tester.pump();
        await hold.up();
        await _settle(tester);
        expect(find.text('Learn'), findsOneWidget);
        expect(find.text('Mark as mastered'), findsOneWidget);
        expect(find.text('Add to collection'), findsOneWidget);
        await tester.tap(find.text('Favorite'));
        await _settle(tester);
        expect(find.byIcon(Icons.star), findsOneWidget);

        // Tapping a word opens its detail view (the flashcard back side),
        // showing detail-only content that plain dictionary rows don't:
        // the transliteration and the mnemonic tip (its 💡 marker is our
        // own widget chrome, not user-editable prose, so it's a stable
        // thing to assert on regardless of what the mnemonic text says).
        await tester.tap(find.text('Taking'));
        await _settle(tester);
        expect(find.text('ʾ-kh-dh'), findsOneWidget);
        expect(find.text('💡'), findsOneWidget);

        // Roots and words are linked both ways: the root lists its
        // words, and a word has a link back to its root.
        expect(find.text('WORDS FROM THIS ROOT'), findsOneWidget);

        // Its sentences stay folded away until asked for, so the card
        // isn't cluttered; opening the section looks them up.
        expect(find.text('The student took the pen.'), findsNothing);
        await tester.ensureVisible(find.text('SENTENCES'));
        await tester.tap(find.text('SENTENCES'));
        await _settle(tester);
        expect(find.text('The student took the pen.'), findsOneWidget);
        await tester.tap(find.text('SENTENCES'));
        await _settle(tester);

        await tester.ensureVisible(find.text('to take'));
        await tester.tap(find.text('to take'));
        await _settle(tester);
        expect(find.text('The student took the pen.'), findsOneWidget);
        await tester.tap(find.text('FROM THE ROOT'));
        await _settle(tester);
        expect(find.text('WORDS FROM THIS ROOT'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.pageBack();
          await _settle(tester);
        }

        // Switch to the Campaigns tab: same underlying decks, shown as
        // sections with a grid of compact root cards each. Absolute Core
        // is the first campaign, so its section renders without scrolling.
        // (Asserting on the deck name rather than a root count, since more
        // than one campaign happens to share the same root count.)
        await tester.tap(find.text('Campaigns'));
        await _settle(tester);
        expect(find.text('Absolute Core'), findsOneWidget);

        // Holding a root tile selects it, tapping another adds it, and
        // the bar acts on both: mastering two roots makes their words
        // ready to learn.
        final holdTile = await tester.startGesture(
          tester.getCenter(find.text('k-t-b')),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        await tester.pump();
        await holdTile.up();
        await _settle(tester);
        expect(find.text('1 selected'), findsOneWidget);
        await tester.tap(find.text('q-w-l'));
        await _settle(tester);
        expect(find.text('2 selected'), findsOneWidget);
        await tester.tap(find.text('Mastered'));
        await _settle(tester);
        expect(find.text('2 selected'), findsNothing);
        expect(find.text('Marked 2 cards as mastered'), findsOneWidget);

        // The Words part shows learnt words (none yet) and, as tiles, the
        // ones ready to be: the words of the two roots just mastered.
        // Collections always has Favorites.
        await tester.tap(find.text('Words'));
        await _settle(tester);
        expect(find.text('No words learnt yet.'), findsOneWidget);
        expect(find.text('Ready to learn'), findsOneWidget);
        expect(find.text('kitāb'), findsOneWidget);
        // The Alphabet part has all 28 letters as tiles.
        await tester.tap(find.text('Alphabet'));
        await _settle(tester);
        expect(find.text('0 of 28 learnt'), findsOneWidget);
        expect(find.text('bāʾ'), findsOneWidget);
        await tester.tap(find.text('Collections'));
        await _settle(tester);
        expect(find.text('Favorites'), findsOneWidget);
        expect(find.text('New collection'), findsOneWidget);
      });
    },
  );
}
