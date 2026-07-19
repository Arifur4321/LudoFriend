import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/room/data/room_models.dart';
import 'package:ludo_friends/features/room/data/room_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    );

Map<String, dynamic> _room({List<Map<String, dynamic>> players = const []}) => {
      'data': {
        'id': 7,
        'code': 'ABC123',
        'host_user_id': 1,
        'mode': '2p',
        'board_tier': 'casual',
        'status': 'lobby',
        'capacity': 2,
        'turn_timer_seconds': 20,
        'players': players,
      },
    };

void main() {
  late _MockDio dio;
  late RoomRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = RoomRepository(dio);
  });

  test('create sends the casual default board tier and the chosen mode',
      () async {
    Map<String, dynamic>? sent;
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((inv) async {
      sent = inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
      return _ok(_room());
    });

    final res = await repo.create(mode: '2p');

    expect(res, isA<Ok<RoomModel>>());
    expect(sent!['mode'], '2p');
    expect(sent!['board_tier'], 'casual'); // valid free default for guests
    expect(sent!['visibility'], 'private');
  });

  test('create success returns a room the lobby can open', () async {
    when(() => dio.post(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _ok(_room()));

    final room = (await repo.create(mode: '2p') as Ok<RoomModel>).value;

    expect(room.id, 7);
    expect(room.code, 'ABC123');
    expect(room.status, 'lobby');
  });

  test('a backend error is mapped to a clean failure with its message',
      () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 409,
          data: {'message': 'Room is full.'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final res = await repo.create(mode: '2p');
    expect(res, isA<Err<RoomModel>>());
    expect((res as Err<RoomModel>).failure.message, 'Room is full.');
  });

  test('join sends the room code in the body', () async {
    Map<String, dynamic>? sent;
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((inv) async {
      sent = inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
      return _ok(_room());
    });

    await repo.join('X9Y8Z7');
    expect(sent!['code'], 'X9Y8Z7');
  });

  group('player parsing (mixed login + bots)', () {
    test('a human seat renders its account name and guest flag', () {
      final p = RoomPlayerModel.fromJson({
        'seat': 0,
        'color': 'red',
        'is_bot': false,
        'is_ready': true,
        'display_name': 'Ignored When User Present',
        'user': {'id': 42, 'name': 'Aisha', 'avatar': null, 'is_guest': true},
      });

      expect(p.isBot, isFalse);
      expect(p.userId, 42);
      expect(p.name, 'Aisha');
      expect(p.isGuest, isTrue);
    });

    test('a bot seat renders its realistic display name (never "Bot")', () {
      final p = RoomPlayerModel.fromJson({
        'seat': 1,
        'color': 'green',
        'is_bot': true,
        'is_ready': true,
        'display_name': 'Rakib',
        // no `user` block for a bot
      });

      expect(p.isBot, isTrue);
      expect(p.userId, isNull);
      expect(p.name, 'Rakib');
      expect(p.name, isNot('Bot'));
    });

    test('mixed-login room data parses every seat', () {
      final room = RoomModel.fromJson(_room(players: [
        {
          'seat': 0, 'color': 'red', 'is_bot': false, 'is_ready': true,
          'user': {'id': 1, 'name': 'GuestHost', 'avatar': null, 'is_guest': true},
        },
        {
          'seat': 1, 'color': 'yellow', 'is_bot': false, 'is_ready': false,
          'user': {'id': 2, 'name': 'GoogleUser', 'avatar': 'http://x/y.png', 'is_guest': false},
        },
      ])['data'] as Map<String, dynamic>);

      expect(room.players, hasLength(2));
      expect(room.players[0].name, 'GuestHost');
      expect(room.players[0].isGuest, isTrue);
      expect(room.players[1].name, 'GoogleUser');
      expect(room.players[1].isGuest, isFalse);
    });
  });
}
