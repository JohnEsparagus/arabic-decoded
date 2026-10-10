import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dev_update.dart';
import '../theme/app_theme.dart';
import '../utils/date_labels.dart';
import '../widgets/pattern_divider.dart';

/// The update log, as written in assets/data/dev_updates.json.
final devUpdatesProvider = FutureProvider<List<DevUpdate>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/dev_updates.json');
  return (json.decode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(DevUpdate.fromJson)
      .toList();
});

/// Reached from the sidebar: what's changed in the app, newest first.
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final updates = ref.watch(devUpdatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dev updates')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: updates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    'Could not load the updates.',
                    style: TextStyle(color: colors.inkMuted),
                  ),
                ),
                data: (updates) => ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: updates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _UpdateCard(update: updates[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});

  final DevUpdate update;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullDate(update.date),
              style: TextStyle(color: colors.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(update.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final change in update.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✦  ', style: TextStyle(color: colors.gold)),
                    Expanded(
                      child: Text(
                        change,
                        style: TextStyle(color: colors.ink, height: 1.35),
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
