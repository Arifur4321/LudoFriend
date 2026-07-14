import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/di/providers.dart';
import 'package:ludo_friends/features/auth/application/auth_controller.dart';
import 'package:ludo_friends/features/auth/data/auth_user.dart';
import 'package:ludo_friends/features/game/application/game_config.dart';
import 'package:ludo_friends/features/game/application/game_controller.dart';
import 'package:ludo_friends/features/game/application/game_session.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/game_status.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/services/audio/audio_service.dart';
import 'package:ludo_friends/services/realtime/realtime_match_service.dart';
import 'package:ludo_friends/services/realtime/websocket_service.dart';

/// End-to-end (no widgets, no sockets) coverage of the online tap → request →
/// authoritative-state pipeline, driven through the REAL GameController with a
/// scripted in-memory server behind Dio. Pins every guarantee of the dice /
/// token-tap fix:
///
///   - one dice tap sends exactly one roll request; rapid taps never duplicate,
///   - a dice result of 1 enters token selection and the token is tappable,
///   - the fallback keeps a legal roll tappable even if `legal_moves` is lost,
///   - one token tap sends exactly one move request; rapid taps never duplicate,
///   - the token lands on the server-confirmed cell and never snaps back,
///   - stale polls / duplicate Reverb deliveries cannot overwrite newer state,
///   - a Reverb event landing mid-roll is applied right after (queued, not
///     dropped), so the board never waits a full poll cycle,
///   - after a rejected/failed move the forced resync restores the highlights,
///   - Facebook, Google, and guest players drive the identical pipeline.
void main() {
  group('online GameController', () {
    test('one dice tap sends exactly one roll request', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);

        expect(h.session.canRoll, isTrue);
        h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);

        h.controller.rollDice();
        h.pump(async);
        expect(h.api.rollRequests, 1);
        expect(h.api.rollBodies.single['color'], 'red');
        expect(h.api.rollBodies.single['action_id'], isNotEmpty);

        h.settleRoll(async);
        expect(h.session.game.status, GameStatus.awaitingMove);
        h.dispose(async);
      });
    });

    test('rapid dice taps do not create duplicate roll requests', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);

        // A burst of taps in the same frame + more while the roll is in
        // flight (the fat-finger / queued-gesture / auto-act race).
        h.controller.rollDice();
        h.controller.rollDice();
        h.controller.rollDice();
        h.pump(async);
        h.controller.rollDice();
        async.elapse(const Duration(milliseconds: 300));
        h.controller.rollDice();
        h.settleRoll(async);

        expect(h.api.rollRequests, 1,
            reason: 'exactly one roll request per physical turn');
        // After the dice-1 result the same player must pick a token, so even
        // later taps cannot roll again.
        h.controller.rollDice();
        h.pump(async);
        expect(h.api.rollRequests, 1);
        h.dispose(async);
      });
    });

    test('dice result 1 with a legal move enters token selection', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);

        h.controller.rollDice();
        h.settleRoll(async);

        expect(h.session.game.status, GameStatus.awaitingMove);
        expect(h.session.game.lastDice, 1);
        expect(h.session.game.pendingMovableTokenIds, ['red_0']);
        expect(h.session.canRoll, isFalse,
            reason: 'must not be asked to roll again');
        expect(h.session.banner, contains('tap a glowing pawn'));
        h.dispose(async);
      });
    });

    test(
        'dice 1 stays tappable even when the payload legal_moves is missing '
        '(fallback recomputes from the authoritative snapshot)', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.api.onRoll = (body) {
          final r = _rollResponseDiceOne(seq: 1);
          r.remove('legal_moves'); // transport lost/failed to encode the list
          return r;
        };

        h.controller.rollDice();
        h.settleRoll(async);

        expect(h.session.game.status, GameStatus.awaitingMove);
        expect(h.session.game.pendingMovableTokenIds, ['red_0'],
            reason: 'the legal 1-step move must be rebuilt locally');
        expect(h.session.canRoll, isFalse);

        // And the tap must actually go through.
        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        h.pump(async);
        expect(h.api.moveRequests, 1);
        h.settleMove(async);
        expect(h.tokenPosition('red_0'), 11);
        h.dispose(async);
      });
    });

    test('one token tap sends exactly one move request (with seq assert)', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async);

        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        h.pump(async);

        expect(h.api.moveRequests, 1);
        final body = h.api.moveBodies.single;
        expect(body['color'], 'red');
        expect(body['token'], 0);
        expect(body['action_id'], isNotEmpty);
        expect(body['seq'], 2,
            reason: 'client asserts the expected next seq (applied 1 + 1)');
        h.settleMove(async);
        h.dispose(async);
      });
    });

    test('rapid token taps do not create duplicate move requests', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async);

        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        h.controller.pickToken('red_0'); // double tap
        h.controller.pickToken('red_1'); // different pawn, same burst
        h.pump(async);
        h.controller.pickToken('red_0'); // while request in flight
        h.settleMove(async);

        expect(h.api.moveRequests, 1,
            reason: 'exactly one move request per physical tap');
        h.dispose(async);
      });
    });

    test('token stays on the server-confirmed cell — no snap-back', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async);
        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        async.flushMicrotasks();

        // While the walking animation runs, the session must expose exactly
        // what the board's animation layer consumes: isMoving + the stepped
        // path, with the underlying board still on the pre-move cell (the
        // overlay pawn walks; nothing teleports).
        expect(h.session.isMoving, isTrue);
        expect(h.session.lastMove?.movedTokenId, 'red_0');
        expect(h.session.lastMove?.path, [11]);
        expect(h.tokenPosition('red_0'), 10,
            reason: 'pre-move board stays visible under the walking overlay');

        // The state flips to the confirmed cell exactly when the walk ends.
        h.settleMove(async);
        expect(h.tokenPosition('red_0'), 11);
        expect(h.session.isMoving, isFalse);

        // A stale poll (pre-move snapshot, seq 1) later that turn must not
        // drag the pawn back to 10.
        h.api.stateData = _statePayload(
          _awaitingMoveDiceOne(seq: 1),
          legalMoves: const [
            {'token': 0, 'from': 10, 'to': 11},
          ],
        );
        async.elapse(const Duration(seconds: 2)); // recovery poll tick
        async.flushMicrotasks();
        expect(h.tokenPosition('red_0'), 11,
            reason: 'stale snapshot must be dropped by the seq gate');
        expect(h.session.game.currentColor, LudoColor.yellow);
        h.dispose(async);
      });
    });

    test('stale or duplicate Reverb refreshes cannot overwrite newer state',
        () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async);
        expect(h.session.game.pendingMovableTokenIds, ['red_0']);

        // The server is at seq 1 (awaiting our move). A duplicate Reverb
        // delivery triggers a refresh that returns the SAME seq — it must not
        // reset the phase, the dice, or the highlights.
        h.api.stateData = _statePayload(
          _awaitingMoveDiceOne(seq: 1),
          legalMoves: const [
            {'token': 0, 'from': 10, 'to': 11},
          ],
        );
        h.realtime.emit(_matchEvent('game.dice_rolled'));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        expect(h.session.game.status, GameStatus.awaitingMove);
        expect(h.session.game.pendingMovableTokenIds, ['red_0']);

        // An OLDER snapshot (seq 0, back to awaiting_roll) must be dropped.
        h.api.stateData = _statePayload(_awaitingRoll(seq: 0));
        h.realtime.emit(_matchEvent('game.turn_changed'));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        expect(h.session.game.status, GameStatus.awaitingMove,
            reason: 'an older seq can never roll the board back');
        expect(h.session.game.lastDice, 1);
        h.dispose(async);
      });
    });

    test('a Reverb event landing mid-roll is applied right after the roll',
        () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        final statesBefore = h.api.stateRequests;
        h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);

        h.controller.rollDice();
        async.flushMicrotasks();
        // Opponent-side event arrives while our roll owns the board: the
        // refresh must be QUEUED (not dropped) and run as soon as the roll
        // resolves — not a full poll period later.
        h.realtime.emit(_matchEvent('game.player_reconnected'));
        async.flushMicrotasks();
        expect(h.api.stateRequests, statesBefore,
            reason: 'refresh must not race the in-flight roll');

        h.api.stateData = _statePayload(
          _awaitingMoveDiceOne(seq: 1),
          legalMoves: const [
            {'token': 0, 'from': 10, 'to': 11},
          ],
        );
        h.settleRoll(async);
        h.pump(async);
        expect(h.api.stateRequests, greaterThan(statesBefore),
            reason: 'the queued refresh drains immediately after the roll');
        expect(h.session.game.pendingMovableTokenIds, ['red_0']);
        h.dispose(async);
      });
    });

    test('rejected move (422) resyncs and restores the tappable highlights',
        () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async);

        // The server refuses this move (e.g. an auto-act race) — the client
        // must resync and the legal token must become tappable again.
        h.api.moveStatus = 422;
        h.api.stateData = _statePayload(
          _awaitingMoveDiceOne(seq: 1),
          legalMoves: const [
            {'token': 0, 'from': 10, 'to': 11},
          ],
        );
        h.controller.pickToken('red_0');
        h.settleMove(async);
        h.pump(async);

        expect(h.session.isMoving, isFalse);
        expect(h.tokenPosition('red_0'), 10,
            reason: 'nothing committed — pawn stays on its pre-move cell');
        expect(h.session.game.pendingMovableTokenIds, ['red_0'],
            reason: 'forced resync must rebuild the highlights');

        // The retry tap now goes through.
        h.api.moveStatus = 200;
        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        h.pump(async);
        expect(h.api.moveRequests, 2);
        h.settleMove(async);
        expect(h.tokenPosition('red_0'), 11);
        h.dispose(async);
      });
    });

    test('Facebook, Google, and guest players drive the identical pipeline',
        () {
      final variants = <String, AuthUser>{
        'guest': const AuthUser(id: '11', name: 'Guest', isGuest: true),
        'google': const AuthUser(
            id: '12', name: 'G User', email: 'g@gmail.com', isGuest: false),
        'facebook': const AuthUser(
            id: '13', name: 'FB User', email: 'f@fb.com', isGuest: false),
      };

      final requestLog = <String, List<String>>{};
      for (final entry in variants.entries) {
        fakeAsync((async) {
          final h = _Harness(user: entry.value)..init(async);
          h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);
          h.controller.rollDice();
          h.settleRoll(async);
          expect(h.session.game.pendingMovableTokenIds, ['red_0']);

          h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
          h.controller.pickToken('red_0');
          h.settleMove(async);
          expect(h.tokenPosition('red_0'), 11);

          requestLog[entry.key] = [
            for (final r in h.api.requests) '${r.method} ${r.path}',
          ];
          expect(h.api.rollRequests, 1);
          expect(h.api.moveRequests, 1);
          h.dispose(async);
        });
      }

      // The request sequence must be byte-identical across login types: the
      // game layer never branches on how the player authenticated.
      expect(requestLog['google'], equals(requestLog['guest']));
      expect(requestLog['facebook'], equals(requestLog['guest']));
    });
  });
}

