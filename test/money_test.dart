import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/money/money.dart';

void main() {
  group('centsFromServer', () {
    test('parses decimal strings exactly (no float drift)', () {
      expect(centsFromServer('50.00'), 5000);
      expect(centsFromServer('0.29'), 29);
      expect(centsFromServer('1234.99'), 123499);
      expect(centsFromServer('16.70'), 1670);
    });

    test('handles ints, nums, missing fraction, and one-digit fraction', () {
      expect(centsFromServer(50), 5000);
      expect(centsFromServer(50.5), 5050);
      expect(centsFromServer('50'), 5000);
      expect(centsFromServer('50.5'), 5050);
    });

    test('truncates beyond two decimals and handles negatives / null / empty', () {
      expect(centsFromServer('9.999'), 999); // truncated, not rounded
      expect(centsFromServer('-12.34'), -1234);
      expect(centsFromServer(null), 0);
      expect(centsFromServer(''), 0);
    });
  });

  group('centsToDecimalString / formatCents', () {
    test('round-trips with centsFromServer', () {
      for (final c in <int>[0, 5, 99, 100, 5000, 123499]) {
        expect(centsFromServer(centsToDecimalString(c)), c);
      }
    });

    test('pads the fraction and prefixes currency', () {
      expect(centsToDecimalString(5), '0.05');
      expect(centsToDecimalString(1670), '16.70');
      expect(formatCents(5000), '50.00');
      expect(formatCents(5000, currency: 'USD'), 'USD 50.00');
    });
  });
}
