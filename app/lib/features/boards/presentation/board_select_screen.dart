import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/theme/board_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/bouncing_button.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';
import '../../wallet/presentation/widgets/coin_balance_chip.dart';
import '../application/boards_controller.dart';
import '../data/board_models.dart';
import 'widgets/board_preview.dart';

class BoardSelectScreen extends ConsumerWidget {
  const BoardSelectScreen({super.key});

  void _play(
    BuildContext context,
    WidgetRef ref, {
    required BoardTier tier,
    required int humans,
    required int bots,
    required bool teamMode,
  }) {
    ref.read(activeBoardThemeProvider.notifier).state = BoardTheme.forKey(tier.key);
    ref.read(localCacheProvider).setSelectedBoardTier(tier.key);
    ref.read(gameConfigProvider.notifier).state = GameConfig.local(
      humans: humans,
      bots: bots,
      boardThemeKey: tier.key,
      teamMode: teamMode,
    );
    context.go(AppRoutes.game);
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, BoardTier tier) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ModeSheet(tier: tier, onPlay: (h, b, team) {
        Navigator.pop(ctx);
        _play(context, ref, tier: tier, humans: h, bots: b, teamMode: team);
      }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boardsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Boards'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: CoinBalanceChip(compact: true)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (_, __) => const Center(
              child: Text('Could not load boards.', style: TextStyle(color: Colors.white)),
            ),
            data: (snap) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 24),
              children: [
                Text('Higher stakes, bigger pots — winner takes all.',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ...snap.tiers.map((t) => _BoardCard(
                      tier: t,
                      onTap: () => _openSheet(context, ref, t),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.tier, required this.onTap});
  final BoardTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = BoardTheme.forKey(tier.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.frame.withValues(alpha: 0.55), width: 2),
          ),
          child: Row(
            children: [
              BoardPreview(theme: theme, size: 92),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(tier.name, style: AppTextStyles.title)),
                        const SizedBox(width: 8),
                        if (tier.badge != null) _Badge(text: tier.badge!, color: theme.frame),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (tier.description != null)
                      Text(tier.description!, style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const CoinIcon(size: 20),
                        const SizedBox(width: 6),
                        Text('${formatCoins(tier.stake)} entry',
                            style: AppTextStyles.label.copyWith(color: AppColors.ink)),
                        const Spacer(),
                        Icon(Icons.play_circle_fill_rounded, color: theme.frame, size: 26),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: AppTextStyles.label.copyWith(color: color, fontSize: 11)),
      );
}

class _ModeSheet extends StatefulWidget {
  const _ModeSheet({required this.tier, required this.onPlay});
  final BoardTier tier;
  final void Function(int humans, int bots, bool teamMode) onPlay;

  @override
  State<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends State<_ModeSheet> {
  int _seats = 4;
  bool _teams = false;

  @override
  Widget build(BuildContext context) {
    final theme = BoardTheme.forKey(widget.tier.key);
    final canTeam = _seats == 4 && widget.tier.team;

    return Padding(
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoardPreview(theme: theme, size: 90),
          const SizedBox(height: 10),
          Text(widget.tier.name, style: AppTextStyles.heading),
          Text('${formatCoins(widget.tier.stake)} entry · winner takes the pot',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: 18),
          Row(
            children: [
              _Seat(label: '2 Players', selected: _seats == 2, onTap: () => setState(() { _seats = 2; _teams = false; })),
              const SizedBox(width: 12),
              _Seat(label: '4 Players', selected: _seats == 4, onTap: () => setState(() => _seats = 4)),
            ],
          ),
          if (canTeam) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('2v2 Teams', style: AppTextStyles.body),
              subtitle: Text('Winning team splits the pot', style: AppTextStyles.bodyMuted),
              value: _teams,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _teams = v),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Action(
                  label: 'vs Computer',
                  color: AppColors.primary,
                  onTap: () => widget.onPlay(1, _seats - 1, _teams),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Action(
                  label: 'Pass & Play',
                  color: theme.frame,
                  onTap: () => widget.onPlay(_seats, 0, _teams),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: AppTextStyles.label
                    .copyWith(color: selected ? Colors.white : AppColors.ink)),
          ),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      );
}
