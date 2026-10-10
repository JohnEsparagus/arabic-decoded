import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Whether the device is on Wi-Fi, mobile data or any other network right
/// now, kept up to date as that changes.
final onlineProvider = StreamProvider<bool>((ref) async* {
  bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  final connectivity = Connectivity();
  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});

/// Whether to offer reading aloud at all: only on a platform that has a
/// speech engine, and only while there's a connection. Anything that shows
/// a speaker button watches this and hides the button when it's false.
final canSpeakProvider = Provider<bool>((ref) {
  if (!TtsService.isSupported) return false;
  return ref.watch(onlineProvider).asData?.value ?? false;
});
