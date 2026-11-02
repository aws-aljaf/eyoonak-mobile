import 'package:fleet_saas_driver/features/family/application/device_pairing_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePairingCode', () {
    test('trims leading and trailing whitespace', () {
      expect(normalizePairingCode('  ABCD1234  '), 'ABCD1234');
    });

    test('uppercases a lowercase or mixed-case code', () {
      expect(normalizePairingCode('abcd1234'), 'ABCD1234');
      expect(normalizePairingCode('AbCd1234'), 'ABCD1234');
    });

    test('trims and uppercases together, matching the web app behavior', () {
      expect(normalizePairingCode('  abcd1234  '), 'ABCD1234');
    });

    test('leaves an already-normalized code unchanged', () {
      expect(normalizePairingCode('ABCD1234'), 'ABCD1234');
    });
  });

  group('isPlausiblePairingCode', () {
    test('is false for an empty string', () {
      expect(isPlausiblePairingCode(''), isFalse);
    });

    test('is false for fewer than 8 characters', () {
      expect(isPlausiblePairingCode('ABCD123'), isFalse);
    });

    test('is false for more than 8 characters', () {
      expect(isPlausiblePairingCode('ABCD12345'), isFalse);
    });

    test('is true for exactly 8 characters', () {
      expect(isPlausiblePairingCode('ABCD1234'), isTrue);
    });
  });
}
