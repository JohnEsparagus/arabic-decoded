import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_progress.dart';
import '../models/synced_extras.dart';

/// Where one signed-in user's progress lives off-device. Kept behind an
/// interface so `SyncService` can be tested against an in-memory fake
/// instead of a real backend.
abstract class ProgressRemote {
  /// Every card the user has progress for.
  Future<List<CardProgress>> fetchAll();

  /// Inserts or overwrites [progress], keyed by deck name + Arabic word.
  Future<void> upsert(List<CardProgress> progress);

  /// The user's review-log entries with a server id above [afterId],
  /// lowest id first, at most [limit] of them. Each one's
  /// [SyncedReview.id] is that server id.
  Future<List<SyncedReview>> fetchReviews({
    required int afterId,
    required int limit,
  });

  /// Adds [reviews] to the user's review log. Ones already there (same
  /// card, same moment) are ignored.
  Future<void> addReviews(List<SyncedReview> reviews);

  /// The user's favorites and collections, or null if they've never
  /// uploaded any.
  Future<LibrarySnapshot?> fetchLibrary();

  /// Replaces the user's library with [library], unless what's stored is
  /// newer.
  Future<void> upsertLibrary(LibrarySnapshot library);
}

/// Backs [ProgressRemote] with the `card_progress` table (see
/// `supabase/migrations/`). Row-level security there already limits every
/// query to the signed-in user's own rows; [userId] is still sent
/// explicitly so a mismatch fails loudly instead of quietly writing
/// nothing.
class SupabaseProgressRemote implements ProgressRemote {
  SupabaseProgressRemote(this._client, {required this.userId});

  final SupabaseClient _client;
  final String userId;

  static const _table = 'card_progress';

  @override
  Future<List<CardProgress>> fetchAll() async {
    // Always the whole table rather than "changed since last sync": it's
    // at most one small row per card, and a since-timestamp cursor would
    // miss rows written by a device whose clock runs behind.
    final rows = await _client.from(_table).select().eq('user_id', userId);
    return rows.map(CardProgress.fromRemote).toList();
  }

  @override
  Future<void> upsert(List<CardProgress> progress) async {
    if (progress.isEmpty) return;
    await _client
        .from(_table)
        .upsert(
          progress.map((p) => p.toRemote(userId: userId)).toList(),
          onConflict: 'user_id,deck_name,arabic_word',
        );
  }

  @override
  Future<List<SyncedReview>> fetchReviews({
    required int afterId,
    required int limit,
  }) async {
    final rows = await _client
        .from('review_log')
        .select()
        .eq('user_id', userId)
        .gt('id', afterId)
        .order('id', ascending: true)
        .limit(limit);
    return rows.map(SyncedReview.fromRemote).toList();
  }

  @override
  Future<void> addReviews(List<SyncedReview> reviews) async {
    if (reviews.isEmpty) return;
    await _client
        .from('review_log')
        .upsert(
          reviews.map((r) => r.toRemote(userId: userId)).toList(),
          onConflict: 'user_id,deck_name,arabic_word,reviewed_at',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<LibrarySnapshot?> fetchLibrary() async {
    final row = await _client
        .from('user_library')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : LibrarySnapshot.fromRemote(row);
  }

  @override
  Future<void> upsertLibrary(LibrarySnapshot library) async {
    await _client
        .from('user_library')
        .upsert(library.toRemote(userId: userId), onConflict: 'user_id');
  }
}
