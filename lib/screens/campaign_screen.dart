import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_providers.dart';
import '../theme/app_theme.dart';
import 'study_screen.dart';

/// The "Campaign" tab: makes sure every campaign is imported, then drops
/// straight into the global study session (due reviews first, then new
/// cards pulled from whichever campaign is current).
class CampaignScreen extends ConsumerWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(campaignDecksProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Could not load campaigns:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ),
        data: (_) => const StudySessionView(),
      ),
    );
  }
}
