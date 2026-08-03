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
    assetPath: 'assets/data/campaign_1_absolute_core.json',
    deckName: 'Absolute Core',
    description: 'The most foundational roots: writing, saying, knowing, being',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_2_daily_actions.json',
    deckName: 'Daily Actions',
    description: 'Going, coming, entering, sitting, and other everyday verbs',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_3_learning_communication.json',
    deckName: 'Learning & Communication',
    description: 'Asking, answering, studying, explaining, translating',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_4_people_relationships.json',
    deckName: 'People & Relationships',
    description: 'Birth, life, death, love, family, and marriage',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_5_home_daily_life.json',
    deckName: 'Home & Daily Life',
    description: 'Eating, drinking, cooking, building, owning, selling',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_6_money_work.json',
    deckName: 'Money & Work',
    description: 'Buying, paying, profit, loss, farming, needing, serving',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_7_society_news.json',
    deckName: 'Society & News',
    description: 'Ruling, justice, war, peace, law, and the people',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_8_nature.json',
    deckName: 'Nature',
    description: 'Earth, sky, sun, moon, sea, mountains, wind, rain, light',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_9_time_change.json',
    deckName: 'Time & Change',
    description: 'Beginning, completing, growing, shrinking, nearness',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_10_abstract.json',
    deckName: 'Abstract Concepts',
    description: 'Cause, result, shape, example, gathering, dividing, type',
  ),
];
