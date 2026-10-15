import '../models/flashcard.dart';

/// What the speaker button on a card should actually say.
///
/// A root is three letters with spaces between them, not a word, and a
/// letter on its own is just a sound: handed to a speech engine as they
/// are, either comes out garbled or not at all. So both are spoken the
/// way a teacher says them, by the letters' names: ك ت ب is "kāf, tāʾ,
/// bāʾ". Everything else is real Arabic and is read as written, minus the
/// stretching line (ـ) a pattern like ـِيّ is shown with.
String spokenText(Flashcard card) {
  return switch (card.kind) {
    CardKind.root =>
      card.arabicWord.contains(' ')
          ? card.arabicWord
                .split(' ')
                .where((letter) => letter.isNotEmpty)
                .map((letter) => _rootLetterNames[letter] ?? letter)
                .join('، ')
          : card.arabicWord,
    CardKind.letter => _letterNames[card.arabicWord] ?? card.arabicWord,
    _ => card.arabicWord.replaceAll('ـ', ''),
  };
}

/// Each letter's name, vowelled so the speech engine says it properly.
const _letterNames = {
  'ا': 'أَلِف',
  'ب': 'بَاء',
  'ت': 'تَاء',
  'ث': 'ثَاء',
  'ج': 'جِيم',
  'ح': 'حَاء',
  'خ': 'خَاء',
  'د': 'دَال',
  'ذ': 'ذَال',
  'ر': 'رَاء',
  'ز': 'زَاي',
  'س': 'سِين',
  'ش': 'شِين',
  'ص': 'صَاد',
  'ض': 'ضَاد',
  'ط': 'طَاء',
  'ظ': 'ظَاء',
  'ع': 'عَيْن',
  'غ': 'غَيْن',
  'ف': 'فَاء',
  'ق': 'قَاف',
  'ك': 'كَاف',
  'ل': 'لَام',
  'م': 'مِيم',
  'ن': 'نُون',
  'ه': 'هَاء',
  'و': 'وَاو',
  'ي': 'يَاء',
};

/// In a root, an alif with a hamza (أ in أ خ ذ) is the hamza, a consonant,
/// and ى is the root letter ي.
const _rootLetterNames = {
  ..._letterNames,
  'أ': 'هَمْزَة',
  'إ': 'هَمْزَة',
  'ء': 'هَمْزَة',
  'ؤ': 'هَمْزَة',
  'ئ': 'هَمْزَة',
  'ى': 'يَاء',
};
