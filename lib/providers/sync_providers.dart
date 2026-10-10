import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/progress_remote.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';
import 'database_providers.dart';
import 'settings_providers.dart';
import 'study_session_provider.dart';

/// The signed-in user's [SyncService], or null while signed out. Rebuilt
/// (for the new user) whenever a different account signs in.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return null;
  return SyncService(
    db: ref.watch(databaseServiceProvider),
    remote: SupabaseProgressRemote(client, userId: userId),
    prefs: ref.watch(sharedPreferencesProvider),
    userId: userId,
  );
});

/// What the Settings screen shows under the account: whether a sync is
/// running, when the last one succeeded, and what went wrong if it didn't.
class SyncState {
  final bool syncing;
  final DateTime? lastSyncedAt;
  final Object? error;

  const SyncState({this.syncing = false, this.lastSyncedAt, this.error});
}

/// Runs sync and tracks how it went. Signing in is itself what kicks off
/// the first sync — [build] re-runs whenever [syncServiceProvider] hands
/// back a service for a new user — and the root shell keeps this provider
/// alive and calls [sync] again each time the app comes back to the
/// foreground (see `root_shell.dart`).
///
/// A failed sync is never an error the user has to deal with: the changes
/// are still saved locally and still flagged for upload, so the next
/// attempt just picks them up.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    if (ref.watch(syncServiceProvider) != null) Future.microtask(sync);
    return const SyncState();
  }

  /// Full two-way sync.
  Future<void> sync() => _run((service) async {
    // Progress for a card that hasn't been imported yet has nowhere to
    // land, so let the first-launch import finish before pulling.
    await ref.read(campaignDecksProvider.future);
    return service.sync();
  });

  /// Upload only — what [SyncedFlashcardRepository] triggers after each
  /// graded card.
  Future<void> push() => _run((service) async {
    await service.push();
    return 0;
  });

  Future<void> _run(Future<int> Function(SyncService service) action) async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return;

    state = SyncState(syncing: true, lastSyncedAt: state.lastSyncedAt);
    try {
      final changed = await action(service);
      if (!ref.mounted) return;
      state = SyncState(lastSyncedAt: DateTime.now());
      // Progress arrived from another device.
      if (changed > 0) _refreshCards();
    } catch (error) {
      if (!ref.mounted) return;
      state = SyncState(lastSyncedAt: state.lastSyncedAt, error: error);
    }
  }

  /// Puts this device back to a blank slate: every card never-studied,
  /// and no account associated with it. The last step of deleting an
  /// account — "delete everything" should include the copy sitting here.
  Future<void> forgetLocalProgress() async {
    await ref.read(databaseServiceProvider).clearProgress();
    await SyncService.forgetOwner(ref.read(sharedPreferencesProvider));
    if (ref.mounted) _refreshCards();
  }

  /// Everything that caches flashcards needs to re-read them once their
  /// progress has changed underneath it, including the study queue.
  void _refreshCards() {
    ref.invalidate(deckFlashcardsProvider);
    ref.invalidate(dictionaryEntriesProvider);
    ref.invalidate(allFlashcardsProvider);
    ref.invalidate(reviewLogProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionFlashcardsProvider);
    ref.invalidate(cardCollectionIdsProvider);
    ref.invalidate(studySessionProvider);
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);
