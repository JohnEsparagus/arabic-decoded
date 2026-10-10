import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/pattern_divider.dart';
import 'campaign_screen.dart';
import 'campaigns_browser_screen.dart';
import 'dictionary_screen.dart';

/// The app's top-level scaffold: a shared app bar + a 3-tab bottom
/// navigation bar (Home / Dictionary / Campaigns), with everything else
/// (account, stats, settings, About, updates) in the [AppDrawer] behind
/// the menu button at the top left. Tabs are kept in an
/// [IndexedStack] so switching between them doesn't reset an in-progress
/// study session or a typed search query.
///
/// Also where background sync is anchored, since this widget lives for as
/// long as the app does: it keeps [syncProvider] alive (which syncs on
/// launch and on sign-in) and syncs again whenever the app returns to the
/// foreground, to pick up anything studied on another device meanwhile.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  static const _titles = ['Home', 'Dictionary', 'Campaigns'];

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(syncProvider.notifier).sync(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `listen` rather than `watch`: this only needs the provider kept
    // alive, not a rebuild of the whole shell on every sync.
    ref.listen(syncProvider, (_, _) {});
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  CampaignScreen(),
                  DictionaryScreen(),
                  CampaignsBrowserScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Campaigns',
          ),
        ],
      ),
    );
  }
}
