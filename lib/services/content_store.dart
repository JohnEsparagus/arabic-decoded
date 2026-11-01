import 'package:flutter/services.dart' show rootBundle;

import '../config/campaign_sources.dart';
import '../models/content_manifest.dart';
import 'database_service.dart';

/// Where content files are read from: a newer downloaded copy if there is
/// one, otherwise the copy bundled with the app. That bundled copy is why
/// a first launch needs no network, and it's what the app falls back on.
class ContentStore {
  ContentStore(this._db, {Future<String> Function(String)? loadBundled})
    : _loadBundled = loadBundled ?? rootBundle.loadString;

  final DatabaseService _db;
  final Future<String> Function(String path) _loadBundled;
  Future<({ContentManifest manifest, String text})>? _active;

  /// The manifest in use: the downloaded one, unless the app itself has
  /// since been updated to something at least as new.
  Future<ContentManifest> get manifest async => (await _resolve()).manifest;

  Future<({ContentManifest manifest, String text})> _resolve() {
    return _active ??= () async {
      final bundledText = await _loadBundled(contentManifestPath);
      final bundled = ContentManifest.parse(bundledText);
      final stored = await _db.getContentFile(contentManifestPath);
      if (stored != null) {
        final downloaded = ContentManifest.parse(stored.body);
        if (downloaded.version > bundled.version) {
          return (manifest: downloaded, text: stored.body);
        }
      }
      return (manifest: bundled, text: bundledText);
    }();
  }

  /// The text of a content file, as the active manifest describes it.
  Future<String> load(String path) async {
    final active = await _resolve();
    if (path == contentManifestPath) return active.text;
    final stored = await _db.getContentFile(path);
    if (stored != null && stored.hash == active.manifest.files[path]) {
      return stored.body;
    }
    return _loadBundled(path);
  }

  /// Drops everything downloaded and goes back to the bundled content.
  Future<void> reset() async {
    await _db.clearContentFiles();
    _active = null;
  }
}
