import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/bouncing_button.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';

class PlayOptionsScreen extends ConsumerWidget {
  const PlayOptionsScreen({super.key});

  void _startLocal(BuildContext context, WidgetRef ref,
      {required int humans, required int bots}) {
    ref.read(gameConfigProvider.notifier).state =
        GameConfig.local(humans: humans, bots: bots);
    context.go(AppRoutes.game);
  }

  Future<void> _pickSeats(
      BuildContext context, WidgetRef ref, bool vsBot) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vsBot ? 'Play vs Computer' : 'Pass & Play',
                style: AppTextStyles.heading),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SeatButton(
                    label: '2 Players',
                    onTap: () {
                      Navigator.pop(ctx);
                      _startLocal(context, ref,
                          humans: vsBot ? 1 : 2, bots: vsBot ? 1 : 0);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SeatButton(
                    label: '4 Players',
                    onTap: () {
                      Navigator.pop(ctx);
                      _startLocal(context, ref,
                          humans: vsBot ? 1 : 4, bots: vsBot ? 3 : 0);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Mode')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              _ModeCard(
                icon: 'dice',
                title: 'Pass & Play',
                subtitle: '2–4 players on this device',
                color: AppColors.tokenGreen,
                onTap: () => _pickSeats(context, ref, false),
              ),
              _ModeCard(
                icon: 'bot',
                title: 'Vs Computer',
                subtitle: 'Practice against smart bots',
                color: AppColors.tokenBlue,
                onTap: () => _pickSeats(context, ref, true),
              ),
              _ModeCard(
                icon: 'friends',
                title: 'Online Match',
                subtitle: 'Random 2 or 4-player games',
                color: AppColors.tokenRed,
                onTap: () => context.push(AppRoutes.matchmaking),
              ),
              _ModeCard(
                icon: 'room',
                title: 'Private Room',
                subtitle: 'Play friends with a room code',
                color: AppColors.tokenYellow,
                onTap: () => context.push(AppRoutes.createRoom),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset(AppAssets.icon(icon)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label, style: AppTextStyles.title),
      ),
    );
  }
}
