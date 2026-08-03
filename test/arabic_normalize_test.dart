import 'package:arabic_decoded/utils/arabic_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeArabic', () {
    test('strips diacritics', () {
      expect(normalizeArabic('كَتَبَ'), normalizeArabic('كتب'));
    });

    test('folds alef variants to a plain alef', () {
      expect(normalizeArabic('أكتب'), normalizeArabic('اكتب'));
      expect(normalizeArabic('إكتب'), normalizeArabic('اكتب'));
      expect(normalizeArabic('آكتب'), normalizeArabic('اكتب'));
    });

    test('folds ta marbuta to ha and alef maksura to ya', () {
      expect(normalizeArabic('مكتبة'), normalizeArabic('مكتبه'));
      expect(normalizeArabic('قارئ'), isNot(isEmpty));
      expect(normalizeArabic('على'), normalizeArabic('علي'));
    });

    test('collapses whitespace and trims', () {
      expect(normalizeArabic('  كتاب   جديد  '), 'كتاب جديد');
    });

    test('is safe on plain English/mixed input', () {
      expect(normalizeArabic('Book كتاب'), 'book كتاب');
    });
  });
}
