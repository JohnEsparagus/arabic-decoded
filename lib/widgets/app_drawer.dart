import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_info.dart';
import '../providers/auth_providers.dart';
import '../screens/about_screen.dart';
import '../screens/account_screen.dart';
import '../screens/sentences_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/updates_screen.dart';
import '../theme/app_theme.dart';

/// The sidebar that slides out from the top-left menu button: the account
/// at the top, then learning stats, sentences, settings, About and the
/// update log.
/// Everything that isn't one of the three study tabs lives here.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    // Closes the sidebar first, so coming back lands on the tab the user
    // left rather than on an open sidebar.
    void open(Widget screen) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      backgroundColor: colors.parchment,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccountHeader(onTap: () => open(const AccountScreen())),
            Divider(height: 1, color: colors.cardBorder),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.insights_outlined,
              label: 'Learning stats',
              onTap: () => open(const StatsScreen()),
            ),
            _DrawerItem(
              icon: Icons.short_text,
              label: 'Sentences',
              onTap: () => open(const SentencesScreen()),
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => open(const SettingsScreen()),
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => open(const AboutScreen()),
            ),
            _DrawerItem(
              icon: Icons.campaign_outlined,
              label: 'Dev updates',
              onTap: () => open(const UpdatesScreen()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '$appName $appVersion',
                style: TextStyle(color: colors.inkMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who's signed in, or an invitation to. Opens the account page.
class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final email = ref.watch(currentUserProvider)?.email;
    final signedIn = ref.watch(currentUserIdProvider) != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 12, 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.deepGreen.withValues(alpha: 0.14),
              foregroundColor: colors.deepGreen,
              child: email != null && email.isNotEmpty
                  ? Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : const Icon(Icons.person_outline),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? (email ?? 'Signed in') : 'Account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    signedIn
                        ? 'Progress syncs to your account'
                        : 'Sign in to back up your progress',
                    style: TextStyle(color: colors.inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: colors.deepGreen),
      title: Text(label, style: TextStyle(color: colors.ink)),
      onTap: onTap,
    );
  }
}