/* =========================================================================
 | Harness
 | ========================================================================= */

/// Scripted in-memory backend behind a real [Dio] instance.
class _FakeGameServer implements HttpClientAdapter {
  /// GET /matches/{id}/state payload (the inner `data` map).
  Map<String, dynamic> stateData = _statePayload(_awaitingRoll(seq: 0));

  Map<String, dynamic> Function(Map<String, dynamic> body)? onRoll;
  Map<String, dynamic> Function(Map<String, dynamic> body)? onMove;
  int rollStatus = 200;
  int moveStatus = 200;

  int rollRequests = 0;
  int moveRequests = 0;
  int stateRequests = 0;
  final List<Map<String, dynamic>> rollBodies = [];
  final List<Map<String, dynamic>> moveBodies = [];
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path;
    if (path.endsWith('/roll')) {
      rollRequests++;
      final body = (options.data as Map).cast<String, dynamic>();
      rollBodies.add(body);
      if (rollStatus != 200) {
        return _json({'message': 'It is not your turn.'}, rollStatus);
      }
      return _json({'data': onRoll!(body)}, 200);
    }
    if (path.endsWith('/move')) {
      moveRequests++;
      final body = (options.data as Map).cast<String, dynamic>();
      moveBodies.add(body);
      if (moveStatus != 200) {
        return _json(
            {'message': 'Illegal move for the current dice value.'},
            moveStatus);
      }
      return _json({'data': onMove!(body)}, 200);
    }
    if (path.endsWith('/state')) {
      stateRequests++;
      return _json({'data': stateData}, 200);
    }
    if (path.contains('/chat')) {
      return _json({'data': <dynamic>[]}, 200);
    }
    return _json({'data': <String, dynamic>{}}, 200);
  }

  ResponseBody _json(Map<String, dynamic> data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

class _SilentAudio implements AudioService {
  @override
  bool enabled = false;

  @override
  Future<void> play(Sfx sfx) async {}

  @override
  Future<void> click() async {}

  @override
  void dispose() {}
}

class _FakeRealtime implements RealtimeMatchService {
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast(sync: true);

  void emit(RealtimeEvent event) => _events.add(event);

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> joinMatch(int matchId) async {}

  @override
  Future<void> joinRoom(int roomId) async {}

  @override
  Future<void> joinUser(int userId) async {}

  @override
  Future<void> leaveMatch(int matchId) async {}

  @override
  Future<void> leaveRoom(int roomId) async {}

  @override
  Future<void> leaveAll() async {}

  @override
  void dispose() {
    _events.close();
  }
}

class _FakeWebSocket implements WebSocketService {
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast(sync: true);
  final StreamController<String> _connections =
      StreamController<String>.broadcast(sync: true);

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<String> get connections => _connections.stream;

  @override
  bool get isConnected => true;

  @override
  String? get socketId => 'test-socket';

  @override
  Future<void> connect() async {}

  @override
  Future<void> subscribe(String channel, {String? auth}) async {}

  @override
  Future<void> unsubscribe(String channel) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _events.close();
    _connections.close();
  }
}

