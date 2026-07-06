import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/utils/format.dart';

void main() {
  group('formatCoins', () {
    test('adds thousands separators', () {
      expect(formatCoins(0), '0');
      expect(formatCoins(200), '200');
      expect(formatCoins(1000), '1,000');
      expect(formatCoins(1234567), '1,234,567');
      expect(formatCoins(-2500), '-2,500');
    });
  });

  group('compactCoins', () {
    test('compacts thousands and millions', () {
      expect(compactCoins(500), '500');
      expect(compactCoins(20000), '20K');
      expect(compactCoins(1500), '1.5K');
      expect(compactCoins(1000000), '1M');
      expect(compactCoins(2500000), '2.5M');
    });
  });
}
