import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';
import 'study_screen.dart';

/// Goes through a fixed set of cards (a collection) as flip cards, as many
/// times as the user likes. This is practice on the side: nothing here is
/// graded, so it never moves a card's place in the spaced-repetition
/// schedule. "Again" just sends the card to the back of this run.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.title, required this.cards});

  final String title;
  final List<Flashcard> cards;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late List<Flashcard> _queue = [...widget.cards];
  int _index = 0;
  bool _revealed = false;

  void _next({required bool again}) {
    setState(() {
      if (again) _queue.add(_queue[_index]);
      _index++;
      _revealed = false;
    });
  }

  void _restart() {
    setState(() {
      _queue = [...widget.cards];
      _index = 0;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: done ? _finished(colors) : _card(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(AppColors colors) {
    final card = _queue[_index];
    return Column(
      children: [
        Text(
          'Practice · ${_queue.length - _index} to go',
          style: TextStyle(color: colors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _revealed = !_revealed),
            child: FlipCard(
              // Its own key per position, so a card sent round again
              // starts face-up-front instead of mid-flip.
              key: ValueKey(_index),
              card: card,
              revealed: _revealed,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_revealed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _revealed = true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Show answer'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _next(again: true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _next(again: false),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _finished(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: colors.deepGreen, size: 64),
          const SizedBox(height: 16),
          Text(
            'That\'s all of them.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _restart,
            child: const Text('Go through them again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
