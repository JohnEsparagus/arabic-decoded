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

/// The 28 letters, for absolute beginners. Not a campaign either: it's
/// optional, and when switched on its cards come before any root (see
/// `DatabaseService.getNewFlashcards`).
const alphabetSource = CampaignSource(
  assetPath: 'assets/data/alphabet.json',
  deckName: 'Alphabet',
  description: 'The 28 letters: their names, sounds and shapes',
);

/// Whole sentences to read. Never fed into the queue automatically: the
/// user picks the ones they want from the Sentences screen.
const sentencesSource = CampaignSource(
  assetPath: 'assets/data/sentences.json',
  deckName: 'Sentences',
  description: 'Everyday sentences to read and understand',
);

/// Read-once cards about anything (a story, a fact), each shown after a
/// set number of roots. The file ships empty; see
/// `ContentImporter.importExtras` for what goes in it.
const extrasSource = CampaignSource(
  assetPath: 'assets/data/extras.json',
  deckName: 'Extras',
);

/// The word patterns (awzān) that words are built on. Not a campaign: a
/// pattern's card comes up along with the words, right before the first
/// word that uses it (see `DatabaseService.getNewFlashcards`).
const patternsSource = CampaignSource(
  assetPath: 'assets/data/patterns.json',
  deckName: 'Patterns',
  description: 'The shapes roots are poured into to make words',
);
