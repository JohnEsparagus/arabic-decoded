/// The manifest listing all content, and where it's published online.
const contentManifestPath = 'assets/data/manifest.json';
const contentBaseUrl = 'https://johnesparagus.github.io/arabic-decoded/assets/';

/// The newest content format this app understands. Raise it, here and in
/// the manifest, when content needs something older apps can't handle;
/// they then simply stay on the content they have.
const contentSchema = 1;

/// One campaign: a JSON file in `assets/data/` and the deck it imports
/// into. To add one, drop in the file, list it under `campaigns` in
/// assets/data/manifest.json, and run `tool/build_manifest.py`.
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

/// The Quran campaign: the most common roots of the Quran, most common
/// first. Unlike the other campaigns it mostly points at roots taught
/// elsewhere (`{"root": "ك ت ب"}`): there's only ever one card per root, so
/// a root learned in any campaign is learned here too. The Quranic roots
/// no campaign teaches are full entries, imported into this deck. See
/// `ContentImporter.importQuran`.
const quranSource = CampaignSource(
  assetPath: 'assets/data/quran.json',
  deckName: 'Quran',
  description: 'The most common roots of the Quran, most common first',
);

/// The frequency list: useful roots, most common first, shown as the
/// Frequency view of the Roots tab. It works like [quranSource]: a
/// reference for a root taught elsewhere, a whole entry for one that isn't.
/// Its own roots never enter the queue by themselves; users add them.
const frequencySource = CampaignSource(
  assetPath: 'assets/data/frequency.json',
  deckName: 'Frequency',
  description: 'The most useful roots, most common first',
);

/// The 28 letters, for absolute beginners. Not a campaign either: it's
/// optional, and when switched on its cards come before any root (see
/// `DatabaseService.getNewFlashcards`).
const alphabetSource = CampaignSource(
  assetPath: 'assets/data/alphabet.json',
  deckName: 'Alphabet',
  description: 'The 28 letters: their names, sounds and shapes',
);

/// The sentence corpus: whole sentences to read (the app's own example
/// sentences, then a selection from Tatoeba, CC BY 2.0 FR, keeping those
/// that use at least one word the app teaches), browsed from the
/// Sentences screen and listed under the words they contain. Never fed
/// into the queue automatically; one becomes a card, in this deck, when
/// the user adds it.
const sentencesSource = CampaignSource(
  assetPath: 'assets/data/sentences.json',
  deckName: 'Sentences',
  description: 'Everyday sentences to read and understand',
);

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

/// A card that has been renamed or moved to another deck in the content,
/// so that anyone who has studied it keeps their progress under the new
/// name. Cards are identified by deck + Arabic (that's also what sync
/// uses), so without this a corrected spelling would look like a brand new
/// card and the old one would linger. See `DatabaseService.moveCard`.
///
/// They're listed under `moves` in the manifest, as `[fromDeck, from,
/// toDeck, to]`, and applied in order at each launch before the import.
/// Each is skipped once done, so they stay there for good: a device
/// updating from any older version still catches up.
class ContentMove {
  const ContentMove(this.fromDeck, this.from, this.toDeck, this.to);

  final String fromDeck;
  final String from;
  final String toDeck;
  final String to;
}
