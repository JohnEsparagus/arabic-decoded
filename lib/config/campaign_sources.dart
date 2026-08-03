/// One entry per campaign JSON asset (see `assets/data/`). This is the only
/// place that needs editing to add a new campaign — drop a new JSON file
/// (same shape as campaign.json) into `assets/data/`, add one entry here,
/// and it's imported into its own deck automatically on next launch.
///
/// List order matters: it's also campaign progression order — new cards
/// are introduced from earlier campaigns first, and only move on to the
/// next campaign once the current one runs out of new cards (see
/// `DatabaseService.getNewFlashcards`).
class CampaignSource {
  const CampaignSource({
    required this.assetPath,
    required this.deckName,
    this.description,
  });

  final String assetPath;
  final String deckName;
  final String? description;
}

const campaignSources = [
  CampaignSource(
    assetPath: 'assets/data/campaign.json',
    deckName: 'Campaign',
    description: 'Core campaign vocabulary',
  ),
  // Add the next campaign here once its JSON file exists, e.g.:
  // CampaignSource(
  //   assetPath: 'assets/data/campaign_2.json',
  //   deckName: 'Campaign 2',
  // ),
];
