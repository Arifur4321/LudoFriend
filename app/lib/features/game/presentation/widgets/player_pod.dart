import 'package:flutter/material.dart';

import '../../../../game_engine/models/game_player.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/player_avatar.dart';

/// A corner identity card for one seat: avatar, name pill, online dot and four
/// home-progress pips. Scales up and recolors on the active turn.
class PlayerPod extends StatelessWidget {
  const PlayerPod({
    super.key,
    required this.player,
    required this.active,
    required this.homeCount,
    this.online = true,
    this.mirror = false,
    this.avatarRadius = 26,
  });

  final GamePlayer player;
  final bool active;
  final int homeCount;
  final bool online;

  /// When true the pod is laid out right-to-left (for the right-hand corners).
  final bool mirror;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(player.color);

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        PlayerAvatar(player: player, radius: avatarRadius),
        Positioned(
          right: mirror ? null : 0,
          left: mirror ? 0 : null,
          bottom: 0,
          child: Container(
            width: avatarRadius * 0.5,
            height: avatarRadius * 0.5,
            decoration: BoxDecoration(
              color: online
                  ? const Color(0xFF39D353)
                  : const Color(0xFF9AA4AD),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );

    final meta = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 128),
      child: Column(
        crossAxisAlignment:
            mirror ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: active ? color : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < homeCount
                      ? color
                      : Colors.white.withValues(alpha: 0.55),
                ),
              );
            }),
          ),
        ],
      ),
    );

    final children = mirror
        ? [meta, const SizedBox(width: 8), avatar]
        : [avatar, const SizedBox(width: 8), meta];

    return AnimatedScale(
      scale: active ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 220),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