class _StubAuth extends AuthController {
  _StubAuth(this._user);

  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _Harness {
  _Harness({AuthUser? user})
      : user = user ?? const AuthUser(id: '11', name: 'Me', isGuest: true) {
    final dio = Dio(BaseOptions(headers: {'Accept': 'application/json'}));
    dio.httpClientAdapter = api;
    realtime = _FakeRealtime();
    container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      audioServiceProvider.overrideWithValue(_SilentAudio()),
      realtimeMatchServiceProvider.overrideWithValue(realtime),
      webSocketServiceProvider.overrideWithValue(_FakeWebSocket()),
      authControllerProvider.overrideWith(() => _StubAuth(this.user)),
      gameConfigProvider.overrideWith((ref) => _onlineConfig()),
    ]);
  }

  final _FakeGameServer api = _FakeGameServer();
  final AuthUser user;
  late final _FakeRealtime realtime;
  late final ProviderContainer container;
  late final ProviderSubscription<GameSession> _keepAlive;

  GameController get controller =>
      container.read(gameControllerProvider.notifier);

  GameSession get session => container.read(gameControllerProvider);

  int tokenPosition(String id) => session.game.tokenById(id).position;

  /// Settle microtasks AND zero-delay timers (Dio defers some pipeline steps
  /// through `Future(...)`, which is a zero-duration Timer under fakeAsync).
  void pump(FakeAsync async) {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
    async.flushMicrotasks();
  }

  /// Build the controller and let `_initOnline` fully settle (bootstrap GET,
  /// chat history, recovery poll armed). The initial server state is red's
  /// awaiting_roll at seq 0 with red_0 on ring cell 10.
  void init(FakeAsync async) {
    _keepAlive = container.listen(gameControllerProvider, (_, __) {});
    pump(async);
    expect(session.game.currentColor, LudoColor.red);
    expect(session.game.status, GameStatus.waitingForRoll);
  }

  /// Roll a scripted dice-1-with-legal-move turn and settle the animation.
  void rollDiceOne(FakeAsync async) {
    api.onRoll = (body) => _rollResponseDiceOne(seq: 1);
    controller.rollDice();
    settleRoll(async);
    expect(session.game.pendingMovableTokenIds, ['red_0']);
  }

  /// Let the dice minimum animation (700ms) finish and microtasks settle.
  void settleRoll(FakeAsync async) {
    async.elapse(const Duration(milliseconds: 700));
    pump(async);
  }

  /// Let a 1-step walk animation (160ms + 60ms slack) finish, plus margin.
  void settleMove(FakeAsync async) {
    async.elapse(const Duration(milliseconds: 400));
    pump(async);
  }

  void dispose(FakeAsync async) {
    _keepAlive.close();
    container.dispose();
    async.flushMicrotasks();
  }
}

