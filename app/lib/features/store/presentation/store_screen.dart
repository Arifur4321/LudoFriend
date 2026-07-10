import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../wallet/presentation/widgets/coin_balance_chip.dart';
import '../application/store_controller.dart';
import '../data/store_models.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  bool _busy = false;

  Future<void> _buy(CoinPack pack) async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await ref.read(storeControllerProvider.notifier).buy(pack);
    if (!mounted) return;
    setState(() => _busy = false);

    res.when(
      ok: (o) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(o.pending ? 'Purchase recorded' : 'Coins added!',
                textAlign: TextAlign.center, style: AppTextStyles.heading),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 44),
                const SizedBox(height: 10),
                Text(
                  o.pending
                      ? 'We\'ll credit your coins once the payment is verified.'
                      : '+${formatCoins(o.coinsAwarded)} coins added to your wallet.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(storeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Store'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: CoinBalanceChip(compact: true)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (_, __) => const Center(
              child: Text('Store is unavailable right now.', style: TextStyle(color: Colors.white)),
            ),
            data: (packs) => Stack(
              children: [
                GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 84, 16, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                  children: packs.map((p) => PackCard(pack: p, onTap: () => _buy(p))).toList(),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class PackCard extends StatelessWidget {
  const PackCard({super.key, required this.pack, required this.onTap});
  final CoinPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = pack.bestValue || pack.popular;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Clip so the coloured ribbon follows the card's rounded corners.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: highlight
              ? Border.all(color: AppColors.accent, width: 2.5)
              : null,
        ),
        child: Column(
          children: [
            // Fixed-height ribbon band: highlighted cards show POPULAR / BEST
            // VALUE, plain cards reserve the same height. Keeping the band a
            // constant height means every grid cell needs the same vertical
            // space, which removes the bottom overflow the taller ribbon used
            // to cause on the highlighted cards.
            SizedBox(
              height: 22,
              width: double.infinity,
              child: highlight
                  ? ColoredBox(
                      color: AppColors.accent,
                      child: Center(
                        child: Text(
                          pack.bestValue ? 'BEST VALUE' : 'POPULAR',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            const CoinIcon(size: 38),
            const SizedBox(height: 6),
            Text(formatCoins(pack.totalCoins),
                style: AppTextStyles.title.copyWith(color: AppColors.ink)),
            if (pack.bonus > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('incl. +${formatCoins(pack.bonus)} bonus',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
              ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(10),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5B3FD6), Color(0xFF8E6BFF)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(pack.price != null ? '\$${pack.price}' : 'Buy',
                  style: AppTextStyles.button.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
