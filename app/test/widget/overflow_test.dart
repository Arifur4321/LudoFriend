import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ludo_friends/features/store/data/store_models.dart';
import 'package:ludo_friends/features/store/presentation/store_screen.dart';
import 'package:ludo_friends/shared/widgets/primary_button.dart';

/// Regression tests for the wallet / coin-store layout overflows.
///
/// A RenderFlex overflow surfaces during layout as a thrown FlutterError, which
/// `tester.takeException()` returns; a passing test means the widget laid out
/// cleanly at the given width.
void main() {
  setUpAll(() {
    // Never hit the network for fonts in tests; fall back to a platform font.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Wallet action buttons (Free Spin / Get Coins)', () {
    Widget walletButtons() => Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Free Spin',
                icon: Icons.casino_rounded,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Get Coins',
                icon: Icons.add_shopping_cart_rounded,
                onPressed: () {},
              ),
            ),
          ],
        );

    for (final width in <double>[360, 320, 240]) {
      testWidgets('render without overflow at ${width.toInt()}px', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(width: width, child: walletButtons()),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Free Spin'), findsOneWidget);
        expect(find.text('Get Coins'), findsOneWidget);
      });
    }
  });

  group('Coin store pack cards', () {
    CoinPack pack({
      required String id,
      required int total,
      required int bonus,
      required String price,
      bool popular = false,
      bool best = false,
    }) =>
        CoinPack(
          productId: id,
          coins: total - bonus,
          bonus: bonus,
          totalCoins: total,
          price: price,
          popular: popular,
          bestValue: best,
        );

    testWidgets('highlighted and plain cards do not overflow', (tester) async {
      final packs = <CoinPack>[
        pack(id: 'p1', total: 5000, bonus: 0, price: '0.99'),
        pack(id: 'p2', total: 33000, bonus: 3000, price: '4.99'),
        pack(id: 'p3', total: 92000, bonus: 12000, price: '9.99', popular: true),
        pack(id: 'p4', total: 625000, bonus: 125000, price: '49.99', best: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
                children: [
                  for (final p in packs) PackCard(pack: p, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('POPULAR'), findsOneWidget);
      expect(find.text('BEST VALUE'), findsOneWidget);
    });
  });
}
