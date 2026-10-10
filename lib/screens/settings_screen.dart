import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';

/// Reached via the cog icon in the app bar: night mode and learning
/// parameters (currently just the daily new-card cap). Both are backed by
/// persisted providers (see settings_providers.dart), so changes survive
/// app restarts and take effect immediately elsewhere in the app — no
/// "Save" button needed.
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
