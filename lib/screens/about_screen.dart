import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';

/// Reached from the sidebar: what the app is and how it teaches, its
/// version, and the licences of what it's built with.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = TextStyle(
      color: colors.ink,
      height: 1.45,
      fontFamilyFallback: arabicFallback(context),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'ج ذ ر',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: arabicTextStyle(
                      context,
                      fontSize: 40,
                      color: colors.gold,
                    ),
                  ),
                  Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $appVersion',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  Text(appTagline, style: body),
                  const SizedBox(height: 16),
                  Text(
                    'Most Arabic words grow out of a root of three letters '
                    'that carries a core idea. Know the root and a whole '
                    'family of words stops being new: ك ت ب is about '
                    'writing, and from it come book, writer, library and '
                    'office.',
                    style: body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Roots are taught in themed campaigns and brought back '
                    'for review just before you would forget them. The '
                    'words built from the roots you know are there when you '
                    'want them.',
                    style: body,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Arabic text is set in Amiri, Scheherazade New, Noto Naskh '
                    'Arabic or Noto Kufi Arabic, whichever you choose in '
                    'Settings. All four are used under the SIL Open Font '
                    'License.',
                    style: TextStyle(color: colors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Most of the sentences in the sentence explorer come '
                    'from Tatoeba (tatoeba.org), a collection of sentences '
                    'and translations written by volunteers, used under the '
                    'Creative Commons Attribution 2.0 France licence.',
                    style: TextStyle(color: colors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: appName,
                        applicationVersion: appVersion,
                      ),
                      child: const Text('Open-source licences'),
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
