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
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/services/audio/audio_service.dart';
import 'package:ludo_friends/services/realtime/realtime_match_service.dart';
import 'package:ludo_friends/services/realtime/websocket_service.dart';

/// Coverage for the residual online-sync hardening:
///
///   - `isActionInFlight` is true exactly while a roll/move is pending, so the
///     turn-timer auto-act can never fire a second action on top of a manual one,
///   - a transport drop on a move (the request reached the server but the reply
///     was lost) recovers to the confirmed cell WITHOUT wedging isMoving and
///     without stranding the pawn on its old cell.
///
/// The harness mirrors game_controller_online_test.dart: the REAL GameController
/// with a scripted in-memory server behind Dio, driven under fakeAsync.
void main() {
  group('online sync hardening', () {
    test('isActionInFlight gates the turn-timer auto-act during a pending action',
        () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        expect(h.controller.isActionInFlight, isFalse,
            reason: 'idle on my awaiting-roll turn');

        h.api.onRoll = (body) => _rollResponseDiceOne(seq: 1);
        h.controller.rollDice();
        async.flushMicrotasks();
        expect(h.controller.isActionInFlight, isTrue,
            reason: 'a roll is in flight — the turn timer must not auto-act');

        h.settleRoll(async);
        expect(h.controller.isActionInFlight, isFalse,
            reason: 'awaiting_move, idle again — a manual tap may proceed');

        h.api.onMove = (body) => _moveResponseOneStep(seq: 3);
        h.controller.pickToken('red_0');
        async.flushMicrotasks();
        expect(h.controller.isActionInFlight, isTrue,
            reason: 'a move is in flight — the turn timer must not auto-act');

        h.settleMove(async);
        expect(h.controller.isActionInFlight, isFalse);
        h.dispose(async);
      });
    });

    test(
        'a transport drop on a move recovers to the confirmed cell without '
        'wedging or snapping back', () {
      fakeAsync((async) {
        final h = _Harness()..init(async);
        h.rollDiceOne(async); // red awaiting_move, dice 1, red_0 on cell 10

        // The move request is lost in transit; in reality the server committed
        // it, so the recovery GET /state returns the post-move snapshot.
        h.api.moveConnectionError = true;
        h.api.stateData = _statePayload(_awaitingRollYellow(seq: 3, red0: 11));

        h.controller.pickToken('red_0');
        h.settleMove(async);
        h.pump(async);

        // Converged on the confirmed destination (11) with the turn advanced —
        // the drop neither wedged the board in isMoving nor left the pawn on 10.
        expect(h.session.isMoving, isFalse);
        expect(h.tokenPosition('red_0'), 11);
        expect(h.session.game.currentColor, LudoColor.yellow);
        // The lock is released so the next turn can act.
        expect(h.controller.isActionInFlight, isFalse);
        h.dispose(async);
      });
    });
  });
}

/* =========================================================================
 | Harness (mirrors game_controller_online_test.dart)
 | ========================================================================= */

class _FakeGameServer implements HttpClientAdapter {
  Map<String, dynamic> stateData = _statePayload(_awaitingRoll(seq: 0));

  Map<String, dynamic> Function(Map<String, dynamic> body)? onRoll;
  Map<String, dynamic> Function(Map<String, dynamic> body)? onMove;
  int rollStatus = 200;
  int moveStatus = 200;

  /// When true, the next /move fails at the transport layer (connection drop)
  /// rather than returning an HTTP status.
  bool moveConnectionError = false;

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
      if (moveConnectionError) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'simulated network drop',
        );
      }
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

  void pump(FakeAsync async) {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
    async.flushMicrotasks();
  }

  void init(FakeAsync async) {
    _keepAlive = container.listen(gameControllerProvider, (_, __) {});
    pump(async);
  }

  void rollDiceOne(FakeAsync async) {
    api.onRoll = (body) => _rollResponseDiceOne(seq: 1);
    controller.rollDice();
    settleRoll(async);
    expect(session.game.pendingMovableTokenIds, ['red_0']);
  }

  void settleRoll(FakeAsync async) {
    async.elapse(const Duration(milliseconds: 700));
    pump(async);
  }

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

Map<String, dynamic> _awaitingRollYellow({required int seq, required int red0}) =>
    {
      'tokens': {
        'red': [red0, -1, -1, -1],
        'yellow': [5, -1, -1, -1],
      },
      'turn': 'yellow',
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

Map<String, dynamic> _statePayload(
  Map<String, dynamic> state, {
  List<Map<String, dynamic>> legalMoves = const [],
}) =>
    {
      'id': 7,
      'state': state,
      'legal_moves': legalMoves,
    };

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
