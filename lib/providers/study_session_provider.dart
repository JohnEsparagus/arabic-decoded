import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../services/sm2.dart';
import 'database_providers.dart';
import 'settings_providers.dart';

/// Which part of the session is currently active. Review always comes
/// first — only once every due card has been reviewed does the session
/// start introducing new cards.
enum StudyPhase { review, newCards, done }

class StudySessionState {
  final List<Flashcard> reviewQueue;
  final List<Flashcard> newQueue;
  final int reviewIndex;
  final int newIndex;
  final bool revealed;
  final bool loading;
  final int reviewedCount;

  const StudySessionState({
    this.reviewQueue = const [],
    this.newQueue = const [],
    this.reviewIndex = 0,
    this.newIndex = 0,
    this.revealed = false,
    this.loading = true,
    this.reviewedCount = 0,
  });

  StudyPhase get phase {
    if (reviewIndex < reviewQueue.length) return StudyPhase.review;
    if (newIndex < newQueue.length) return StudyPhase.newCards;
    return StudyPhase.done;
  }

  Flashcard? get current => switch (phase) {
    StudyPhase.review => reviewQueue[reviewIndex],
    StudyPhase.newCards => newQueue[newIndex],
    StudyPhase.done => null,
  };

  /// 1-based position within the *current phase* (e.g. "2 of 5"), not the
  /// whole session — review and new cards are counted separately so the
  /// number resets when the session moves from reviewing into new cards.
  int get phasePosition =>
      (phase == StudyPhase.review ? reviewIndex : newIndex) + 1;

  int get phaseTotal =>
      phase == StudyPhase.review ? reviewQueue.length : newQueue.length;

  StudySessionState copyWith({
    List<Flashcard>? reviewQueue,
    List<Flashcard>? newQueue,
    int? reviewIndex,
    int? newIndex,
    bool? revealed,
    bool? loading,
    int? reviewedCount,
  }) {
    return StudySessionState(
      reviewQueue: reviewQueue ?? this.reviewQueue,
      newQueue: newQueue ?? this.newQueue,
      reviewIndex: reviewIndex ?? this.reviewIndex,
      newIndex: newIndex ?? this.newIndex,
      revealed: revealed ?? this.revealed,
      loading: loading ?? this.loading,
      reviewedCount: reviewedCount ?? this.reviewedCount,
    );
  }
}

/// Drives the single global study session: every already-introduced card
/// due for review (across all campaigns), followed by new cards pulled in
/// campaign order, capped at [maxNewCardsPerDayProvider] introductions per
/// day. There's only ever one queue in the whole app — campaigns don't get
/// their own separate review rotation, they just feed new cards into it.
class StudySessionNotifier extends Notifier<StudySessionState> {
  @override
  StudySessionState build() {
    // Re-run whenever the daily new-card cap changes (see
    // maxNewCardsPerDayProvider), so raising it after exhausting today's
    // quota can surface more cards immediately instead of only tomorrow.
    ref.watch(maxNewCardsPerDayProvider);
    // Same for switching words on or off: the queue is rebuilt around it.
    ref.watch(studyWordsProvider);
    ref.watch(studyAlphabetProvider);
    // Kick off the load without blocking `build`, which must stay
    // synchronous for a plain Notifier.
    Future.microtask(_load);
    return const StudySessionState();
  }

  Future<void> _load() async {
    final repository = ref.read(flashcardRepositoryProvider);
    // Make sure every campaign has been imported before pulling new cards
    // from them, so a fresh install has something to show.
    await ref.read(campaignDecksProvider.future);

    final reviewCards = await repository.getDueReviewFlashcards(
      includeWords: ref.read(studyWordsProvider),
      includeLetters: ref.read(studyAlphabetProvider),
    );
    final newCards = await _fetchNewCards();

    state = StudySessionState(
      reviewQueue: reviewCards,
      newQueue: newCards,
      reviewIndex: 0,
      newIndex: 0,
      loading: false,
    );
  }

