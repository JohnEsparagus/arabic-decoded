import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import 'word_detail_screen.dart';

/// The "Dictionary" tab: every word across every deck, browsable by
/// default and filterable with basic Arabic-aware search (normalizeArabic
/// handles diacritics/alef-variant folding so spelling variants match).
/// Tapping a word opens its full flashcard back side ([WordDetailScreen]).
class DictionaryScreen extends ConsumerWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final entriesAsync = ref.watch(dictionaryEntriesProvider);
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث عن كلمة… (search Arabic or English)',
              prefixIcon: Icon(Icons.search, color: colors.inkMuted),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          ref.read(searchQueryProvider.notifier).set(''),
                    )
                  : null,
            ),
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).set(value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Could not load the dictionary:\n$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.inkMuted),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      query.trim().isEmpty
                          ? 'No words yet — visit Home to add some.'
                          : 'No matches for "$query".',
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _DictionaryEntryCard(card: entries[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DictionaryEntryCard extends StatelessWidget {
  const _DictionaryEntryCard({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => WordDetailScreen(card: card))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.arabicWord,
                      textDirection: TextDirection.rtl,
                      style: arabicTextStyle(fontSize: 22, color: colors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.englishTranslation,
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
