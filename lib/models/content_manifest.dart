import 'dart:convert';

import '../config/campaign_sources.dart';

/// What content exists: assets/data/manifest.json. It lists the campaigns
/// in order, the cards that have been renamed, and a hash of every content
/// file. A copy ships inside the app, and the same file is published
/// online, so content can change without a store update (see
/// `ContentUpdater`). `tool/build_manifest.py` keeps it up to date.
class ContentManifest {
  const ContentManifest({
    required this.schema,
    required this.version,
    required this.campaigns,
    required this.moves,
    required this.files,
  });

  /// The content format. An app only takes content whose schema it
  /// understands (see [contentSchema]).
  final int schema;

  /// Goes up with every content change; the highest wins.
  final int version;
  final List<CampaignSource> campaigns;
  final List<ContentMove> moves;

  /// Content file path to the hash of its contents.
  final Map<String, String> files;

  factory ContentManifest.parse(String text) {
    final map = json.decode(text) as Map<String, dynamic>;
    return ContentManifest(
      schema: map['schema'] as int,
      version: map['version'] as int,
      campaigns: [
        for (final campaign in map['campaigns'] as List)
          CampaignSource(
            assetPath: campaign['file'] as String,
            deckName: campaign['deck'] as String,
            description: campaign['description'] as String?,
          ),
      ],
      moves: [
        for (final move in (map['moves'] as List).cast<List>())
          ContentMove(
            move[0] as String,
            move[1] as String,
            move[2] as String,
            move[3] as String,
          ),
      ],
      files: (map['files'] as Map).cast<String, String>(),
    );
  }
}
