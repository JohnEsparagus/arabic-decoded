import 'dart:async';

import 'package:arabic_decoded/models/deck.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/providers/database_providers.dart';
import 'package:arabic_decoded/providers/settings_providers.dart';
import 'package:arabic_decoded/providers/study_session_provider.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/services/sm2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Waits for the session's initial async load to finish. Plain `test()`
/// (not `testWidgets()`) runs in a real async zone, so this is a normal
/// await — no fake-async pumping gymnastics needed here.
Future<StudySessionState> _loaded(ProviderContainer container) async {
  final current = container.read(studySessionProvider);
  if (!current.loading) return current;
  final completer = Completer<StudySessionState>();
  late final ProviderSubscription<StudySessionState> sub;
  sub = container.listen(studySessionProvider, (previous, next) {
    if (!next.loading) {
      completer.complete(next);
      sub.close();
    }
  });
  return completer.future;
}

Future<ProviderContainer> _containerFor(DatabaseService db) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(db),
      // These tests seed their own cards directly rather than through the
      // real campaign.json content, so skip the real import entirely.
      campaignDecksProvider.overrideWith((ref) async => <Deck>[]),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // A single shared (empty) mock backing store for the whole file — none
  // of these tests touch settings, so every container sees the same
  // untouched defaults (10 new cards/day) regardless of test order.
  SharedPreferences.setMockInitialValues({});

  test('new cards are capped at the daily limit', () async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');
    for (var i = 0; i < 15; i++) {
      await db.insertFlashcard(
        Flashcard.newCard(
          arabicWord: 'word$i',
          englishTranslation: 'meaning$i',
          exampleSentence: '',
          deckId: deck.id!,
        ),
      );
    }

    final container = await _containerFor(db);
    final state = await _loaded(container);

    expect(state.reviewQueue, isEmpty);
    expect(state.newQueue.length, 10); // maxNewCardsPerDayProvider default
    expect(state.phase, StudyPhase.newCards);
    expect(state.phaseTotal, 10);

    // Grade all 10 as Good — that's today's quota used up.
    final notifier = container.read(studySessionProvider.notifier);
    for (var i = 0; i < 10; i++) {
      await notifier.grade(Grade.good);
    }
    expect(container.read(studySessionProvider).phase, StudyPhase.done);

    // Re-opening the session the same day should show none of the 5
    // remaining new cards, even though they're still sitting in the deck.
    final secondContainer = await _containerFor(db);
    final secondState = await _loaded(secondContainer);
    expect(secondState.newQueue, isEmpty);
    expect(secondState.phase, StudyPhase.done);
  });

  test('raising the daily cap after running out surfaces more cards '
      'immediately, without waiting for tomorrow', () async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');
    for (var i = 0; i < 15; i++) {
      await db.insertFlashcard(
        Flashcard.newCard(
          arabicWord: 'word$i',
          englishTranslation: 'meaning$i',
          exampleSentence: '',
          deckId: deck.id!,
        ),
      );
    }

    final container = await _containerFor(db);
    final state = await _loaded(container);
    expect(state.newQueue.length, 10);

    // Exhaust today's default 10-card quota.
    final notifier = container.read(studySessionProvider.notifier);
    for (var i = 0; i < 10; i++) {
      await notifier.grade(Grade.good);
    }
    expect(container.read(studySessionProvider).phase, StudyPhase.done);

    // Raise the cap from Settings — StudySessionNotifier watches
    // maxNewCardsPerDayProvider, so this alone should re-trigger a load
    // (no explicit refresh call needed) and pick up 5 more of today's
    // still-new cards, since only 10 have actually been introduced so far.
    await container.read(maxNewCardsPerDayProvider.notifier).set(15);
    final afterRaise = await _loaded(container);

    expect(afterRaise.phase, StudyPhase.newCards);
    expect(afterRaise.newQueue.length, 5);
  });

  test('due reviews are shown before new cards, in their own phase', () async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');

    // A card that was already introduced and is now due again.
    await db.insertFlashcard(
      Flashcard(
        arabicWord: 'ك ت ب',
        englishTranslation: 'Writing',
        exampleSentence: '',
        deckId: deck.id!,
        nextReview: DateTime.now().subtract(const Duration(days: 1)),
        isNew: false,
        introducedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    );
    // Two cards that have never been studied.
    for (var i = 0; i < 2; i++) {
      await db.insertFlashcard(
        Flashcard.newCard(
          arabicWord: 'new$i',
          englishTranslation: 'new-meaning$i',
          exampleSentence: '',
          deckId: deck.id!,
        ),
      );
    }

    final container = await _containerFor(db);
    final state = await _loaded(container);

    expect(state.phase, StudyPhase.review);
    expect(state.reviewQueue, hasLength(1));
    expect(state.newQueue, hasLength(2));
    expect(state.phasePosition, 1);
    expect(state.phaseTotal, 1); // review phase total, not the whole session

    final notifier = container.read(studySessionProvider.notifier);
    await notifier.grade(Grade.good);

    // Review done -> now in the new-cards phase, counter restarts at 1.
    final afterReview = container.read(studySessionProvider);
    expect(afterReview.phase, StudyPhase.newCards);
    expect(afterReview.phasePosition, 1);
    expect(afterReview.phaseTotal, 2);
  });

  test(
    'grading "Again" requeues the card at the back of its own phase',
    () async {
      final db = DatabaseService(pathOverride: inMemoryDatabasePath);
      final deck = await db.getOrCreateDeck('Test Campaign');
      for (final word in ['a', 'b', 'c']) {
        await db.insertFlashcard(
          Flashcard.newCard(
            arabicWord: word,
            englishTranslation: '$word-meaning',
            exampleSentence: '',
            deckId: deck.id!,
          ),
        );
      }

      final container = await _containerFor(db);
      final state = await _loaded(container);
      expect(state.newQueue.map((c) => c.arabicWord), ['a', 'b', 'c']);

      final notifier = container.read(studySessionProvider.notifier);

      // Fail "a" — it should NOT just vanish until tomorrow; it goes to
      // the back of today's queue instead, and the next card up is "b".
      await notifier.grade(Grade.again);
      var current = container.read(studySessionProvider);
      expect(current.newQueue.map((c) => c.arabicWord), ['a', 'b', 'c', 'a']);
      expect(current.current?.arabicWord, 'b');
      expect(current.phaseTotal, 4); // grew by one when "a" was requeued

      await notifier.grade(Grade.good); // b
      await notifier.grade(Grade.good); // c

      // "a" comes back around before the session ends.
      current = container.read(studySessionProvider);
      expect(current.current?.arabicWord, 'a');
      expect(current.phase, StudyPhase.newCards);

      await notifier.grade(Grade.good); // a, second time
      expect(container.read(studySessionProvider).phase, StudyPhase.done);
      // 4 grading actions total: a (failed), b, c, a (passed).
      expect(container.read(studySessionProvider).reviewedCount, 4);
    },
  );

  test(
    'new cards are exhausted from one campaign before moving to the next',
    () async {
      final db = DatabaseService(pathOverride: inMemoryDatabasePath);

      final campaignA = await db.getOrCreateDeck('Campaign A');
      final campaignB = await db.getOrCreateDeck('Campaign B');
      for (var i = 0; i < 2; i++) {
        await db.insertFlashcard(
          Flashcard.newCard(
            arabicWord: 'a$i',
            englishTranslation: 'a-meaning$i',
            exampleSentence: '',
            deckId: campaignA.id!,
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        await db.insertFlashcard(
          Flashcard.newCard(
            arabicWord: 'b$i',
            englishTranslation: 'b-meaning$i',
            exampleSentence: '',
            deckId: campaignB.id!,
          ),
        );
      }

      // With quota to spare, a fetch spills past A into B rather than
      // stopping at A's boundary — that's the "auto-advance" behavior
      // that fills the day's quota across campaigns.
      final spillBatch = await db.getNewFlashcards(limit: 3);
      expect(spillBatch.map((c) => c.deckId).toSet(), {
        campaignA.id,
        campaignB.id,
      });

      // Campaign A was created first (lower deck id), so its cards come
      // first regardless of insertion order across decks. Limiting to
      // exactly A's card count isolates "A's cards only" from the
      // spilling behavior just checked above.
      final firstBatch = await db.getNewFlashcards(limit: 2);
      expect(firstBatch.map((c) => c.deckId).toSet(), {campaignA.id});

      // Introduce both of Campaign A's cards.
      for (final card in firstBatch) {
        await db.updateFlashcard(
          card.copyWith(isNew: false, introducedAt: DateTime.now()),
        );
      }

      // Campaign A is now exhausted — new cards should come from B.
      final secondBatch = await db.getNewFlashcards(limit: 10);
      expect(secondBatch.map((c) => c.deckId).toSet(), {campaignB.id});
      expect(secondBatch, hasLength(2));
    },
  );

  test('a read-once card is dismissed, not graded, and the session moves '
      'on to what it unlocked', () async {
    final db = DatabaseService(pathOverride: inMemoryDatabasePath);
    final deck = await db.getOrCreateDeck('Test Campaign');
    for (final root in ['root1', 'root2']) {
      await db.insertFlashcard(
        Flashcard.newCard(
          arabicWord: root,
          englishTranslation: root,
          exampleSentence: '',
          deckId: deck.id!,
        ),
      );
    }
    await db.insertFlashcard(
      Flashcard.newCard(
        arabicWord: 'A story',
        englishTranslation: 'Story',
        exampleSentence: 'Once upon a time…',
        deckId: deck.id!,
        kind: CardKind.info,
        unlockAfter: 1,
      ),
    );

    final container = await _containerFor(db);
    var state = await _loaded(container);
    final notifier = container.read(studySessionProvider.notifier);
    expect(state.current!.arabicWord, 'root1');

    // Grading isn't how you get past anything but a read-once card, and
    // dismissing does nothing to a card that should be graded.
    await notifier.dismiss();
    expect(container.read(studySessionProvider).current!.arabicWord, 'root1');

    await notifier.grade(Grade.good);
    state = container.read(studySessionProvider);
    expect(state.current!.arabicWord, 'A story');
    expect(state.reviewedCount, 1);

    await notifier.dismiss();
    state = container.read(studySessionProvider);
    expect(state.current!.arabicWord, 'root2');
    expect(state.reviewedCount, 1); // reading it isn't a card studied
  });
}
