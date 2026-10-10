import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';
import 'sign_in_screen.dart';

/// Reached from the top of the sidebar: who's signed in and how sync is
/// doing, or the way in if nobody is.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // No backend configured (only the case in tests): there's
                  // nothing to sign in to, so don't offer it.
                  if (ref.watch(authServiceProvider) == null)
                    Text(
                      'Accounts aren\'t available in this build. Your '
                      'progress is saved on this device.',
                      style: TextStyle(color: colors.inkMuted),
                    )
                  else ...[
                    const AccountCard(),
                    const SizedBox(height: 16),
                    Text(
                      'An account is optional. It backs up your progress '
                      'and keeps it in step across your devices. Favorites '
                      'and collections stay on this device.',
                      style: TextStyle(color: colors.inkMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signed out: an invitation to sign in. Signed in: who you are, how sync
/// is doing, and the two things you can do about it.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          leading: Icon(Icons.cloud_off_outlined, color: colors.deepGreen),
          title: const Text('Sign in'),
          subtitle: const Text(
            'Save your progress and pick it up on any device',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
        ),
      );
    }

    final sync = ref.watch(syncProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle_outlined, color: colors.deepGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.email ?? 'Signed in',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _syncSummary(sync),
              style: TextStyle(color: colors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: sync.syncing
                      ? null
                      : () => ref.read(syncProvider.notifier).sync(),
                  child: const Text('Sync now'),
                ),
                TextButton(
                  onPressed: () => _signOut(ref),
                  child: const Text('Sign out'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmAndDeleteAccount(context, ref),
                child: Text(
                  'Delete account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _syncSummary(SyncState sync) {
    if (sync.syncing) return 'Syncing…';
    if (sync.error != null) {
      return 'Couldn\'t sync just now. Your progress is saved on this '
          'device and will upload next time.';
    }
    final last = sync.lastSyncedAt;
    if (last == null) return 'Progress syncs to your account';
    final time = TimeOfDay.fromDateTime(last);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return 'Progress synced at $hh:$mm';
  }

  /// Uploads anything still waiting before signing out, so the account is
  /// up to date for wherever they sign in next. Best effort: if that
  /// fails (e.g. offline) the changes stay on this device and go up when
  /// the same account signs back in here.
  Future<void> _signOut(WidgetRef ref) async {
    final auth = ref.read(authServiceProvider);
    await ref.read(syncProvider.notifier).push();
    await auth?.signOut();
  }

  Future<void> _confirmAndDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and all of your progress, '
          'on this device and everywhere else. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authServiceProvider);
    final sync = ref.read(syncProvider.notifier);
    try {
      // Server first: if that fails, nothing here has been touched and
      // they can simply try again.
      await auth?.deleteAccount();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t delete your account. Check your connection and try '
            'again.',
          ),
        ),
      );
      return;
    }
    await sync.forgetLocalProgress();
    await auth?.signOut();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
  }
}
