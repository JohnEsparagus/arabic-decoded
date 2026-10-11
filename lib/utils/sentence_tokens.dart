/// Breaking Arabic sentences into words, and working out which dictionary
/// word each one is. That second part is what links a sentence to the
/// word cards in it: it's how a word's page finds its sentences, and how
/// each word of a sentence gets coloured by how well it's known.
library;

import 'arabic_normalize.dart';

/// A run of Arabic letters and the marks that sit on them.
final _arabicWord = RegExp('[ء-ٰٟ-ۓ]+');

/// One piece of a sentence: a word, or the spaces and punctuation between
/// two words.
typedef SentencePiece = ({String text, bool isWord});

/// Splits [sentence] into words and what lies between them, in order, so
/// the pieces put back together are the sentence again.
List<SentencePiece> splitSentence(String sentence) {
  final pieces = <SentencePiece>[];
  var end = 0;
  for (final match in _arabicWord.allMatches(sentence)) {
    if (match.start > end) {
      pieces.add((text: sentence.substring(end, match.start), isWord: false));
    }
    pieces.add((text: match.group(0)!, isWord: true));
    end = match.end;
  }
  if (end < sentence.length) {
    pieces.add((text: sentence.substring(end), isWord: false));
  }
  return pieces;
}

/// Particles Arabic writes attached to the front of the next word: "the",
/// "and", "in/with", "to/for", "so", alone or stacked with "the". Longest
/// first, so "وال" is tried before "و".
const _prefixes = ['وال', 'بال', 'فال', 'كال', 'لل', 'ال', 'و', 'ب', 'ل', 'ف'];

/// Endings written attached to a word: the alif of an indefinite object,
/// and the pronouns "his", "her", "their", "our".
const _endings = ['ا', 'ه', 'ها', 'هم', 'نا'];

/// What's left of a word has to be at least this long for a prefix to be
/// taken off it; shorter than that and it was part of the word.
const _shortestStem = 3;

/// The dictionary forms a word as written in a sentence might be, most
/// likely first: the word itself with its vowel marks stripped (see
/// [wordKey], which is also what word cards are looked up by),
/// then with an attached particle removed, then without an ending: the
/// alif that marks an indefinite object ("كتابا" for "كتاب") or an
/// attached pronoun ("كتابه", his book).
///
/// It's a light touch on purpose: enough to see "الكتاب", "وكتابا" and
/// "كتابه" as "كتاب", with no attempt at conjugated verbs. A word it can't
/// place just doesn't link to a card.
List<String> wordKeys(String word) {
  final plain = wordKey(word);
  final keys = <String>[plain];
  void add(String key) {
    if (key.length >= _shortestStem && !keys.contains(key)) keys.add(key);
  }

  void addWithoutEnding(String key) {
    for (final ending in _endings) {
      if (key.endsWith(ending)) {
        add(key.substring(0, key.length - ending.length));
      }
    }
  }

  for (final prefix in _prefixes) {
    if (plain.startsWith(prefix)) {
      final stem = plain.substring(prefix.length);
      add(stem);
      addWithoutEnding(stem);
    }
  }
  addWithoutEnding(plain);
  return keys;
}

/// Every key any word of [sentence] might be filed under: what the
/// sentence is indexed by, so it can be found from any of those words.
Set<String> sentenceKeys(String sentence) {
  return {
    for (final piece in splitSentence(sentence))
      if (piece.isWord) ...wordKeys(piece.text),
  };
}