GameConfig _onlineConfig() => const GameConfig(
      mode: GameMode.online,
      players: [
        GamePlayer(color: LudoColor.red, name: 'Me'),
        GamePlayer(
            color: LudoColor.yellow, name: 'Them', kind: PlayerKind.remote),
      ],
      matchId: '7',
      myColor: 'red',
      autoMoveSingle: false,
    );

RealtimeEvent _matchEvent(String event) =>
    RealtimeEvent('private-match.7', event, const {});

/* =========================================================================
 | Scripted server payloads (mirror the Laravel response shapes)
 | ========================================================================= */

Map<String, dynamic> _tokens({List<int>? red, List<int>? yellow}) => {
      'red': red ?? [10, -1, -1, -1],
      'yellow': yellow ?? [5, -1, -1, -1],
    };

Map<String, dynamic> _awaitingRoll({
  required int seq,
  String turn = 'red',
  Map<String, dynamic>? tokens,
}) =>
    {
      'tokens': tokens ?? _tokens(),
      'turn': turn,
      'phase': 'awaiting_roll',
      'dice': null,
      'winner': null,
      'seq': seq,
    };

Map<String, dynamic> _awaitingMoveDiceOne({required int seq}) => {
      'tokens': _tokens(),
      'turn': 'red',
      'phase': 'awaiting_move',
      'dice': 1,
      'winner': null,
      'seq': seq,
    };

