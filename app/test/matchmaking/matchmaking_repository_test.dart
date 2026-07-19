import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/matchmaking/data/matchmaking_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 201,
      data: {'data': data},
    );

void main() {
  late _MockDio dio;
  late MatchmakingRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = MatchmakingRepository(dio);
  });

  test('enqueue sends the chosen mode (2p and 4p)', () async {
    final sent = <Map<String, dynamic>>[];
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((inv) async {
      sent.add(inv.namedArguments[const Symbol('data')] as Map<String, dynamic>);
      return _ok({'ticket_id': 1, 'status': 'queued'});
    });

    await repo.enqueue('2p');
    await repo.enqueue('4p');

    expect(sent[0]['mode'], '2p');
    expect(sent[1]['mode'], '4p');
  });

  test('enqueue that matched immediately carries room + match ids', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => _ok({'ticket_id': 1, 'status': 'matched', 'room_id': 5, 'match_id': 9}),
    );

    final s = (await repo.enqueue('2p') as Ok<MatchmakingStatus>).value;

    expect(s.matched, isTrue);
    expect(s.roomId, 5);
    expect(s.matchId, 9);
  });

  test('a still-queued enqueue is not treated as matched', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => _ok({'ticket_id': 1, 'status': 'queued', 'room_id': null, 'match_id': null}),
    );

    final s = (await repo.enqueue('4p') as Ok<MatchmakingStatus>).value;
    expect(s.matched, isFalse);
    expect(s.status, 'queued');
  });

  test('status parses the match id once matched', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'data': {'status': 'matched', 'room_id': 3, 'room_code': 'ABC123', 'match_id': 8}
        },
      ),
    );

    final s = (await repo.status() as Ok<MatchmakingStatus>).value;
    expect(s.status, 'matched');
    expect(s.matchId, 8);
    expect(s.roomCode, 'ABC123');
  });

  test('cancel never throws even if the request fails', () async {
    when(() => dio.post(any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '')),
    );

    // Should complete without throwing (best-effort withdraw).
    await expectLater(repo.cancel(), completes);
  });
}
