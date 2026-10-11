import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sentence_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';
import '../widgets/sentence_text.dart';
import '../widgets/sentence_tile.dart';

/// Reached from the sidebar: the sentence explorer. The whole corpus,
/// searchable in Arabic or English, with every word the user is studying
/// underlined in the colour of how well they know it.
///
/// Sentences never come up by themselves; the + on a row puts that one in
/// the study queue (tap it again to take it back out). After that it's a
/// card like any other.
///
/// Built for a corpus of thousands: rows are fetched a page at a time as
/// the list is scrolled, and only the rows on screen are ever built.
class SentencesScreen extends ConsumerStatefulWidget {
  const SentencesScreen({super.key});

  @override
  ConsumerState<SentencesScreen> createState() => _SentencesScreenState();
}

class _SentencesScreenState extends ConsumerState<SentencesScreen> {
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Asks for the next page a screenful or so before the end is reached,
  /// so it's usually there by the time it's scrolled to.
  void _loadMoreNearEnd() {
    if (_scroll.position.extentAfter < 600) {
      ref.read(sentenceExplorerProvider.notifier).loadMore();
    }
  }

  /// Searches once typing pauses, not on every keystroke.
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(sentenceExplorerProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final explorer = ref.watch(sentenceExplorerProvider);
    final sentences = explorer.sentences;

    return Scaffold(
      appBar: AppBar(title: const Text('Sentences')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Arabic or English',
                  prefixIcon: Icon(Icons.search, color: colors.inkMuted),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  const Expanded(child: MasteryLegend()),
                  Text(
                    '${explorer.total} sentences',
                    style: TextStyle(color: colors.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sentences.isEmpty
                  ? Center(
                      child: explorer.loading
                          ? const CircularProgressIndicator()
                          : Text(
                              explorer.query.trim().isEmpty
                                  ? 'No sentences yet.'
                                  : 'No matches for "${explorer.query}".',
                              style: TextStyle(color: colors.inkMuted),
                            ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: sentences.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          SentenceTile(sentence: sentences[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
