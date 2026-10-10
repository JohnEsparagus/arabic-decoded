import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tts_providers.dart';
import '../theme/app_theme.dart';

/// A small speaker icon that reads [text] aloud. Takes up no space at all
/// when reading aloud isn't available (see [canSpeakProvider]).
class SpeakButton extends ConsumerWidget {
  const SpeakButton({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSpeakProvider)) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.volume_up_outlined),
      color: context.colors.deepGreen,
      tooltip: 'Listen',
      visualDensity: VisualDensity.compact,
      onPressed: () => ref.read(ttsServiceProvider).speak(text),
    );
  }
}
