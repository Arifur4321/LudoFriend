import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// The bottom action bar on the game table: Chat, Emoji, Friends, Settings.
class GameActionBar extends StatelessWidget {
  const GameActionBar({
    super.key,
    required this.onChat,
    required this.onEmoji,
    required this.onFriends,
    required this.onSettings,
    this.chatBadge = 0,
    this.friendsBadge = 0,
  });

  final VoidCallback onChat;
  final VoidCallback onEmoji;
  final VoidCallback onFriends;
  final VoidCallback onSettings;
  final int chatBadge;
  final int friendsBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Action(
              icon: Icons.chat_bubble_rounded,
              label: 'CHAT',
              onTap: onChat,
              badge: chatBadge),
          _Action(
              icon: Icons.emoji_emotions_rounded,
              label: 'EMOJI',
              onTap: onEmoji),
          _Action(
              icon: Icons.group_rounded,
              label: 'FRIENDS',
              onTap: onFriends,
              badge: friendsBadge),
          _Action(
              icon: Icons.settings_rounded,
              label: 'SETTINGS',
              onTap: onSettings),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
