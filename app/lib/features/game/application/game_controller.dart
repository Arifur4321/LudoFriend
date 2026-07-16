import 'dart:async';

import 'package:dio/dio.dart';
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
  bool _refreshQueuedForce = false;
  final MatchStateGate _gate = MatchStateGate();
  StreamSubscription<RealtimeEvent>? _rtSub;
  StreamSubscription<String>? _wsConnSub;
  Timer? _statePoll;
  int _lastAnimatedMoveSequence = -1;
  int _rollActionSequence = 0;
  int _moveActionSequence = 0;

  /// When the last authoritative realtime (Reverb) event for THIS match was
  /// received. Drives adaptive recovery polling: while the socket is healthy and
  /// recently active we rely on events and skip the redundant poll; when it goes
  /// quiet or the socket drops we fall back to polling so a missed broadcast can
  /// never strand a player.
  DateTime? _lastRealtimeEventAt;

  /// Last authoritative snapshot applied in an online match, used to detect
  /// home-arrivals / captures / the win from state diffs so BOTH players get
  /// the same sounds + celebrations regardless of who moved.
  GameState? _lastSyncedGame;

  bool get _online => config.isOnline && config.matchId != null;

  AudioService get _audio => _ref.read(audioServiceProvider);

  /// True while a roll/move request is in flight or a local action is still
  /// animating. The turn-timer auto-act consults this so a timeout can never
  /// fire a second action on top of one the player already started (a manual
  /// move must always win the race against its own turn timer).
  bool get isActionInFlight => _busy || _gate.isSubmitting || state.isBusy;

  /// Whether the realtime channel is trustworthy enough to skip a recovery
  /// poll: the socket is connected AND an authoritative match event arrived
  /// within the last few seconds. When false (socket down or events quiet) the
  /// poll runs, so a missed broadcast can never strand a player.
  bool get _realtimeHealthy {
    final last = _lastRealtimeEventAt;
    if (last == null) return false;
    if (!_ref.read(webSocketServiceProvider).isConnected) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 6);
  }

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
    // Every step is individually guarded so one failing teardown can never
    // skip the rest — otherwise a single throw could leak the Reverb
    // subscription or leave the recovery timer running after the screen is
    // gone (the "ghost listener" that re-applies stale state).
    _rtSub?.cancel();
    _rtSub = null;
    _wsConnSub?.cancel();
    _wsConnSub = null;
    _statePoll?.cancel();
    _statePoll = null;
    if (_online) {
      try {
        final id = int.tryParse(config.matchId ?? '');
        if (id != null) {
          _ref.read(realtimeMatchServiceProvider).leaveMatch(id);
        }
      } catch (e, st) {
        AppLogger.e('leaveMatch during dispose failed', e, st);
      }
      try {
        _ref.read(currentMatchIdProvider.notifier).state = null;
        _ref.read(gameChatProvider.notifier).clear();
        _ref.read(emojiReactionsProvider.notifier).clear();
      } catch (e, st) {
        AppLogger.e('match-scope cleanup during dispose failed', e, st);
      }
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
    // Exactly ONE event listener per controller: cancel any earlier one first
    // so a re-entered init can never stack duplicate listeners.
    await _rtSub?.cancel();
    _rtSub = realtime.events.listen(_onRealtimeEvent);
    // After every WebSocket (re)connect, re-fetch the bounded chat history so
    // messages sent while this device was offline appear. The store
    // de-duplicates by server id, so however many reconnects happen, each
    // message shows exactly once — and this listener is the ONLY reconnect
    // hook, cancelled with the controller, so reconnects never stack extras.
    await _wsConnSub?.cancel();
    _wsConnSub = _ref.read(webSocketServiceProvider).connections.listen((_) {
      if (mounted) unawaited(_loadChatHistory());
    });
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
      // Exactly ONE recovery timer per match: never stack a second one.
      _statePoll?.cancel();
      // Adaptive recovery polling: the timer ticks on a fixed short cadence, but
      // each tick only hits the network when it needs to. While the Reverb
      // socket is connected and has delivered an event recently, the
      // event-driven refresh already keeps us current, so the redundant poll is
      // skipped. When the socket is down or events have gone quiet (a missed
      // broadcast, a backgrounded peer, a network switch), polling resumes so a
      // player is never stranded — the safety net stays, without hammering
      // GET /state while realtime is healthy.
      _statePoll = Timer.periodic(
        const Duration(seconds: 2),
        (_) {
          if (_realtimeHealthy) return;
          _refreshState();
        },
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

  /// Remember that a refresh was requested while one couldn't run right now.
  /// [force] is sticky: if ANY queued request needed a forced re-apply (error
  /// recovery), the drained refresh keeps it — dropping it used to leave the
  /// board without its token highlights after a failed roll/move, making a
  /// perfectly legal token (dice 1 included) un-tappable.
  void _queueRefresh({bool force = false}) {
    _refreshQueued = true;
    _refreshQueuedForce = _refreshQueuedForce || force;
  }

  /// Run the coalesced follow-up refresh as soon as nothing local owns the
  /// board anymore. Called when a refresh finishes AND when a roll/move
  /// resolves, so a Reverb event that landed mid-action is applied immediately
  /// instead of waiting for the next 2s recovery poll (the wait was the
  /// "dice/token needs several taps" stale window).
  void _drainQueuedRefresh() {
    if (!_refreshQueued || !mounted) return;
    if (_busy || state.isMoving || state.isRolling) return; // re-drained later
    _refreshQueued = false;
    final force = _refreshQueuedForce;
    _refreshQueuedForce = false;
    unawaited(_refreshState(force: force));
  }

  /// Fetch and apply the authoritative snapshot.
  ///
  /// [force] re-applies a snapshot even when its `seq` equals the one already
  /// applied. Error-recovery paths use it: after a failed roll/move the board
  /// may have lost derived UI state (token highlights, phase banner) that only
  /// a re-apply can rebuild — the gate still rejects anything *older*.
  Future<void> _refreshState({bool force = false}) async {
    // A local action owns the state while it runs: never let a recovery refresh
    // interrupt a roll (isRolling) or a move animation (isMoving), or race a
    // roll/move HTTP call (_busy). Coalesce bursts: if a refresh is already in
    // flight or an action owns the board, remember to run one afterwards so we
    // always converge on the newest snapshot after a flurry of Reverb events.
    if (!mounted) return;
    if (!force && (_busy || state.isMoving || state.isRolling)) {
      // Queue instead of dropping: this trigger (often a Reverb event for the
      // very state change the player is waiting on) is re-run the moment the
      // action/animation ends.
      _queueRefresh();
      return;
    }
    if (_refreshing) {
      _queueRefresh(force: force);
      return;
    }
    _refreshing = true;
    try {
      final res = await _ref
          .read(dioProvider)
          .get(ApiEndpoints.gameState(config.matchId!));
      if (!mounted) return;
      // A roll/move may have started while this fetch was in flight. The local
      // action owns the screen now — processing this (possibly pre-action)
      // snapshot would cancel its rolling/moving animation, so step aside and
      // let the action's own response (which always carries a newer seq) win.
      // The queued follow-up re-converges the moment the action resolves.
      if (!force && (_busy || state.isMoving || state.isRolling)) {
        _queueRefresh();
        return;
      }
      final payload = _payload(res.data);
      final serverState = _asMap(payload['state']);
      if (serverState == null) return;
      // Drop stale/duplicate/out-of-order snapshots up front, so a late poll can
      // neither replay an old move animation nor revert a newer turn/dice state.
      if (!_gate.shouldApply(_seqOf(serverState), allowEqual: force)) return;

      final movable = _movableFor(serverState, payload['legal_moves']);
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
      final applied =
          _applyServerState(serverState, movable: movable, force: force);
      if (!applied && (state.isMoving || state.isRolling)) {
        // The gate rejected this snapshot after its move animation already
        // started (something newer applied meanwhile). Drop the transient
        // overlay so the board can never stay wedged in isMoving/isRolling —
        // that wedge froze ALL dice/token input until the app restarted.
        state = state.copyWith(
          isMoving: false,
          isRolling: false,
          lastMove: null,
        );
      }
    } catch (e, st) {
      AppLogger.e('online state refresh failed', e, st);
    } finally {
      _refreshing = false;
      // Run the coalesced follow-up only when no local action has since taken
      // over; otherwise it is drained again when that action resolves.
      _drainQueuedRefresh();
    }
  }

  /// Movable token ids for [serverState], preferring the payload's
  /// authoritative `legal_moves` and falling back to a local recompute from
  /// the snapshot itself (mirrored rules) when the payload list is absent or
  /// unparseable while the phase says a move is pending. Guarantees a legal
  /// roll — 1 included — always yields tappable tokens on the owner's device.
  List<String> _movableFor(
      Map<String, dynamic> serverState, dynamic legalMoves) {
    final turn = serverState['turn'] as String?;
    if (turn == null || turn != config.myColor) return const [];
    final fromPayload = ServerStateAdapter.movableIds(turn, legalMoves);
    if (fromPayload.isNotEmpty) return fromPayload;
    return ServerStateAdapter.movableFromState(serverState,
        rules: config.rules);
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
    try {
      // Inside the try so a throwing audio backend can never leave _busy or the
      // submission lock stuck — that would silently swallow every later dice tap
      // for the rest of the match. endSubmission always runs in the finally.
      _audio.play(Sfx.dice);
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.rollDice(config.matchId!),
        data: {'color': config.myColor, 'action_id': actionId},
      );
      final data = _payload(res.data);
      final serverState = _asMap(data['state']);
      final movable = serverState == null
          ? const <String>[]
          : _movableFor(serverState, data['legal_moves']);
      final dice = (data['dice'] as num?)?.toInt();
      final forfeited = data['forfeited'] == true;
      final turnPassed = data['turn_passed'] == true;

      // Keep a real roll visible long enough for the player to perceive it,
      // even when the API responds faster than the animation can start.
      await minimumAnimation;
      if (!mounted) return;
      if (serverState != null) {
        final applied = _applyServerState(
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
        if (!applied) {
          // Should not happen (refreshes are fenced out while _busy), but if
          // the gate ever rejects the roll's own snapshot, never leave the
          // die spinning — resync to the authoritative truth instead.
          state = state.copyWith(isRolling: false);
          needsResync = true;
        } else if (state.game.status == GameStatus.awaitingMove &&
            state.game.currentPlayer.isHuman &&
            state.game.pendingMovableTokenIds.isEmpty) {
          // Inconsistent response: the server is awaiting OUR move but no
          // token could be derived as movable. Re-fetch rather than leaving
          // the player stranded with a wrong "roll again" prompt.
          needsResync = true;
        }
      } else {
        // Malformed/empty body: stop the dice animation but do NOT rebuild the
        // session from a pre-roll snapshot — that could paint state older than
        // what the gate has already applied. The forced resync below re-applies
        // the authoritative snapshot (same-seq allowed) and rebuilds the
        // token highlights/banner from the server's truth.
        state = state.copyWith(isRolling: false);
        needsResync = true;
      }
    } catch (e, st) {
      // The http status is logged explicitly so a hidden 401/422/429 (the exact
      // "silent" failures called out in the bug report) is visible on-device.
      AppLogger.e('online roll failed (http ${_httpStatus(e)})', e, st);
      await minimumAnimation;
      if (!mounted) return;
      // Whether this was a network drop (roll may or may not have committed)
      // or a 422 rejection (e.g. the turn-timer auto-roll won the race), the
      // server knows best: clear the transient flag and force a resync instead
      // of guessing with a locally-cached snapshot. (A roll moves no token, so
      // there is no position to preserve here — unlike a move.)
      state = state.copyWith(
        isRolling: false,
        banner: _httpStatus(e) == 429
            ? 'Server is busy — retrying in a moment…'
            : 'Connection interrupted — checking the game state…',
      );
      needsResync = true;
    } finally {
      _busy = false;
      _gate.endSubmission();
    }

    if (needsResync && mounted) {
      await _refreshState(force: true);
      if (!mounted) return;
      state = state.copyWith(
        banner: state.canRoll
            ? 'Roll was not confirmed — tap the dice once to retry.'
            : 'Connection restored — game state synchronized.',
      );
    }
    // A Reverb event may have arrived while this roll owned the board;
    // converge on it now instead of waiting for the next recovery poll.
    _drainQueuedRefresh();
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
    // Only a six ever grants a re-roll (existing rules). Any other value
    // with no legal move always passes the turn server-side, so claiming
    // "roll again" for it was wrong — with dice 1 it told the player to
    // roll while the server was still awaiting their move.
    if (dice == 6) return 'Rolled 6 — no legal move. Roll again!';
    return 'Rolled $dice — synchronizing…';
  }

  Future<void> _sendMove(String tokenId) async {
    // Same atomic re-entrancy lock as the dice: the first valid tap acquires
    // it; a rapid second tap on the same (or another) pawn, a queued gesture,
    // or the turn-timer auto-act firing simultaneously is ignored until this
    // move fully resolves — exactly one move request leaves the device per
    // tap. It also fences a token tap out while a roll is still in flight.
    if (!_gate.beginSubmission()) return;
    if (_busy || !state.game.pendingMovableTokenIds.contains(tokenId)) {
      _gate.endSubmission();
      return;
    }
    final originalGame = state.game;
    late final MoveApplication predictedApp;
    try {
      predictedApp = _engine.applyMove(originalGame, tokenId);
    } catch (e, st) {
      // An inconsistent snapshot (e.g. a movable token but no pending dice, so
      // `lastDice!` throws) must never leave the submission lock stuck — that
      // would swallow every later token tap for the rest of the match. Release
      // the lock and resync to the authoritative truth instead.
      AppLogger.e('online move preflight failed', e, st);
      _gate.endSubmission();
      if (mounted) unawaited(_refreshState(force: true));
      return;
    }
    final predicted = predictedApp.result;
    final predictedState = predictedApp.state;
    final parts = tokenId.split('_');
    final color = parts.isNotEmpty ? parts[0] : (config.myColor ?? '');
    final token = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    // One stable id per physical tap: if the transport retries this request,
    // the backend replays the first result instead of moving twice.
    final actionId = [
      config.matchId,
      color,
      token,
      DateTime.now().microsecondsSinceEpoch,
      _moveActionSequence++,
    ].join('-');
    _busy = true;
    state = state.copyWith(
      isMoving: true,
      lastMove: predicted,
      banner: null,
    );
    final minimumAnimation = Future<void>.delayed(
      _moveAnimationDuration(predicted),
    );
    var needsResync = false;
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.moveToken(config.matchId!),
        data: {
          'color': color,
          'token': token,
          'action_id': actionId,
          // Assert the expected next seq so a stale duplicate of this request
          // can never apply out of order server-side.
          if (_gate.appliedSeq >= 0) 'seq': _gate.appliedSeq + 1,
        },
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
        // The response's own movable set matters when the move grants an
        // extra turn only in the awaiting_roll sense; when the server stays in
        // awaiting_move for us (not a case today, but shape-proof) the
        // fallback recompute keeps the pawns tappable.
        final applied = _applyServerState(
          serverState,
          movable: _movableFor(serverState, data['legal_moves']),
        );
        if (!applied) {
          // Snapshot rejected as stale (should not happen — refreshes are
          // fenced while _busy): never leave the walking overlay on screen.
          state = state.copyWith(isMoving: false, lastMove: null);
          needsResync = true;
        }
      } else {
        // Confirmed-but-unparseable response: never repaint from the local
        // pre-move snapshot (that is exactly the walk-forward-then-snap-back
        // bug). Drop the animation overlay and let the forced resync render
        // the authoritative outcome.
        state = state.copyWith(isMoving: false, lastMove: null);
        needsResync = true;
      }
    } catch (e, st) {
      // Log the http status explicitly so a hidden 401/422/429 is visible.
      AppLogger.e('online move failed (http ${_httpStatus(e)})', e, st);
      await minimumAnimation;
      if (!mounted) return;
      if (_isTransportDrop(e)) {
        // Transport drop / timeout: the request very likely reached the server
        // and committed — only the reply was lost. Do NOT snap the token back
        // to its old cell (the "walk forward then jump back" bug, and a breach
        // of the "keep a stable visual state while resynchronizing" rule). Hold
        // it at the predicted destination; the forced resync confirms it (or,
        // if it never committed, corrects it once from authoritative truth). We
        // intentionally did NOT advance _lastAnimatedMoveSequence, so a fresh
        // last_move can still animate if needed.
        state = GameSession(
          game: predictedState,
          diceFace: state.diceFace,
          banner: 'Connection interrupted — checking the game state…',
        );
      } else {
        // A real server rejection (422 stale phase / illegal move, 403, 429
        // busy): the pre-move board is authoritative. Drop the overlay and let
        // the forced resync rebuild the token highlights so the player can act
        // again with no dead taps. (Behaviour unchanged from before.)
        state = state.copyWith(
          isMoving: false,
          lastMove: null,
          banner: _httpStatus(e) == 429
              ? 'Server is busy — retrying in a moment…'
              : 'Connection interrupted — checking the game state…',
        );
      }
      needsResync = true;
    } finally {
      _busy = false;
      _gate.endSubmission();
    }

    if (needsResync && mounted) {
      await _refreshState(force: true);
    }
    // Converge on any Reverb event that arrived while this move owned the
    // board, instead of waiting for the next recovery poll.
    _drainQueuedRefresh();
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

  /// Returns true when the snapshot passed the ordering gate and was applied;
  /// false when it was rejected as stale/duplicate (callers then clean up any
  /// transient animation flags they own — the game state itself is untouched).
  bool _applyServerState(
    Map<String, dynamic> serverState, {
    List<String> movable = const [],
    String? banner,
    int? displayedDice,
    bool force = false,
  }) {
    if (!mounted) return false;
    // Monotonic authoritative ordering: never let an older/duplicate snapshot
    // replace a newer one already on screen. This is what stops a late poll or a
    // re-delivered Reverb event from reverting a fresh roll and re-enabling the
    // dice. Authoritative HTTP roll/move responses always carry a newer seq, so
    // they still apply here. [force] additionally allows re-applying the SAME
    // seq (idempotent) so recovery can rebuild highlights/banners — an OLDER
    // snapshot is still always rejected.
    final incomingSeq = _seqOf(serverState);
    if (!_gate.shouldApply(incomingSeq, allowEqual: force)) return false;
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
    return true;
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
        // A fresh authoritative event means the socket is alive; record it so
        // adaptive polling can trust realtime for the next few seconds.
        _lastRealtimeEventAt = DateTime.now();
        _refreshState();
        break;
      case 'chat.message':
        if (_ref.read(settingsControllerProvider).chat) {
          final id = (ev.data['id'] as num?)?.toInt();
          final body = ev.data['body'] as String? ?? '';
          if (id == null || body.isEmpty) break;
          final myId = _ref.read(authControllerProvider).valueOrNull?.id;
          final ts = ev.data['ts'] as String?;
          // De-duplicated + reconciled with any optimistic bubble by the store.
          _ref.read(gameChatProvider.notifier).applyServer(
                id: id,
                clientId: ev.data['client_id'] as String?,
                sender: ev.data['name'] as String? ?? 'Player',
                avatarUrl: ev.data['avatar'] as String?,
                color: ev.data['color'] as String?,
                text: body,
                isMe: myId != null && ev.data['user_id']?.toString() == myId,
                at: ts == null ? null : DateTime.tryParse(ts)?.toLocal(),
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

  /// The HTTP status of a failed request, or null for a transport-level error
  /// (no response). Logged so a hidden 401/422/429 is visible on-device, and
  /// used to decide how to recover.
  int? _httpStatus(Object e) => e is DioException ? e.response?.statusCode : null;

  /// True when a failure is a transport drop / timeout (the request may well
  /// have reached the server and committed) rather than a definitive HTTP
  /// rejection. Only on a transport drop do we preserve the optimistic token
  /// position instead of reverting to the pre-move board.
  bool _isTransportDrop(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return true;
        default:
          // Any other Dio error without a response is also transport-level; one
          // that carries a response (4xx/5xx) is a real server rejection.
          return e.response == null;
      }
    }
    return false; // non-Dio throw → treat as a rejection (revert + resync).
  }
}
