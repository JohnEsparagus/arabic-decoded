import 'dart:async';

import 'package:arabic_decoded/models/deck.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/providers/database_providers.dart';
import 'package:arabic_decoded/providers/study_session_provider.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:arabic_decoded/services/sm2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

ProviderContainer _containerFor(DatabaseService db) {
  final container = ProviderContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(db),
      // These tests seed their own cards directly rather than through the
      // real campaign.json content, so skip the real import entirely.
      campaignDecksProvider.overrideWith((ref) async => <Deck>[]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
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

    final container = _containerFor(db);
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
    final secondContainer = _containerFor(db);
    final secondState = await _loaded(secondContainer);
    expect(secondState.newQueue, isEmpty);
    expect(secondState.phase, StudyPhase.done);
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

    final container = _containerFor(db);
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
}
