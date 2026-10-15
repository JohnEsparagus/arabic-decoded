import 'package:arabic_decoded/models/flashcard.dart';
import 'package:arabic_decoded/utils/spoken_text.dart';
import 'package:flutter_test/flutter_test.dart';

Flashcard _card(String arabic, CardKind kind) => Flashcard.newCard(
  arabicWord: arabic,
  englishTranslation: '',
  exampleSentence: '',
  deckId: 1,
  kind: kind,
);

void main() {
  test('a root is spoken as the names of its letters', () {
    expect(spokenText(_card('ك ت ب', CardKind.root)), 'كَاف، تَاء، بَاء');
    // The hamza in أ خ ذ is a consonant, not an alif.
    expect(spokenText(_card('أ خ ذ', CardKind.root)), 'هَمْزَة، خَاء، ذَال');
    expect(spokenText(_card('ر أ ي', CardKind.root)), 'رَاء، هَمْزَة، يَاء');
  });

  test('every root that ships has a name for each of its letters', () {
    // Spaced roots are made of single letters, all of which must be known;
    // otherwise a bare letter slips through and is mispronounced.
    const letters = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي';
    for (final letter in letters.split('')) {
      expect(
        spokenText(_card('$letter $letter', CardKind.root)),
        isNot(contains(RegExp('(^|، )$letter(،|\$)'))),
        reason: letter,
      );
    }
  });

  test('a letter is spoken as its name', () {
    expect(spokenText(_card('ب', CardKind.letter)), 'بَاء');
    expect(spokenText(_card('ا', CardKind.letter)), 'أَلِف');
    expect(spokenText(_card('ع', CardKind.letter)), 'عَيْن');
  });

  test('words and patterns are read as written', () {
    expect(spokenText(_card('كِتَاب', CardKind.word)), 'كِتَاب');
    expect(spokenText(_card('فَاعِل', CardKind.pattern)), 'فَاعِل');
    expect(spokenText(_card('ـِيّ', CardKind.pattern)), 'ِيّ');
  });
}
