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
  CampaignSource(
    assetPath: 'assets/data/campaign_11_body_health.json',
    deckName: 'Body & Health',
    description: 'Body, health, illness, medicine, sleep, strength',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_12_travel_places.json',
    deckName: 'Travel & Places',
    description: 'Travelling, flying, riding, visiting, roads, countries',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_13_feelings_character.json',
    deckName: 'Feelings & Character',
    description:
        'Joy, sadness, fear, anger, patience, thanks, honesty, generosity, mercy',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_14_mind_will.json',
    deckName: 'Mind & Will',
    description:
        'Thinking, reason, feeling, wanting, trying, choosing, success, failure, goals',
  ),
  CampaignSource(
    assetPath: 'assets/data/campaign_15_city_media.json',
    deckName: 'City & Media',
    description:
        'Cities, streets, companies, jobs, messages, pictures, printing, publishing, news',
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

/// The sentence corpus: whole sentences to read, browsed from the
/// Sentences screen and listed under the words they contain. Never fed
/// into the queue automatically; one becomes a card, in this deck, when
/// the user adds it.
const sentencesSource = CampaignSource(
  assetPath: 'assets/data/sentences.json',
  deckName: 'Sentences',
  description: 'Everyday sentences to read and understand',
);

/// Which edition of assets/data/sentences.json this build ships. The
/// corpus is loaded into the database once, then left alone until this
/// number changes, so a launch never has to open the file just to find
/// out nothing is new. **Bump it whenever the file changes** (a test
/// fails if the file changes and this doesn't).
const sentencesVersion = 2;

/// Read-once cards: something to read at a set point along the way, not
/// to memorise. Each file is a deck of them, and each card is shown in
/// the study session once enough roots have been introduced (see
/// `ContentImporter.importReadOnce` for the file format). [label] is the
/// small heading its cards carry, which is also what sorts them into the
/// Lessons and Stories screens.
class ReadOnceSource {
  const ReadOnceSource({
    required this.assetPath,
    required this.deckName,
    required this.label,
  });

  final String assetPath;
  final String deckName;
  final String label;
}

/// How Arabic builds words from roots, one pattern at a time, each placed
/// where a learner has just met enough examples of it.
const lessonsSource = ReadOnceSource(
  assetPath: 'assets/data/lessons.json',
  deckName: 'Lessons',
  label: 'Lesson',
);

/// Famous stories of Arab culture, one after each campaign, told with an
/// eye to the roots that campaign taught.
const storiesSource = ReadOnceSource(
  assetPath: 'assets/data/stories.json',
  deckName: 'Stories',
  label: 'Story',
);

/// Anything else: a fact, a note, a milestone. Ships empty.
const extrasSource = ReadOnceSource(
  assetPath: 'assets/data/extras.json',
  deckName: 'Extras',
  label: '',
);

const readOnceSources = [lessonsSource, storiesSource, extrasSource];

/// The word patterns (awzān) that words are built on. Not a campaign: a
/// pattern's card comes up along with the words, right before the first
/// word that uses it (see `DatabaseService.getNewFlashcards`).
const patternsSource = CampaignSource(
  assetPath: 'assets/data/patterns.json',
  deckName: 'Patterns',
  description: 'The shapes roots are poured into to make words',
);
