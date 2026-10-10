import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/welcome_card.dart';
import 'study_screen.dart';

/// The "Campaign" tab: makes sure every campaign is imported, greets the
/// user with a [WelcomeCard] summing up what's due and how far along they
/// are, then drops into the global study session (due reviews first, then
/// new cards pulled from whichever campaign is current).
///
/// The welcome is shown once per launch: [_started] lives in this widget's
/// state, which [RootShell]'s IndexedStack keeps alive across tab switches.
class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(campaignDecksProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Could not load campaigns:\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.inkMuted),
          ),
        ),
        data: (_) => _started
            ? const StudySessionView()
            : WelcomeCard(onStart: () => setState(() => _started = true)),
      ),
    );
  }
}
