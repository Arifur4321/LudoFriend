import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';

/// Leaderboard. Phase 2 loads ranked players from `/leaderboard`; until then it
/// shows a representative layout with an explanatory note.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const _sample = [
    ('Otter4821', 142),
    ('Panda3190', 128),
    ('Tiger7742', 119),
    ('Koala5503', 96),
    ('Robin2210', 88),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            itemCount: _sample.length + 1,
            itemBuilder: (context, i) {
              if (i == _sample.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Live rankings appear here once connected to the server.',
                    style: AppTextStyles.label.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final (name, wins) = _sample[i];
              final medal = i < 3;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: medal
                          ? [
                              AppColors.accent,
                              Colors.grey,
                              Color(0xFFCD7F32)
                            ][i]
                          : AppColors.surfaceMuted,
                      child: Text('${i + 1}',
                          style: AppTextStyles.button.copyWith(
                              color: medal ? Colors.white : AppColors.ink)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(name, style: AppTextStyles.title)),
                    Icon(Icons.emoji_events, size: 18, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('$wins', style: AppTextStyles.body),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
