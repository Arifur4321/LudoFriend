import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// The compact "LUDO <tier>" wordmark shown at the top of the game table.
/// Colored letters echo the four token colors; the ribbon names the board tier.
class LudoHeader extends StatelessWidget {
  const LudoHeader({super.key, required this.tierName});

  final String tierName;

  static const List<(String, Color)> _letters = [
    ('L', AppColors.tokenRed),
    ('U', AppColors.tokenBlue),
    ('D', AppColors.tokenGreen),
    ('O', AppColors.tokenYellow),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (ch, col) in _letters)
              Text(
                ch,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: col,
                  height: 1.0,
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 1),
                    Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 2)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3F74FF), Color(0xFF2B57D6)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            tierName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}
