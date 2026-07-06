import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/bouncing_button.dart';
import '../../application/wallet_controller.dart';

/// A tappable coin-balance pill. Shows the live balance and a "+" that jumps to
/// the coin store. Designed to sit on the purple app background.
class CoinBalanceChip extends ConsumerWidget {
  const CoinBalanceChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinsProvider);
    final label = compact ? compactCoins(coins) : formatCoins(coins);

    return BouncingButton(
      onTap: () => context.push(AppRoutes.wallet),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Coin(size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.label.copyWith(color: Colors.white)),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 16, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small stylised gold coin used across the economy UI.
class _Coin extends StatelessWidget {
  const _Coin({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD770), Color(0xFFF5A623)],
        ),
        border: Border.all(color: const Color(0xFFE0902A), width: 1),
      ),
      alignment: Alignment.center,
      child: Text('C',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF9A5B00),
          )),
    );
  }
}

/// Public stylised coin for reuse (store, spin, boards).
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => _Coin(size: size);
}
