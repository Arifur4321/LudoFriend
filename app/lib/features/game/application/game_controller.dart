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
import '../../../game_engine/models/move_result.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/realtime/realtime_match_service.dart';
import '../../../services/realtime/websocket_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../data/match_chat_repository.dart';
import 'celebration.dart';
import 'emoji_reactions.dart';
import 'game_chat_state.dart';
import 'game_config.dart';
import 'game_session.dart';
import 'match_state_gate.dart';
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
  bool _refreshing = false;
  bool _refreshQueued = false;
  final MatchStateGate _gate = MatchStateGate();
  StreamSubscription<RealtimeEvent>? _rtSub;
  Timer? _statePoll;
  int _lastAnimatedMoveSequence = -1;
  int _rollActionSequence = 0;

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
    _statePoll?.cancel();
    if (_online) {
      final id = int.tryParse(config.matchId ?? '');
      if (id != null) {
        _ref.read(realtimeMatchServiceProvider).leaveMatch(id);
      }
      _ref.read(currentMatchIdProvider.notifier).state = null;
      _ref.read(gameChatProvider.notifier).clear();
      _ref.read(emojiReactionsProvider.notifier).clear();
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

    await Future<void>.delayed(
      _moveAnimationDuration(result) + const Duration(milliseconds: 140),
    );
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
    // Start from a clean slate so a previous match's chat/emoji never leak in.
    _ref.read(gameChatProvider.notifier).clear();
    _ref.read(emojiReactionsProvider.notifier).clear();
    final realtime = _ref.read(realtimeMatchServiceProvider);
    _rtSub = realtime.events.listen(_onRealtimeEvent);
    final matchId = int.tryParse(config.matchId ?? '');
    if (matchId != null) {
      await realtime.joinMatch(matchId);
    }
    await _refreshState();
    await _loadChatHistory();
    // Realtime remains the fast path. This lightweight authoritative refresh
    // is the safety net for a dropped broadcast, a temporarily unavailable
    // Reverb worker, or a phone that switched networks while the opponent was
    // taking their turn. Without it, one missed event leaves the dice disabled
    // forever on the other device.
    if (mounted) {
      _statePoll = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _refreshState(),
      );
    }
  }

  /// One-shot recent-history restore so re-entering a match shows the last
  /// messages; de-duplicated by id against anything already live.
  Future<void> _loadChatHistory() async {
    final matchId = config.matchId;
    if (matchId == null) return;
    final myId = _ref.read(authControllerProvider).valueOrNull?.id;
    final res = await _ref
        .read(matchChatRepositoryProvider)
        .history(matchId, myUserId: myId);
    if (!mounted) return;
    res.when(
      ok: (msgs) => _ref.read(gameChatProvider.notifier).loadHistory(msgs),
      err: (_) {},
    );
  }

  Future<void> _refreshState() async {
    // A local action owns the state while it runs: never let a recovery refresh
    // interrupt a roll (isRolling) or a move animation (isMoving), or race a
    // roll/move HTTP call (_busy). Coalesce bursts: if a refresh is already in
    // flight, remember to run one more afterwards so we always converge on the
    // newest snapshot after a flurry of Reverb events.
    if (!mounted || _busy || state.isMoving || state.isRolling) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final res = await _ref
          .read(dioProvider)
          .get(ApiEndpoints.gameState(config.matchId!));
      if (!mounted) return;
      final payload = _payload(res.data);
      final serverState = _asMap(payload['state']);
      if (serverState == null) return;
      // Drop stale/duplicate/out-of-order snapshots up front, so a late poll can
      // neither replay an old move animation nor revert a newer turn/dice state.
      if (!_gate.shouldApply(_seqOf(serverState))) return;

      final turn = serverState['turn'] as String?;
      final movable = turn != null && turn == config.myColor
          ? ServerStateAdapter.movableIds(turn, payload['legal_moves'])
          : const <String>[];
      final lastMove = _moveFromState(serverState);
      if (_lastSyncedGame == null) {
        if (lastMove?.sequence != null) {
          _lastAnimatedMoveSequence = lastMove!.sequence!;
        }
      } else if (lastMove != null &&
          lastMove.sequence != null &&
          lastMove.sequence! > _lastAnimatedMoveSequence &&
          _canAnimateFromCurrentState(lastMove)) {
        _lastAnimatedMoveSequence = lastMove.sequence!;
        await _playMoveAnimation(lastMove);
        if (!mounted) return;
      } else if (lastMove?.sequence != null) {
        _lastAnimatedMoveSequence = lastMove!.sequence!;
      }
      _applyServerState(serverState, movable: movable);
    } catch (e, st) {
      AppLogger.e('online state refresh failed', e, st);
    } finally {
      _refreshing = false;
      // Run the coalesced follow-up only when no local action has since taken
      // over, so recovery never fights an in-progress roll/move.
      if (_refreshQueued) {
        _refreshQueued = false;
        if (mounted && !_busy && !state.isMoving && !state.isRolling) {
          unawaited(_refreshState());
        }
      }
    }
  }

  Future<void> _sendRoll() async {
    // Atomic re-entrancy lock: the first valid tap acquires it; any further tap
    // (fat-finger double tap, a queued gesture, or the turn-timer auto-act
    // firing at the same instant) is ignored until this roll fully resolves, so
    // exactly one roll request leaves the device per turn.
    if (!_gate.beginSubmission()) return;
    if (_busy || !state.canRoll || config.myColor == null) {
      _gate.endSubmission();
      return;
    }
    final original = state;
    final actionId = [
      config.matchId,
      config.myColor,
      DateTime.now().microsecondsSinceEpoch,
      _rollActionSequence++,
    ].join('-');
    final minimumAnimation = Future<void>.delayed(AppConstants.diceRoll);
    var needsResync = false;
    _busy = true;
    state = state.copyWith(isRolling: true, banner: null);
    _audio.play(Sfx.dice);
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.rollDice(config.matchId!),
        data: {'color': config.myColor, 'action_id': actionId},
      );
      final data = _payload(res.data);
      final serverState = _asMap(data['state']);
      final movable = ServerStateAdapter.movableIds(
          config.myColor ?? '', data['legal_moves']);
      final dice = (data['dice'] as num?)?.toInt();
      final forfeited = data['forfeited'] == true;
      final turnPassed = data['turn_passed'] == true;

      // Keep a real roll visible long enough for the player to perceive it,
      // even when the API responds faster than the animation can start.
      await minimumAnimation;
      if (!mounted) return;
      if (serverState != null) {
        _applyServerState(
          serverState,
          movable: movable,
          banner: _onlineRollBanner(
            dice: dice,
            forfeited: forfeited,
            turnPassed: turnPassed,
            hasLegalMoves: movable.isNotEmpty,
          ),
          displayedDice: turnPassed ? null : dice,
        );
      } else {
        state = GameSession(
          game: original.game,
          diceFace: original.diceFace,
          lastMove: original.lastMove,
          banner: 'Roll was not confirmed — tap the dice once to retry.',
        );
        needsResync = true;
      }
    } catch (e, st) {
      AppLogger.e('online roll failed', e, st);
      await minimumAnimation;
      if (!mounted) return;
      state = GameSession(
        game: original.game,
        diceFace: original.diceFace,
        lastMove: original.lastMove,
        banner: 'Connection interrupted — checking the game state…',
      );
      needsResync = true;
    } finally {
      _busy = false;
      _gate.endSubmission();
    }

    if (needsResync && mounted) {
      await _refreshState();
      if (!mounted) return;
      state = state.copyWith(
        banner: state.canRoll
            ? 'Roll was not confirmed — tap the dice once to retry.'
            : 'Connection restored — game state synchronized.',
      );
    }
  }

  String _onlineRollBanner({
    required int? dice,
    required bool forfeited,
    required bool turnPassed,
    required bool hasLegalMoves,
  }) {
    if (forfeited) return 'Three sixes — turn skipped!';
    if (dice == null) return 'Dice rolled.';
    if (hasLegalMoves) return 'Rolled $dice — tap a glowing pawn.';
    if (turnPassed) return 'Rolled $dice — no legal move. Turn passed.';
    return 'Rolled $dice — no legal move. Roll again!';
  }

  Future<void> _sendMove(String tokenId) async {
    if (_busy || !state.game.pendingMovableTokenIds.contains(tokenId)) return;
    final originalGame = state.game;
    final predicted = _engine.applyMove(originalGame, tokenId).result;
    final parts = tokenId.split('_');
    final color = parts.isNotEmpty ? parts[0] : (config.myColor ?? '');
    final token = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    _busy = true;
    state = state.copyWith(
      isMoving: true,
      lastMove: predicted,
      banner: null,
    );
    final minimumAnimation = Future<void>.delayed(
      _moveAnimationDuration(predicted),
    );
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.moveToken(config.matchId!),
        data: {'color': color, 'token': token},
      );
      final data = _payload(res.data);
      final serverState = _asMap(data['state']);
      final serverMove = MoveResult.fromServer(data, fallbackTokenId: tokenId);
      await minimumAnimation;
      if (!mounted) return;
      if (serverMove.sequence != null) {
        _lastAnimatedMoveSequence = serverMove.sequence!;
      }
      if (serverState != null) {
        // Sounds/celebrations (capture, home, win) come from the state diff in
        // _applyServerState, so they fire identically for every player.
        _applyServerState(serverState);
      } else {
        state = GameSession(
          game: originalGame,
          diceFace: originalGame.lastDice,
          banner: 'Could not confirm the move — tap the pawn again.',
        );
      }
    } catch (e, st) {
      AppLogger.e('online move failed', e, st);
      state = GameSession(
        game: originalGame,
        diceFace: originalGame.lastDice,
        banner: 'Move failed — tap the pawn again.',
      );
    } finally {
      _busy = false;
    }
  }

  MoveResult? _moveFromState(Map<String, dynamic> serverState) {
    final raw = _asMap(serverState['last_move']);
    if (raw == null) return null;
    final color = raw['color'] as String?;
    final token = (raw['token'] as num?)?.toInt();
    if (color == null || token == null) return null;
    return MoveResult.fromServer(
      raw,
      fallbackTokenId: '${color}_$token',
    );
  }

  bool _canAnimateFromCurrentState(MoveResult move) {
    for (final token in state.game.tokens) {
      if (token.id == move.movedTokenId) {
        return token.position == move.fromPosition;
      }
    }
    return false;
  }

  Duration _moveAnimationDuration(MoveResult move) {
    final forwardSteps = move.path.isEmpty ? 1 : move.path.length;
    return AppConstants.tokenStep * forwardSteps +
        AppConstants.capturedTokenStep * move.maxCapturedReturnSteps +
        const Duration(milliseconds: 60);
  }

  Future<void> _playMoveAnimation(MoveResult move) async {
    state = state.copyWith(isMoving: true, lastMove: move, banner: null);
    await Future<void>.delayed(_moveAnimationDuration(move));
  }

  void _applyServerState(
    Map<String, dynamic> serverState, {
    List<String> movable = const [],
    String? banner,
    int? displayedDice,
  }) {
    if (!mounted) return;
    // Monotonic authoritative ordering: never let an older/duplicate snapshot
    // replace a newer one already on screen. This is what stops a late poll or a
    // re-delivered Reverb event from reverting a fresh roll and re-enabling the
    // dice. Authoritative HTTP roll/move responses always carry a newer seq, so
    // they still apply here.
    final incomingSeq = _seqOf(serverState);
    if (!_gate.shouldApply(incomingSeq)) return;
    _gate.markApplied(incomingSeq);
    final game = ServerStateAdapter.toGameState(
      serverState: serverState,
      players: config.players,
      rules: config.rules,
      movableTokenIds: movable,
    );
    final prev = _lastSyncedGame;
    _lastSyncedGame = game;
    state = GameSession(
      game: game,
      diceFace: displayedDice ?? game.lastDice,
      banner: banner,
    );
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
      int homes(GameState g) => g.tokensOf(c).where((t) => t.isFinished).length;
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
    if (ev.channel != 'private-match.${config.matchId}') return;
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
          final id = (ev.data['id'] as num?)?.toInt();
          final body = ev.data['body'] as String? ?? '';
          if (id == null || body.isEmpty) break;
          final myId = _ref.read(authControllerProvider).valueOrNull?.id;
          // De-duplicated + reconciled with any optimistic bubble by the store.
          _ref.read(gameChatProvider.notifier).applyServer(
                id: id,
                clientId: ev.data['client_id'] as String?,
                sender: ev.data['name'] as String? ?? 'Player',
                avatarUrl: ev.data['avatar'] as String?,
                color: ev.data['color'] as String?,
                text: body,
                isMe: myId != null && ev.data['user_id']?.toString() == myId,
              );
        }
        break;
      case 'chat.emoji':
        if (_ref.read(settingsControllerProvider).emoji) {
          final id = ev.data['id'] as String?;
          final emoji = ev.data['emoji'] as String? ?? '';
          if (id != null && id.isNotEmpty && emoji.isNotEmpty) {
            // De-duplicated by id so a re-delivered event never plays twice.
            _ref.read(emojiReactionsProvider.notifier).add(EmojiReaction(
                  id: id,
                  emoji: emoji,
                  sender: ev.data['name'] as String? ?? '',
                  color: ev.data['color'] as String?,
                ));
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

  /// The authoritative monotonic sequence stamped on a server snapshot, or null
  /// if absent (older payloads / unexpected shapes — the gate then fails open).
  int? _seqOf(Map<String, dynamic> serverState) {
    final raw = serverState['seq'];
    return raw is num ? raw.toInt() : null;
  }
}
