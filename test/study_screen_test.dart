import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:arabic_decoded/models/deck.dart';
import 'package:arabic_decoded/providers/database_providers.dart';
import 'package:arabic_decoded/providers/settings_providers.dart';
import 'package:arabic_decoded/repositories/local_flashcard_repository.dart';
import 'package:arabic_decoded/screens/study_screen.dart';
import 'package:arabic_decoded/services/content_importer.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/theme/app_theme.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    // Pass an explicit duration so the flip card's TweenAnimationBuilder
    // (and any other implicit animation) actually advances — a bare
    // `pump()` only renders a frame at the current time, it doesn't move
    // the animation clock forward on its own.
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('flip reveals the answer, grading advances through the deck', (
    tester,
  ) async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final deck = await ContentImporter(
        LocalFlashcardRepository(db),
      ).importAsset(assetPath: 'assets/data/campaign.json', deckName: 'Campaign');
      final cardCount = (await db.getFlashcardsForDeck(deck.id!)).length;
      expect(cardCount, greaterThan(0));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(db),
            // Content is already imported above; skip the real import so
            // this test isn't coupled to what's in campaign_sources.dart.
            campaignDecksProvider.overrideWith((ref) async => <Deck>[deck]),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: StudySessionView(),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      // Front of the first card is showing; translation is hidden. Every
      // card is unstudied, so this is the "New card" phase.
      expect(find.text('New card'), findsOneWidget);
      expect(find.text('Show answer'), findsOneWidget);
      expect(find.text('Writing'), findsNothing);

      await tester.tap(find.text('Show answer'));
      await _settle(tester);

      // Flipping reveals the English translation and grading buttons.
      expect(find.text('Writing'), findsOneWidget);
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);

      // Grade every card in the deck as "Good" and confirm the session
      // ends. Card 1 is already flipped from above; flip each subsequent
      // card before grading it, since grading resets `revealed` to false.
      for (var i = 0; i < cardCount; i++) {
        if (i > 0) {
          expect(find.text('Show answer'), findsOneWidget);
          await tester.tap(find.text('Show answer'));
          await _settle(tester);
        }
        await tester.tap(find.text('Good'));
        await _settle(tester);
      }

      expect(find.textContaining('Reviewed $cardCount cards'), findsOneWidget);
    });
  });
}
