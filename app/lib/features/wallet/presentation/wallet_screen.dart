import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/wallet_controller.dart';
import '../data/wallet_models.dart';
import 'widgets/coin_balance_chip.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletControllerProvider);
    final coins = async.valueOrNull?.coins ?? 0;
    final recent = async.valueOrNull?.recent ?? const <WalletTx>[];

    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(walletControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
              children: [
                _BalanceCard(coins: coins),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Daily Spin',
                        icon: Icons.casino_rounded,
                        onPressed: () => context.push(AppRoutes.spin),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Get Coins',
                        icon: Icons.add_shopping_cart_rounded,
                        onPressed: () => context.push(AppRoutes.store),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Recent activity',
                    style: AppTextStyles.title.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                if (async.isLoading && recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
                else if (recent.isEmpty)
                  _EmptyActivity()
                else
                  ...recent.map((t) => _TxTile(tx: t)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2440), Color(0xFF4B3E86)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text('Balance',
              style: AppTextStyles.label.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(size: 30),
              const SizedBox(width: 10),
              Text(formatCoins(coins),
                  style: AppTextStyles.heading
                      .copyWith(color: Colors.white, fontSize: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final WalletTx tx;

  static const _labels = {
    'signup_bonus': 'Welcome bonus',
    'stake': 'Match buy-in',
    'prize': 'Match prize',
    'refund': 'Stake refunded',
    'spin': 'Daily spin',
    'purchase': 'Coin purchase',
    'adjustment': 'Adjustment',
  };

  @override
  Widget build(BuildContext context) {
    final credit = tx.isCredit;
    final title = tx.description ?? _labels[tx.type] ?? tx.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (credit ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
            child: Icon(credit ? Icons.arrow_downward : Icons.arrow_upward,
                color: credit ? AppColors.success : AppColors.danger, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                if (tx.createdAt != null)
                  Text(_fmtDate(tx.createdAt!), style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          Text('${credit ? '+' : ''}${formatCoins(tx.amount)}',
              style: AppTextStyles.title.copyWith(
                color: credit ? AppColors.success : AppColors.danger,
              )),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('No activity yet. Win a match or take a daily spin!',
          style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
    );
  }
}
