import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_progress.dart';

/// Where one signed-in user's progress lives off-device. Kept behind an
/// interface so `SyncService` can be tested against an in-memory fake
/// instead of a real backend.
abstract class ProgressRemote {
  /// Every card the user has progress for.
  Future<List<CardProgress>> fetchAll();

  /// Inserts or overwrites [progress], keyed by deck name + Arabic word.
  Future<void> upsert(List<CardProgress> progress);
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
}
