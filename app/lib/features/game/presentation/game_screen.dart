import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../game_engine/models/game_player.dart';
import '../../../game_engine/models/game_status.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/board_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../settings/application/settings_controller.dart';
import '../application/celebration.dart';
import '../application/emoji_reactions.dart';
import '../application/game_config.dart';
import '../application/game_controller.dart';
import '../application/game_session.dart';
import 'widgets/celebration_burst.dart';
import 'widgets/dice_widget.dart';
import 'widgets/game_action_bar.dart';
import 'widgets/game_chat.dart';
import 'widgets/ludo_board.dart';
import 'widgets/ludo_header.dart';
import 'widgets/player_pod.dart';
import 'widgets/turn_timer_bar.dart';
import 'widgets/winner_overlay.dart';

/// The live "table": LUDO header, four corner player pods each with their own
/// dice (the active player's is enlarged and, for you, tappable), the board in
/// the middle, a turn status strip, and the Chat/Emoji/Friends/Settings bar.
/// The same layout is used for every board tier.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gameConfigProvider);
    if (config == null) {
      return const Scaffold(body: Center(child: Text('No game in progress')));
    }

    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final game = session.game;
    final theme = ref.watch(activeBoardThemeProvider);
    final settings = ref.watch(settingsControllerProvider);

    // Float incoming emoji reactions over the board. The controller de-dupes by
    // id and self-expires; here we flash only the reactions newly added since
    // the last build, so each one plays exactly once and several can co-exist.
    ref.listen<List<EmojiReaction>>(emojiReactionsProvider, (prev, next) {
      if (!context.mounted) return;
      final seen = {for (final r in (prev ?? const <EmojiReaction>[])) r.id};
      for (final r in next) {
        if (!seen.contains(r.id)) {
          flashEmoji(context, r.emoji, sender: r.sender);
        }
      }
    });

    // Flash a short celebration when any player's token reaches home.
    ref.listen<CelebrationEvent?>(celebrationProvider, (prev, next) {
      if (next != null && context.mounted) {
        flashTokenHome(context, AppColors.of(next.color));
        Future.microtask(
            () => ref.read(celebrationProvider.notifier).state = null);
      }
    });

    GamePlayer? seatOf(LudoColor c) {
      for (final p in game.players) {
        if (p.color == c) return p;
      }
      return null;
    }

    Widget corner(LudoColor c, {required bool mirror}) {
      final p = seatOf(c);
      if (p == null) return const SizedBox.shrink();
      final isActive = !game.isFinished && game.currentPlayer.color == c;
      final homeCount = game.tokensOf(c).where((t) => t.isFinished).length;
      final pod = PlayerPod(
        player: p,
        active: isActive,
        homeCount: homeCount,
        online: !p.isBot,
        mirror: mirror,
        teamSide: config.teamMode ? c.teamSide : null,
      );
      final die = _PodDice(
        active: isActive,
        color: AppColors.of(c),
        session: session,
        isLocalHuman: isActive && p.isHuman,
        onRoll: controller.rollDice,
      );
      final items = mirror
          ? [die, const SizedBox(width: 6), pod]
          : [pod, const SizedBox(width: 6), die];
      // FittedBox guards against a RenderFlex overflow on very narrow phones.
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: mirror ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header row: back + wordmark.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _confirmLeave(context),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                        ),
                        Expanded(
                          child: Center(child: LudoHeader(tierName: theme.name)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // Top pods: RED (top-left) · GREEN (top-right).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: corner(LudoColor.red, mirror: false),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: corner(LudoColor.green, mirror: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Board.
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const LudoBoard(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom pods: BLUE (bottom-left) · YELLOW (bottom-right).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: corner(LudoColor.blue, mirror: false),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: corner(LudoColor.yellow, mirror: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _StatusStrip(),
                  GameActionBar(
                    onChat: () {
                      if (settings.chat) {
                        showGameChat(context);
                      } else {
                        _hint(context, 'Chat is off — turn it on in Settings');
                      }
                    },
                    onEmoji: () {
                      if (settings.emoji) {
                        showGameEmojis(context, ref);
                      } else {
                        _hint(context, 'Emoji is off — turn it on in Settings');
                      }
                    },
                    onFriends: () => context.push(AppRoutes.friends),
                    onSettings: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
              if (game.isFinished && game.winner != null)
                WinnerOverlay(
                  winner: game.winner!,
                  winnerName: game.players
                      .firstWhere((p) => p.color == game.winner)
                      .name,
                  teamWin: config.teamMode,
                  teamLabel: config.teamMode
                      ? LudoColor.teamLabel(game.winner!.teamSide)
                      : null,
                  teammateNames: config.teamMode
                      ? game.players
                          .where(
                              (p) => p.color.teamSide == game.winner!.teamSide)
                          .map((p) => p.name)
                          .toList()
                      : const [],
                  onRematch: () => config.isOnline
                      ? context.go(AppRoutes.home)
                      : _rematch(ref, config),
                  onHome: () => context.go(AppRoutes.home),
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
    if (leave == true && context.mounted) context.go(AppRoutes.home);
  }
}

void _hint(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// A per-player die. The active player's die is larger and animates; when it's
/// your turn it is tappable to roll. Inactive dice are dimmed placeholders so
/// each seat visibly "has" a die near it.
class _PodDice extends StatelessWidget {
  const _PodDice({
    required this.active,
    required this.color,
    required this.session,
    required this.isLocalHuman,
    required this.onRoll,
  });

  final bool active;
  final Color color;
  final GameSession session;
  final bool isLocalHuman;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    final die = DiceWidget(
      face: active ? session.diceFace : null,
      rolling: active && session.isRolling,
      enabled: isLocalHuman && session.canRoll,
      onRoll: onRoll,
      size: active ? 48 : 34,
      tapTargetSize: active ? 68 : 34,
      tint: color,
    );

    if (!active) return Opacity(opacity: 0.35, child: die);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        die,
        if (isLocalHuman && session.canRoll)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'TAP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// The turn status line + (for a waiting human) an auto-acting countdown bar so
/// a match never stalls on an idle player.
class _StatusStrip extends ConsumerWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final game = session.game;
    final current = game.currentPlayer;
    final color = AppColors.of(current.color);

    final l = AppLocalizations.of(context);
    String status;
    if (game.isFinished) {
      status = l.gameOver;
    } else if (session.isRolling) {
      status = l.rolling;
    } else if (session.banner?.trim().isNotEmpty == true) {
      // Dynamic roll banners are produced by the controller; localizing their
      // templated values is a follow-up (see report).
      status = session.banner!;
    } else if (current.isBot) {
      status = l.playerThinking(current.name);
    } else if (game.status == GameStatus.awaitingMove) {
      status =
          current.isHuman ? l.tapGlowingToken : l.playerMove(current.name);
    } else {
      status =
          current.isHuman ? l.yourTurnTapDice : l.playerTurn(current.name);
    }

    final showTimer = current.isHuman &&
        !game.isFinished &&
        !session.isBusy &&
        (game.status == GameStatus.waitingForRoll ||
            game.status == GameStatus.awaitingMove);

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 2, 28, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTimer)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TurnTimerBar(
                key: ValueKey(
                    '${game.turnCount}-${game.status}-${game.currentPlayerIndex}-${session.diceFace}'),
                seconds: game.rules.turnTimerSeconds,
                color: color,
                onExpire: () => _autoAct(controller, ref),
              ),
            ),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _autoAct(GameController controller, WidgetRef ref) {
    // Never let the turn timer fire an action on top of one the player already
    // started: a manual roll/move that is in flight (or still animating) must
    // win. The controller's submission lock would also reject a duplicate, but
    // bailing here additionally stops the timer from auto-picking a *different*
    // token than the one the player just tapped.
    if (controller.isActionInFlight) return;
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
