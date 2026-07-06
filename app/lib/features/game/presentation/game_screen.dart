import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../game_engine/models/game_status.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../application/game_config.dart';
import '../application/game_controller.dart';
import 'widgets/dice_widget.dart';
import 'widgets/ludo_board.dart';
import 'widgets/player_chip.dart';
import 'widgets/turn_timer_bar.dart';
import 'widgets/winner_overlay.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gameConfigProvider);
    if (config == null) {
      return const Scaffold(
        body: Center(child: Text('No game in progress')),
      );
    }

    final session = ref.watch(gameControllerProvider);
    final game = session.game;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(onLeave: () => _confirmLeave(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < game.players.length; i++)
                          PlayerChip(
                            player: game.players[i],
                            active: i == game.currentPlayerIndex &&
                                !game.isFinished,
                            homeCount: game
                                .tokensOf(game.players[i].color)
                                .where((t) => t.isFinished)
                                .length,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const LudoBoard(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _BottomPanel(),
                ],
              ),
              if (game.isFinished && game.winner != null)
                WinnerOverlay(
                  winner: game.winner!,
                  winnerName: game.players
                      .firstWhere((p) => p.color == game.winner)
                      .name,
                  onRematch: () => _rematch(ref, config),
                  onHome: () => context.go('/home'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _rematch(WidgetRef ref, GameConfig config) {
    ref.read(gameConfigProvider.notifier).state = GameConfig(
      mode: config.mode,
      players: config.players,
      rules: config.rules,
      seed: DateTime.now().millisecondsSinceEpoch,
      autoMoveSingle: config.autoMoveSingle,
      // Preserve the chosen board so a rematch stays on the same table.
      boardThemeKey: config.boardThemeKey,
      stake: config.stake,
      teamMode: config.teamMode,
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('Your current match will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && context.mounted) context.go('/home');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onLeave});
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Spacer(),
          Text('Ludo Friends',
              style: AppTextStyles.title.copyWith(color: Colors.white)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BottomPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final game = session.game;
    final current = game.currentPlayer;
    final color = AppColors.of(current.color);

    String status;
    if (game.isFinished) {
      status = 'Game over';
    } else if (session.isRolling) {
      status = 'Rolling…';
    } else if (current.isBot) {
      status = '${current.name} is thinking…';
    } else if (game.status == GameStatus.awaitingMove) {
      status = 'Tap a glowing token';
    } else {
      status = current.isHuman ? 'Your turn — roll!' : "${current.name}'s turn";
    }

    final showTimer = current.isHuman &&
        !game.isFinished &&
        !session.isBusy &&
        (game.status == GameStatus.waitingForRoll ||
            game.status == GameStatus.awaitingMove);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTimer)
            TurnTimerBar(
              key: ValueKey(
                  '${game.turnCount}-${game.status}-${game.currentPlayerIndex}-${session.diceFace}'),
              seconds: game.rules.turnTimerSeconds,
              color: color,
              onExpire: () => _autoAct(controller, ref),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: color),
              const SizedBox(width: 8),
              Expanded(child: Text(status, style: AppTextStyles.body)),
              if (session.banner != null)
                Text(session.banner!,
                    style: AppTextStyles.label.copyWith(color: color)),
              const SizedBox(width: 12),
              DiceWidget(
                face: session.diceFace,
                rolling: session.isRolling,
                enabled: session.canRoll,
                tint: color,
                onRoll: controller.rollDice,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _autoAct(GameController controller, WidgetRef ref) {
    final game = ref.read(gameControllerProvider).game;
    if (game.isFinished) return;
    if (game.status == GameStatus.waitingForRoll) {
      controller.rollDice();
    } else if (game.status == GameStatus.awaitingMove &&
        game.pendingMovableTokenIds.isNotEmpty) {
      controller.pickToken(game.pendingMovableTokenIds.first);
    }
  }
}