  /// The cards the user queued by hand, all of them, then as many new
  /// cards as today's cap still allows, in teaching order. The cap is on
  /// what the app hands out; cards someone asked for aren't held back.
  Future<List<Flashcard>> _fetchNewCards() async {
    final repository = ref.read(flashcardRepositoryProvider);
    final queued = await repository.getQueuedFlashcards();
    final startOfToday = _startOfDay(DateTime.now());
    final introducedToday = await repository.countIntroducedSince(startOfToday);
    final maxPerDay = ref.read(maxNewCardsPerDayProvider);
    final remainingToday = (maxPerDay - introducedToday).clamp(0, maxPerDay);
    final upNext = await repository.getNewFlashcards(
      limit: remainingToday,
      includeWords: ref.read(studyWordsProvider),
      includeLetters: ref.read(studyAlphabetProvider),
    );
    return [...queued, ...upNext];
  }

  DateTime _startOfDay(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  void flip() {
    if (state.current == null) return;
    state = state.copyWith(revealed: !state.revealed);
  }

  Future<void> grade(Grade grade) async {
    final card = state.current;
    if (card == null) return;

    final result = computeSM2(
      easeFactor: card.easeFactor,
      interval: card.interval,
      repetitions: card.repetitions,
      quality: grade.quality,
    );
    final updated = card.copyWith(
      easeFactor: result.easeFactor,
      interval: result.interval,
      repetitions: result.repetitions,
      nextReview: result.nextReview,
      isNew: false,
      introducedAt: card.isNew ? DateTime.now() : card.introducedAt,
    );

    await ref.read(flashcardRepositoryProvider).updateFlashcard(updated);
    // "Again" means you didn't get it — put it back at the end of whichever
    // queue it came from so it comes up again before this session ends,
    // instead of only coming back tomorrow via its persisted next_review.
    await _advance(card, updated, requeue: grade == Grade.again);
  }

  /// Moves on from a read-once card ([CardKind.info]): it's marked as
  /// read, and that's all. No grade, no schedule.
  Future<void> dismiss() async {
    final card = state.current;
    if (card == null || card.kind != CardKind.info) return;
    await ref.read(flashcardRepositoryProvider).markSeen(card.id!);
    await _advance(card, card.copyWith(isNew: false), counts: false);
  }

  /// Steps the session past [card], which has just been saved as
  /// [updated]. [counts] is false for a card that was only read, which
  /// isn't one of the cards "seen" in the tally.
  Future<void> _advance(
    Flashcard card,
    Flashcard updated, {
    bool requeue = false,
    bool counts = true,
  }) async {
    final phase = state.phase;
    // The Campaigns tab's per-deck root grid and the Dictionary tab both
    // cache their flashcard lists independently of this session — without
    // invalidating them, a just-graded card's new mastery level/interval
    // wouldn't show up until something else happened to refresh them.
    ref.invalidate(deckFlashcardsProvider);
    ref.invalidate(dictionaryEntriesProvider);
    ref.invalidate(allFlashcardsProvider);
    ref.invalidate(reviewLogProvider);

    var newQueue = state.newQueue;
    if (phase == StudyPhase.newCards) {
      final seen = newQueue.sublist(0, state.newIndex + 1);
      var upcoming = newQueue.sublist(state.newIndex + 1);
      if (card.isNew) {
        // Introducing a card can unlock others (a root unlocks its words,
        // or a read-once card due after it), and those belong next in line
        // rather than in tomorrow's session. So the not-yet-introduced
        // part of the queue is asked for again; cards already waiting for
        // another go after "Again" keep their place at the end.
        upcoming = [
          ...await _fetchNewCards(),
          ...upcoming.where((queued) => !queued.isNew),
        ];
      }
      newQueue = [...seen, ...upcoming, if (requeue) updated];
    }

    state = state.copyWith(
      reviewQueue: phase == StudyPhase.review && requeue
          ? [...state.reviewQueue, updated]
          : state.reviewQueue,
      newQueue: newQueue,
      reviewIndex: phase == StudyPhase.review
          ? state.reviewIndex + 1
          : state.reviewIndex,
      newIndex: phase == StudyPhase.newCards
          ? state.newIndex + 1
          : state.newIndex,
      revealed: false,
      reviewedCount: state.reviewedCount + (counts ? 1 : 0),
    );
  }
}

final studySessionProvider =
    NotifierProvider<StudySessionNotifier, StudySessionState>(
      StudySessionNotifier.new,
    );