/// GET /state payload: MatchResource shape (state + top-level legal_moves).
Map<String, dynamic> _statePayload(
  Map<String, dynamic> state, {
  List<Map<String, dynamic>> legalMoves = const [],
}) =>
    {
      'id': 7,
      'state': state,
      'legal_moves': legalMoves,
    };

/// POST /roll response for a dice value of 1 with the single legal move.
Map<String, dynamic> _rollResponseDiceOne({required int seq}) => {
      'dice': 1,
      'forfeited': false,
      'turn_passed': false,
      'replayed': false,
      'legal_moves': [
        {'token': 0, 'from': 10, 'to': 11, 'captures': <int>[]},
      ],
      'state': _awaitingMoveDiceOne(seq: seq),
    };

/// POST /move response for red_0 walking exactly one step (10 → 11), turn
/// passing to yellow. `seq` is the final snapshot seq (move + turn events).
Map<String, dynamic> _moveResponseOneStep({required int seq}) => {
      'color': 'red',
      'token': 0,
      'from': 10,
      'to': 11,
      'path': [11],
      'move_seq': seq - 1,
      'captured': <Map<String, dynamic>>[],
      'finished': false,
      'extra_turn': false,
      'winner': null,
      'turn_passed': true,
      'replayed': false,
      'state': _awaitingRoll(
        seq: seq,
        turn: 'yellow',
        tokens: _tokens(red: [11, -1, -1, -1]),
      ),
    };
