import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../game_engine/bot/easy_bot.dart';
import '../../../game_engine/ludo_engine.dart';
import '../../../game_engine/models/dice.dart';
import '../../../game_engine/models/game_status.dart';
import '../../../services/audio/audio_service.dart';
import 'game_config.dart';
import 'game_session.dart';

/// Holds the [GameConfig] for the match about to be / currently played.
/// Set during navigation, read by [gameControllerProvider].
final gameConfigProvider = StateProvider<GameConfig?>((ref) => null);

final gameControllerProvider =
    StateNotifierProvider.autoDispose<GameController, GameSession>((ref) {
  final config = ref.watch(gameConfigProvider);
  if (config == null) {
    throw StateError('gameConfigProvider must be set before opening the game');
  }
  return GameController(config, ref);
});

/// Orchestrates a local match: drives dice rolls, sequences animations, runs
/// bot turns, and plays sound — all on top of the pure [LudoEngine].
///
/// Online play (Phase 2) will subclass / wrap this to apply server-validated
/// moves received over the WebSocket instead of rolling locally.
class GameController extends StateNotifier<GameSession> {
  GameController(this.config, this._ref)
      : super(GameSession(
          game:
              LudoEngine.newGame(players: config.players, rules: config.rules),
        )) {
    _dice = DiceRoller(config.seed);
    _scheduleNext();
  }

  final GameConfig config;
  final Ref _ref;
  final LudoEngine _engine = const LudoEngine();
  final EasyBot _bot = const EasyBot();
  late final DiceRoller _dice;
  bool _busy = false;

  AudioService get _audio => _ref.read(audioServiceProvider);

  /// Called by the dice button (human only).
  Future<void> rollDice() async {
    if (_busy || !state.canRoll) return;
    await _performRoll();
  }

  Future<void> _performRoll() async {
    if (_busy || state.game.isFinished) return;
    if (state.game.status != GameStatus.waitingForRoll) return;
    _busy = true;

    final value = _dice.roll();
    state = state.copyWith(isRolling: true, diceFace: value, banner: null);
    _audio.play(Sfx.dice);
    await Future<void>.delayed(AppConstants.diceRoll);
    if (!mounted) return;

    final roll = _engine.applyRoll(state.game, value);
    state = state.copyWith(
      game: roll.state,
      isRolling: false,
      diceFace: value,
      banner: roll.forfeited
          ? 'Three sixes — turn skipped!'
          : (roll.noMove ? 'No moves' : null),
    );
    _busy = false;

    if (roll.forfeited || (roll.noMove && !roll.extraTurn)) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      _scheduleNext();
      return;
    }
    if (roll.noMove && roll.extraTurn) {
      // Rolled a six but stuck — roll again (bot auto, human waits).
      await Future<void>.delayed(const Duration(milliseconds: 450));
      _scheduleNext();
      return;
    }

    // awaitingMove
    if (state.game.currentPlayer.isBot) {
      await Future<void>.delayed(AppConstants.botThinkDelay);
      if (!mounted) return;
      final pick =
          _bot.chooseMove(state.game, value, state.game.pendingMovableTokenIds);
      await pickToken(pick);
    } else if (config.autoMoveSingle &&
        state.game.pendingMovableTokenIds.length == 1) {
      await pickToken(state.game.pendingMovableTokenIds.first);
    }
  }

  /// Called when a (human) taps a highlighted token, or internally for bots.
  Future<void> pickToken(String tokenId) async {
    if (_busy) return;
    if (state.game.status != GameStatus.awaitingMove) return;
    if (!state.game.pendingMovableTokenIds.contains(tokenId)) return;
    _busy = true;

    final applied = _engine.applyMove(state.game, tokenId);
    final result = applied.result;

    // Keep the OLD state visible while the moving token animates along its path.
    state = state.copyWith(isMoving: true, lastMove: result, banner: null);
    _audio.play(result.didCapture ? Sfx.capture : Sfx.move);

    final steps = result.path.isEmpty ? 1 : result.path.length;
    await Future<void>.delayed(
        AppConstants.tokenStep * steps + const Duration(milliseconds: 140));
    if (!mounted) return;

    state = state.copyWith(
      game: applied.state,
      isMoving: false,
      lastMove: null,
      banner: result.didCapture ? 'Captured!' : null,
    );
    _busy = false;

    if (result.winner != null) {
      _audio.play(Sfx.win);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _scheduleNext();
  }

  /// After a settled state, let a bot continue automatically; a human waiting
  /// to roll simply sees the dice enabled.
  void _scheduleNext() {
    if (!mounted || state.game.isFinished) return;
    final g = state.game;
    if (g.status == GameStatus.waitingForRoll && g.currentPlayer.isBot) {
      Future<void>.delayed(AppConstants.botThinkDelay, () {
        if (mounted) _performRoll();
      });
    }
  }
}
