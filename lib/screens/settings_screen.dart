import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';
import 'sign_in_screen.dart';

/// Reached via the cog icon in the app bar: the account (sign in / sync /
/// sign out), night mode and learning parameters (currently just the
/// daily new-card cap). The last two are backed by persisted providers
/// (see settings_providers.dart), so changes survive app restarts and
/// take effect immediately elsewhere in the app — no "Save" button needed.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isDarkMode = ref.watch(darkModeProvider);
    final maxNewCardsPerDay = ref.watch(maxNewCardsPerDayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                  if (ref.watch(authServiceProvider) != null) ...[
                    _SectionLabel('Account'),
                    const SizedBox(height: 8),
                    const _AccountCard(),
                    const SizedBox(height: 28),
                  ],
                  _SectionLabel('Appearance'),
                  const SizedBox(height: 8),
                  Card(
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      title: const Text('Night mode'),
                      subtitle: const Text(
                        'Switch to a dark, low-light palette',
                      ),
                      secondary: Icon(
                        isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode_outlined,
                        color: colors.deepGreen,
                      ),
                      value: isDarkMode,
                      onChanged: (value) =>
                          ref.read(darkModeProvider.notifier).set(value),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Learning'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.style_outlined,
                                color: colors.deepGreen,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'New cards per day',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'How many never-studied roots can be introduced '
                            'per day, across every campaign combined.',
                            style: TextStyle(
                              color: colors.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _NewCardsPerDayControl(
                            value: maxNewCardsPerDay,
                            onChanged: (value) => ref
                                .read(maxNewCardsPerDayProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                    ),
                  ),
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
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: context.colors.inkMuted,
      ),
    );
  }
}

/// A big current-value readout plus a slider (for coarse changes across the
/// whole 0-100 range) and quick-pick chips (for the values most people
/// actually want), instead of a bare +/- stepper that would take dozens of
/// taps to move any real distance.
class _NewCardsPerDayControl extends StatelessWidget {
  const _NewCardsPerDayControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _presets = [5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        Text(
          value == 1 ? 'new card a day' : 'new cards a day',
          style: TextStyle(fontSize: 13, color: colors.inkMuted),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.deepGreen,
            thumbColor: colors.deepGreen,
            inactiveTrackColor: colors.cardBorder,
            overlayColor: colors.deepGreen.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value.toDouble(),
            min: minNewCardsPerDay.toDouble(),
            max: maxNewCardsPerDayLimit.toDouble(),
            divisions: maxNewCardsPerDayLimit - minNewCardsPerDay,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: _presets.map((preset) {
            final selected = value == preset;
            return ChoiceChip(
              label: Text('$preset'),
              selected: selected,
              onSelected: (_) => onChanged(preset),
              selectedColor: colors.deepGreen.withValues(alpha: 0.2),
              backgroundColor: colors.cardSurface,
              side: BorderSide(
                color: selected ? colors.deepGreen : colors.cardBorder,
              ),
              labelStyle: TextStyle(
                color: selected ? colors.deepGreen : colors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
