import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/campaign_sources.dart';
import '../models/content_manifest.dart';
import 'content_store.dart';
import 'database_service.dart';

/// Fetches newer content, so roots, lessons and sentences can be added
/// without a store update. Publishing is a push: the web app's deploy puts
/// the manifest and the content files online.
///
/// Everything is checked before anything is saved, and saved in one go, so
/// a bad file or a dropped connection leaves the current content as it
/// was. New content takes effect on the next launch rather than changing
/// the cards under someone mid-session.
class ContentUpdater {
  ContentUpdater(
    this._db,
    this._store, {
    Future<Uint8List?> Function(Uri)? fetch,
  }) : _fetch = fetch ?? _get;

  final DatabaseService _db;
  final ContentStore _store;
  final Future<Uint8List?> Function(Uri url) _fetch;

  /// Downloads any newer content and returns whether there was some. Never
  /// throws: being offline, or anything else going wrong, just means
  /// trying again next time.
  Future<bool> check() async {
    try {
      // The query string gets past any cached copy of the manifest.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final manifestBytes = await _fetch(
        Uri.parse('$contentBaseUrl$contentManifestPath?t=$stamp'),
      );
      if (manifestBytes == null) return false;
      final manifestText = utf8.decode(manifestBytes);
      final remote = ContentManifest.parse(manifestText);
      final current = await _store.manifest;
      if (remote.schema > contentSchema) return false;
      if (remote.version <= current.version) return false;

      final downloads = <String, ({String hash, String body})>{
        contentManifestPath: (hash: '', body: manifestText),
      };
      for (final MapEntry(key: path, value: hash) in remote.files.entries) {
        if (current.files[path] == hash) continue;
        final bytes = await _fetch(Uri.parse('$contentBaseUrl$path?v=$hash'));
        if (bytes == null || !_isValid(bytes, hash)) return false;
        downloads[path] = (hash: hash, body: utf8.decode(bytes));
      }
      await _db.saveContentFiles(downloads);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A content file is valid if it's exactly what the manifest says it is,
  /// and is a list of entries.
  static bool _isValid(Uint8List bytes, String hash) {
    if (contentHash(bytes) != hash) return false;
    final decoded = json.decode(utf8.decode(bytes));
    return decoded is List && decoded.every((entry) => entry is Map);
  }

  static Future<Uint8List?> _get(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 30));
    return response.statusCode == 200 ? response.bodyBytes : null;
  }
}

/// A content file's hash, as `tool/build_manifest.py` computes it.
String contentHash(List<int> bytes) =>
    sha256.convert(bytes).toString().substring(0, 16);
