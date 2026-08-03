import 'package:flutter/material.dart';

import '../widgets/pattern_divider.dart';
import 'campaign_screen.dart';
import 'campaigns_browser_screen.dart';
import 'dictionary_screen.dart';

/// The app's top-level scaffold: a shared app bar + a 3-tab bottom
/// navigation bar (Campaign / Dictionary / Campaigns). Tabs are kept in an
/// [IndexedStack] so switching between them doesn't reset an in-progress
/// study session or a typed search query.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _titles = ['Campaign', 'Dictionary', 'Campaigns'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
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
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Campaign',
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
