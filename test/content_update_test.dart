import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arabic_decoded/config/campaign_sources.dart';
import 'package:arabic_decoded/models/content_manifest.dart';
import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/repositories/local_flashcard_repository.dart';
import 'package:arabic_decoded/services/content_importer.dart';
import 'package:arabic_decoded/services/content_store.dart';
import 'package:arabic_decoded/services/content_updater.dart';
import 'package:arabic_decoded/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _newCampaign = 'assets/data/campaign_21_test.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bundledManifest = File(contentManifestPath).readAsStringSync();
  late DatabaseService db;
  late ContentStore store;

  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  /// A published update adding one campaign, as [ContentUpdater] would
  /// find it online, with a way to tamper with what's served.
  Map<String, Uint8List> published({
    String campaign = '[{"arabic": "ر ق ب", "meaning": "Watching"}]',
    int versionBump = 1,
    int? schema,
  }) {
    final manifest = json.decode(bundledManifest) as Map<String, dynamic>;
    manifest['version'] = (manifest['version'] as int) + versionBump;
    if (schema != null) manifest['schema'] = schema;
    manifest['campaigns'].add({'file': _newCampaign, 'deck': 'Test Campaign'});
    manifest['files'][_newCampaign] = contentHash(utf8.encode(campaign));
    return {
      contentManifestPath: bytes(json.encode(manifest)),
      _newCampaign: bytes(campaign),
    };
  }

  ContentUpdater updaterFor(Map<String, Uint8List> site) => ContentUpdater(
    db,
    store,
    fetch: (url) async =>
        site[url.path.replaceFirst('/arabic-decoded/assets/', '')],
  );

  setUp(() {
    db = DatabaseService(pathOverride: inMemoryDatabasePath);
    store = ContentStore(db, loadBundled: (p) => File(p).readAsString());
  });

  /// What the next launch does: a fresh read of whatever is stored.
  Future<List<Flashcard>> relaunch() async {
    store = ContentStore(db, loadBundled: (p) => File(p).readAsString());
    await ContentImporter(
      LocalFlashcardRepository(db),
      loadAsset: store.load,
    ).importAll();
    return db.getAllFlashcards();
  }

  test('the manifest is up to date (run tool/build_manifest.py if not)', () {
    final manifest = ContentManifest.parse(bundledManifest);
    for (final MapEntry(key: path, value: hash) in manifest.files.entries) {
      expect(contentHash(File(path).readAsBytesSync()), hash, reason: path);
    }
    final onDisk = Directory('assets/data')
        .listSync()
        .map((file) => file.path)
        .where((path) => path.endsWith('.json'))
        .where(
          (path) => ![
            'manifest.json',
            'dev_updates.json',
            'campaign.json',
          ].any(path.endsWith),
        );
    expect(manifest.files.keys, unorderedEquals(onDisk));
    expect(manifest.schema, lessThanOrEqualTo(contentSchema));
  });

  test('a published campaign arrives without an app update, keeping '
      'progress', () async {
    var cards = await relaunch();
    final root = cards.singleWhere((c) => c.arabicWord == 'ك ت ب');
    await db.updateFlashcard(root.copyWith(isNew: false, interval: 12));

    expect(await updaterFor(published()).check(), isTrue);
    cards = await relaunch();

    expect(cards.where((c) => c.arabicWord == 'ر ق ب'), hasLength(1));
    final kept = cards.singleWhere((c) => c.arabicWord == 'ك ت ب');
    expect(kept.id, root.id);
    expect(kept.interval, 12);
  });

  test('nothing is fetched beyond the manifest when up to date', () async {
    final asked = <String>[];
    final updater = ContentUpdater(
      db,
      store,
      fetch: (url) async {
        asked.add(url.path);
        return bytes(bundledManifest);
      },
    );
    expect(await updater.check(), isFalse);
    expect(asked, hasLength(1));
  });

  test('a file that does not match its hash changes nothing', () async {
    final site = published();
    site[_newCampaign] = bytes('[{"arabic": "tampered"}]');
    expect(await updaterFor(site).check(), isFalse);
    expect(await db.getContentFile(contentManifestPath), isNull);
  });

  test('a file that is not a list of entries changes nothing', () async {
    final site = published(campaign: '{"not": "a list"}');
    expect(await updaterFor(site).check(), isFalse);
    expect(await db.getContentFile(contentManifestPath), isNull);
  });

  test('a file that fails to download changes nothing', () async {
    final site = published()..remove(_newCampaign);
    expect(await updaterFor(site).check(), isFalse);
    expect(await db.getContentFile(contentManifestPath), isNull);
  });

  test('being offline is not an error', () async {
    final updater = ContentUpdater(
      db,
      store,
      fetch: (_) => throw const SocketException('offline'),
    );
    expect(await updater.check(), isFalse);
  });

  test('content in a newer format than the app understands is left '
      'alone', () async {
    final site = published(schema: contentSchema + 1);
    expect(await updaterFor(site).check(), isFalse);
  });

  test('a newer app update takes over from older downloaded content', () async {
    await updaterFor(published()).check();
    expect(
      (await ContentStore(
        db,
        loadBundled: (p) => File(p).readAsString(),
      ).manifest).campaigns.last.deckName,
      'Test Campaign',
    );

    // The next store release ships a later version than that download.
    final newer = jsonDecode(bundledManifest) as Map<String, dynamic>;
    newer['version'] = (newer['version'] as int) + 5;
    final updatedApp = ContentStore(
      db,
      loadBundled: (p) async => p == contentManifestPath
          ? json.encode(newer)
          : File(p).readAsString(),
    );
    expect((await updatedApp.manifest).version, newer['version']);
    expect(
      (await updatedApp.manifest).campaigns.map((c) => c.deckName),
      isNot(contains('Test Campaign')),
    );
  });

  test('reset goes back to the bundled content', () async {
    await updaterFor(published()).check();
    await store.reset();
    final cards = await relaunch();
    expect(cards.where((c) => c.arabicWord == 'ر ق ب'), isEmpty);
  });
}
