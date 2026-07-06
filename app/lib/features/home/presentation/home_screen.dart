import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_gradients.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/bouncing_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../spin/presentation/widgets/free_spin_badge.dart';
import '../../wallet/presentation/widgets/coin_balance_chip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  children: [
                    _AccountChip(
                      name: auth?.name ?? 'Guest',
                      signedIn: auth != null,
                      onTap: () => context.push(
                          auth == null ? AppRoutes.login : AppRoutes.profile),
                    ),
                    const Spacer(),
                    const CoinBalanceChip(compact: true),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: SvgPicture.asset(AppAssets.icon('sound_on'),
                          width: 26),
                    ),
                  ],
                ),
              ),
              // Scrollable menu so the growing set of entries never overflows.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: Column(
                    children: [
                      SvgPicture.asset(AppAssets.logo, width: 210),
                      const SizedBox(height: 8),
                      Text('Roll the dice. Bring them home.',
                          style: AppTextStyles.body
                              .copyWith(color: Colors.white70)),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: 'Play',
                        icon: Icons.play_arrow_rounded,
                        gradient: AppGradients.accentButton,
                        onPressed: () => context.push(AppRoutes.play),
                      ),
                      const SizedBox(height: 12),
                      const FreeSpinBadge(),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Enter Boards',
                        icon: Icons.grid_view_rounded,
                        onPressed: () => context.push(AppRoutes.boards),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MenuTile(
                              icon: 'friends',
                              label: 'Online',
                              onTap: () => context.push(AppRoutes.matchmaking),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _MenuTile(
                              icon: 'room',
                              label: 'Private Room',
                              onTap: () => context.push(AppRoutes.createRoom),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MenuTile(
                              icon: 'trophy',
                              label: 'Leaderboard',
                              onTap: () => context.push(AppRoutes.leaderboard),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _MenuTile(
                              icon: 'dice',
                              label: 'How to Play',
                              onTap: () => context.push(AppRoutes.help),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip(
      {required this.name, required this.signedIn, required this.onTap});
  final String name;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.avatarGuest, width: 28),
            const SizedBox(width: 8),
            Text(name,
                style: AppTextStyles.label.copyWith(color: Colors.white)),
            const SizedBox(width: 4),
            Icon(signedIn ? Icons.person : Icons.login,
                color: Colors.white, size: 16),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            SvgPicture.asset(AppAssets.icon(icon), width: 34),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.label.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
