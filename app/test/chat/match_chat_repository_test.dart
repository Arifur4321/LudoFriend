import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/game/application/game_chat_state.dart';
import 'package:ludo_friends/features/game/data/match_chat_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// The transport contract the chat fixes rely on:
///  - the send RESPONSE carries the authoritative message so the sender's
///    bubble reconciles even when the Reverb echo is lost,
///  - emoji sends are throttled client-side before the server limiter,
///  - history rows parse identity, type, and timestamp for every login kind.
void main() {
  late _MockDio dio;

  Response<dynamic> ok(Map<String, dynamic> data) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: data,
      );

  setUp(() {
    dio = _MockDio();
  });

  group('sendMessage', () {
    test('returns the authoritative stored message from the response',
        () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => ok({
          'data': {
            'id': 41,
            'client_id': 'tap-1',
            'user_id': 7,
            'name': 'Me',
            'avatar': null,
            'color': 'red',
            'type': 'text',
            'body': 'hello',
            'ts': '2026-07-13T18:30:00+00:00',
          },
          'meta': {'duplicate': false},
        }),
      );

      final repo = MatchChatRepository(dio);
      final res = await repo.sendMessage('9', 'hello',
          clientId: 'tap-1', myUserId: '7');

      final msg = (res as Ok<ChatMessage>).value;
      expect(msg.id, 41);
      expect(msg.clientId, 'tap-1');
      expect(msg.isMe, isTrue);
      expect(msg.at, isNotNull);
    });

    test('an idempotent duplicate response still returns the stored message',
        () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => ok({
          'data': {
            'id': 41,
            'client_id': 'tap-1',
            'user_id': 7,
            'name': 'Me',
            'color': 'red',
            'type': 'text',
            'body': 'hello',
            'ts': '2026-07-13T18:30:00+00:00',
          },
          'meta': {'duplicate': true}, // retry of the same physical tap
        }),
      );

      final repo = MatchChatRepository(dio);
      final res = await repo.sendMessage('9', 'hello', clientId: 'tap-1');

      // Duplicate retries broadcast nothing, so THIS is what reconciles the
      // pending bubble — it must carry the same server id.
      expect((res as Ok<ChatMessage>).value.id, 41);
    });

    test('a transport failure surfaces as Err (bubble becomes retryable)',
        () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      final repo = MatchChatRepository(dio);
      final res = await repo.sendMessage('9', 'hello', clientId: 'tap-1');
      expect(res, isA<Err<ChatMessage>>());
    });

    test('exactly one HTTP request per send call', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => ok({
          'data': {'id': 1, 'type': 'text', 'body': 'x', 'name': 'Me'},
        }),
      );

      final repo = MatchChatRepository(dio);
      await repo.sendMessage('9', 'x', clientId: 'c1');

      verify(() => dio.post(any(), data: any(named: 'data'))).called(1);
    });
  });

  group('sendEmoji throttle', () {
    test('rapid taps inside the window send ONE request', () async {
      var now = DateTime(2026, 7, 13, 12, 0, 0);
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => ok({'data': {}}));

      final repo = MatchChatRepository(dio, clock: () => now);

      expect(await repo.sendEmoji('9', '🎉'), isA<Ok<bool>>());
      now = now.add(const Duration(milliseconds: 200));
      final second = await repo.sendEmoji('9', '🔥');
      now = now.add(const Duration(milliseconds: 200));
      final third = await repo.sendEmoji('9', '😂');

      expect((second as Ok<bool>).value, isFalse); // throttled locally
      expect((third as Ok<bool>).value, isFalse);
      verify(() => dio.post(any(), data: any(named: 'data'))).called(1);
    });

    test('a tap after the window sends again', () async {
      var now = DateTime(2026, 7, 13, 12, 0, 0);
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => ok({'data': {}}));

      final repo = MatchChatRepository(dio, clock: () => now);
      await repo.sendEmoji('9', '🎉');
      now = now.add(const Duration(milliseconds: 700));
      final second = await repo.sendEmoji('9', '🔥');

      expect((second as Ok<bool>).value, isTrue);
      verify(() => dio.post(any(), data: any(named: 'data'))).called(2);
    });
  });

  group('history', () {
    test('parses identity, emoji type, and timestamp for each row', () async {
      when(() => dio.get(any(),
          queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => ok({
          'data': [
            {
              'id': 1,
              'user_id': 7,
              'name': 'গেমার এক', // Bengali sender name
              'avatar': 'https://cdn.example/a.jpg',
              'color': 'red',
              'type': 'text',
              'body': 'নমস্কার 你好 🎉',
              'ts': '2026-07-13T18:00:00+00:00',
            },
            {
              'id': 2,
              'user_id': 8,
              'name': 'Guest 2',
              'color': 'green',
              'type': 'emoji',
              'body': '🔥',
              'ts': '2026-07-13T18:00:05+00:00',
            },
          ],
          'meta': {'has_more': false, 'next_before_id': null},
        }),
      );

      final repo = MatchChatRepository(dio);
      final res = await repo.history('9', myUserId: '7');
      final list = (res as Ok<List<ChatMessage>>).value;

      expect(list, hasLength(2));
      expect(list[0].isMe, isTrue);
      expect(list[0].text, 'নমস্কার 你好 🎉');
      expect(list[0].at, isNotNull);
      expect(list[1].isEmoji, isTrue);
      expect(list[1].isMe, isFalse);
      expect(list[1].sender, 'Guest 2');
    });
  });
}
