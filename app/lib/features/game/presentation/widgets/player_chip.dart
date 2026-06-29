import 'package:flutter/material.dart';

import '../../../../game_engine/models/game_player.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// Compact player indicator shown around the board. Highlights the active turn
/// and shows how many tokens have reached home.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.player,
    required this.active,
    required this.homeCount,
  });

  final GamePlayer player;
  final bool active;
  final int homeCount;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(player.color);
    return AnimatedScale(
      scale: active ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.96 : 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(radius: 16, backgroundColor: color),
                if (player.isBot)
                  const Icon(Icons.smart_toy, size: 16, color: Colors.white)
                else
                  Text(
                    player.name.characters.first.toUpperCase(),
                    style: AppTextStyles.button.copyWith(fontSize: 16),
                  ),
                if (homeCount == 4)
                  const Positioned(
                    top: -2,
                    child: Icon(Icons.emoji_events,
                        size: 14, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  style: AppTextStyles.label.copyWith(color: AppColors.ink),
                ),
                Row(
                  children: List.generate(
                    4,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 3, top: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < homeCount
                            ? color
                            : color.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
