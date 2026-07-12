import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies the localization resources are complete and consistent: English is
/// the template, every required locale loads, and every English key exists in
/// every locale with no orphans. Runs from the package root (`flutter test`),
/// reading the .arb sources directly.
void main() {
  const dir = 'lib/l10n';
  const requiredLocales = [
    'en', 'de', 'nl', 'es', 'it', 'pt', 'bn', 'hi', 'zh', 'ko', 'ja',
  ];

  Map<String, dynamic> loadArb(String locale) {
    final f = File('$dir/app_$locale.arb');
    expect(f.existsSync(), isTrue, reason: 'missing app_$locale.arb');
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('English template exists and declares itself the default locale', () {
    final en = loadArb('en');
    expect(en['@@locale'], 'en');
    expect(messageKeys(en), isNotEmpty);
  });

  test('every required locale loads and declares its @@locale', () {
    for (final loc in requiredLocales) {
      final arb = loadArb(loc);
      expect(arb['@@locale'], loc, reason: '@@locale mismatch in app_$loc.arb');
    }
  });

  test('every English key exists in every locale, with no orphans', () {
    final enKeys = messageKeys(loadArb('en'));
    for (final loc in requiredLocales) {
      final keys = messageKeys(loadArb(loc));
      expect(enKeys.difference(keys), isEmpty,
          reason: 'app_$loc.arb is missing keys');
      expect(keys.difference(enKeys), isEmpty,
          reason: 'app_$loc.arb has orphan keys not in English');
    }
  });

  test('exactly the 11 supported language files are present', () {
    final arbs = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    expect(arbs.length, requiredLocales.length);
  });
}
