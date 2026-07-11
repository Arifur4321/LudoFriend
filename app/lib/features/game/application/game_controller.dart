import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/logger.dart';
import '../../../game_engine/bot/easy_bot.dart';
import '../../../game_engine/ludo_engine.dart';
import '../../../game_engine/models/dice.dart';
import '../../../game_engine/models/game_state.dart';
import '../../../game_engine/models/game_status.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/realtime/realtime_match_service.dart';
import '../../../services/realtime/websocket_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import 'celebration.dart';
import 'game_chat_state.dart';
import 'game_config.dart';
import 'game_session.dart';
import 'server_state_adapter.dart';

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

/// Orchestrates a match.
///
/// Offline (pass-and-play / vs-bot) it drives dice, animations, and bots on top
/// of the pure [LudoEngine]. Online it becomes a thin client of the
/// server-authoritative engine: roll/move go over HTTP and the authoritative
/// snapshot is re-synced (via the state adapter) on every broadcast event —
/// robust and free of client/server drift.
class GameController extends StateNotifier<GameSession> {
  GameController(this.config, this._ref)
      : super(GameSession(
          game:
              LudoEngine.newGame(players: config.players, rules: config.rules),
        )) {
    if (_online) {
      // Defer so we don't mutate other providers during widget build.
      Future.microtask(_initOnline);
    } else {
      _dice = DiceRoller(config.seed);
      _applyLocalIdentity();
      _scheduleNext();
    }
  }

  final GameConfig config;
  final Ref _ref;
  final LudoEngine _engine = const LudoEngine();
  final EasyBot _bot = const EasyBot();
  late final DiceRoller _dice;
  bool _busy = false;
  StreamSubscription<RealtimeEvent>? _rtSub;

  /// Last authoritative snapshot applied in an online match, used to detect
  /// home-arrivals / captures / the win from state diffs so BOTH players get
  /// the same sounds + celebrations regardless of who moved.
  GameState? _lastSyncedGame;

  bool get _online => config.isOnline && config.matchId != null;

  AudioService get _audio => _ref.read(audioServiceProvider);

  /// For a local (offline) game, stamp the signed-in user's name + profile photo
  /// (or guest flag) onto the first human seat, so the board shows YOU rather
  /// than "Player 1". Runs regardless of which entry point started the game
  /// (Enter Boards, matchmaking fallback, private room, rematch, pass & play).
  void _applyLocalIdentity() {
    final me = _ref.read(authControllerProvider).valueOrNull;
    if (me == null) return;
    final players = state.game.players;
    final idx = players.indexWhere((p) => p.isHuman);
    if (idx < 0) return;
    final updated = [...players];
    updated[idx] = updated[idx].copyWith(
      name: me.name,
      avatarUrl: me.avatarUrl,
      isGuest: me.isGuest,
    );
    state = state.copyWith(game: state.game.copyWith(players: updated));
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    if (_online) {
      final id = int.tryParse(config.matchId ?? '');
      if (id != null) {
        _ref.read(realtimeMatchServiceProvider).leaveMatch(id);
      }
      _ref.read(currentMatchIdProvider.notifier).state = null;
    }
    super.dispose();
  }

  /// Called by the dice button (human only).
  Future<void> rollDice() async {
    if (_online) return _sendRoll();
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
    if (_online) return _sendMove(tokenId);
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
    if (result.reachedHome) {
      _audio.play(Sfx.home);
      _celebrate(CelebrationKind.tokenHome,
          LudoColor.fromId(result.movedTokenId.split('_').first));
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _scheduleNext();
  }

  void _celebrate(CelebrationKind kind, LudoColor color) {
    if (!mounted) return;
    _ref.read(celebrationProvider.notifier).state =
        CelebrationEvent(kind, color);
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

  /* =====================================================================
   | Online (server-authoritative) path
   | ===================================================================== */

  Future<void> _initOnline() async {
    _ref.read(currentMatchIdProvider.notifier).state = config.matchId;
    final realtime = _ref.read(realtimeMatchServiceProvider);
    _rtSub = realtime.events.listen(_onRealtimeEvent);
    final matchId = int.tryParse(config.matchId ?? '');
    if (matchId != null) {
      await realtime.joinMatch(matchId);
    }
    await _refreshState();
  }

  Future<void> _refreshState() async {
    if (!mounted) return;
    try {
      final res =
          await _ref.read(dioProvider).get(ApiEndpoints.gameState(config.matchId!));
      final serverState = _extractState(res.data);
      if (serverState != null) _applyServerState(serverState);
    } catch (e, st) {
      AppLogger.e('online state refresh failed', e, st);
    }
  }

  Future<void> _sendRoll() async {
    if (_busy) return;
    _busy = true;
    state = state.copyWith(isRolling: true, banner: null);
    _audio.play(Sfx.dice);
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.rollDice(config.matchId!),
        data: {'color': config.myColor},
      );
      final data = _payload(res.data);
      final serverState = _asMap(data['state']);
      final movable =
          ServerStateAdapter.movableIds(config.myColor ?? '', data['legal_moves']);
      if (serverState != null) {
        _applyServerState(serverState, movable: movable);
      } else {
        state = state.copyWith(isRolling: false);
      }
      _busy = false;
      // Auto-play a forced single move for snappier turns.
      if (movable.length == 1) {
        await _sendMove(movable.first);
      }
    } catch (e, st) {
      AppLogger.e('online roll failed', e, st);
      state = state.copyWith(isRolling: false);
      _busy = false;
    }
  }

