import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../game_engine/models/ludo_color.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_assets.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Celebration overlay shown when a match ends.
class WinnerOverlay extends StatelessWidget {
  const WinnerOverlay({
    super.key,
    required this.winner,
    required this.winnerName,
    required this.onRematch,
    required this.onHome,
  });

  final LudoColor winner;
  final String winnerName;
  final VoidCallback onRematch;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(winner);
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        IgnorePointer(
          child: Lottie.asset(
            AppAssets.confetti,
            repeat: true,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, size: 72, color: color),
                const SizedBox(height: 12),
                Text('$winnerName wins!',
                    style: AppTextStyles.heading, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('What a game 🎉',
                    style: AppTextStyles.bodyMuted,
                    textAlign: TextAlign.center),
                const SizedBox(height: 22),
                PrimaryButton(
                    label: 'Rematch',
                    icon: Icons.refresh,
                    onPressed: onRematch),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  onPressed: onHome,
                  gradient: const LinearGradient(
                      colors: [AppColors.inkSoft, AppColors.ink]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
