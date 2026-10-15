import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// Reads Arabic text aloud with the device's own text-to-speech engine,
/// through `flutter_tts`. A thin wrapper so the rest of the app doesn't
/// depend on the plugin, and so a different voice (a cloud one, say) could
/// be swapped in here without touching any screen.
class TtsService {
  FlutterTts? _tts;

  /// `flutter_tts` has no Linux implementation. In a browser it uses the
  /// browser's own speech (the Web Speech API).
  static bool get isSupported => kIsWeb || !Platform.isLinux;

  /// Speaks [text], cutting off anything still being read. A device with
  /// no Arabic voice just stays silent rather than throwing.
  Future<void> speak(String text) async {
    if (!isSupported) return;
    try {
      var tts = _tts;
      if (tts == null) {
        tts = _tts = FlutterTts();
        await tts.setLanguage('ar');
        // A little under normal speed: these are words being learned.
        await tts.setSpeechRate(0.4);
      }
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // No engine or no voice: nothing useful to tell the user mid-study.
    }
  }

  Future<void> dispose() async => _tts?.stop();
}
