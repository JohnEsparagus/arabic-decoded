import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// The app's Supabase client, or null when there isn't one. `main()`
/// overrides this with the real client after `Supabase.initialize`;
/// anything that doesn't (i.e. tests) gets null, which every provider
/// below treats as "permanently signed out" — so the rest of the app runs
/// exactly as it did before accounts existed, with no network involved.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});

/// Emits the signed-in user (or null) now and again on every sign-in,
/// sign-out and token refresh.
final _authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange.map((state) => state.session?.user);
});

/// Who's signed in right now, or null. Supabase restores a saved session
/// during `Supabase.initialize`, so this is already correct on the very
/// first frame — there's no "loading" state to handle.
final currentUserProvider = Provider<User?>((ref) {
  final fromStream = ref.watch(_authStateProvider);
  if (fromStream.hasValue) return fromStream.value;
  return ref.watch(supabaseClientProvider)?.auth.currentUser;
});

/// Just the signed-in user's id. Split out from [currentUserProvider] so
/// the things that only care *who* is signed in (the repository, sync)
/// aren't rebuilt every time a token refresh hands back a new [User]
/// object for the same person.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider.select((user) => user?.id));
});