  Future<void> _sendMove(String tokenId) async {
    final parts = tokenId.split('_');
    final color = parts.isNotEmpty ? parts[0] : (config.myColor ?? '');
    final token = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.moveToken(config.matchId!),
        data: {'color': color, 'token': token},
      );
      final data = _payload(res.data);
      final serverState = _asMap(data['state']);
      if (serverState != null) {
        // Sounds/celebrations (capture, home, win) come from the state diff in
        // _applyServerState, so they fire identically for every player.
        _applyServerState(serverState);
      }
    } catch (e, st) {
      AppLogger.e('online move failed', e, st);
    }
  }

  void _applyServerState(
    Map<String, dynamic> serverState, {
    List<String> movable = const [],
  }) {
    if (!mounted) return;
    final game = ServerStateAdapter.toGameState(
      serverState: serverState,
      players: config.players,
      rules: config.rules,
      movableTokenIds: movable,
    );
    final prev = _lastSyncedGame;
    _lastSyncedGame = game;
    state = GameSession(game: game, diceFace: game.lastDice);
    // Never on the first snapshot (joining/reconnecting mustn't replay noises).
    if (prev != null) _announceDiff(prev, game);
  }

  /// Compare consecutive authoritative snapshots and fire the matching sounds
  /// and celebrations: a token arriving home, a capture (sad sound), the win.
  void _announceDiff(GameState prev, GameState next) {
    if (prev.isFinished) return; // already over — nothing left to announce.

    var captured = false;
    var homeColor = LudoColor.values.first;
    var reachedHome = false;
    for (final p in next.players) {
      final c = p.color;
      int homes(GameState g) =>
          g.tokensOf(c).where((t) => t.isFinished).length;
      int based(GameState g) => g.tokensOf(c).where((t) => t.isInBase).length;
      if (homes(next) > homes(prev)) {
        reachedHome = true;
        homeColor = c;
      }
      if (based(next) > based(prev)) captured = true;
    }

    if (next.isFinished) {
      _audio.play(Sfx.win);
      return; // the WinnerOverlay is the celebration.
    }
    if (reachedHome) {
      _audio.play(Sfx.home);
      _celebrate(CelebrationKind.tokenHome, homeColor);
      return;
    }
    if (captured) {
      _audio.play(Sfx.capture);
      return;
    }
    // Plain move (anyone's): audible so the opponent's turns feel alive.
    final prevPos = {for (final t in prev.tokens) t.id: t.position};
    final moved = next.tokens
        .any((t) => prevPos.containsKey(t.id) && prevPos[t.id] != t.position);
    if (moved) _audio.play(Sfx.move);
  }

  void _onRealtimeEvent(RealtimeEvent ev) {
    if (!mounted) return;
    switch (ev.event) {
      case 'game.dice_rolled':
      case 'game.token_moved':
      case 'game.turn_changed':
      case 'game.ended':
      case 'game.player_reconnected':
      case 'game.player_disconnected':
        _refreshState();
        break;
      case 'chat.message':
        if (_ref.read(settingsControllerProvider).chat) {
          final myId = _ref.read(authControllerProvider).valueOrNull?.id;
          final mine =
              myId != null && ev.data['user_id']?.toString() == myId;
          final body = ev.data['body'] as String? ?? '';
          if (body.isEmpty) break;
          if (mine) {
            _ref.read(gameChatProvider.notifier).addLocal(body);
          } else {
            _ref.read(gameChatProvider.notifier).addRemote(
                  ev.data['name'] as String? ?? 'Player',
                  body,
                );
          }
        }
        break;
      case 'chat.emoji':
        if (_ref.read(settingsControllerProvider).emoji) {
          final emoji = ev.data['emoji'] as String? ?? '';
          if (emoji.isNotEmpty) {
            _ref.read(incomingEmojiProvider.notifier).state = emoji;
          }
        }
        break;
    }
  }

  // ---- response helpers ----------------------------------------------------

  /// Unwrap `{ "data": {...} }` (or a bare body) to the inner map.
  Map<String, dynamic> _payload(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) return inner.cast<String, dynamic>();
      return body.cast<String, dynamic>();
    }
    return const {};
  }

  Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : null;

  /// Pull the compact match `state` out of a MatchResource response.
  Map<String, dynamic>? _extractState(dynamic body) {
    final root = _payload(body);
    return _asMap(root['state']);
  }
}
