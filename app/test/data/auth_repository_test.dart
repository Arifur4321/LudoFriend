import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/core/storage/secure_storage.dart';
import 'package:ludo_friends/features/auth/data/auth_repository.dart';
import 'package:ludo_friends/features/auth/data/auth_user.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements SecureStorage {}

void main() {
  late _MockDio dio;
  late _MockStorage storage;
  late AuthRepository repo;

  setUp(() {
    dio = _MockDio();
    storage = _MockStorage();
    repo = AuthRepository(dio, storage);
    when(() => storage.saveToken(any())).thenAnswer((_) async {});
    when(() => storage.guestId).thenAnswer((_) async => 'device-test');
    when(() => storage.saveGuestId(any())).thenAnswer((_) async {});
    when(() => storage.saveCachedUser(any())).thenAnswer((_) async {});
    when(() => storage.clearCachedUser()).thenAnswer((_) async {});
  });

  test('guest falls back to a local guest when the backend is unreachable',
      () async {
    when(() => dio.post(any(), data: any(named: 'data')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    final res = await repo.guest(name: 'Tester');

    expect(res, isA<Ok<AuthUser>>());
    final user = (res as Ok<AuthUser>).value;
    expect(user.isGuest, isTrue);
    expect(user.name, 'Tester');
    expect(user.token, isNull); // purely local, no token
    verify(() => storage.guestId).called(1);
  });

  test('guest login surfaces a server error instead of a token-less guest',
      () async {
    // Regression guard for the original bug: a 5xx from /auth/guest must NOT be
    // swallowed into a fake local "success" (which then had no bearer token and
    // failed every authenticated call like create-room). It must surface.
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Server Error'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final res = await repo.guest(name: 'Tester');

    expect(res, isA<Err<AuthUser>>());
    verifyNever(() => storage.saveToken(any()));
  });

  test('successful guest login sends device id and persists the token',
      () async {
    final captured = <Map<String, dynamic>>[];
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'user': {'id': 1, 'name': 'Tester', 'is_guest': true},
          'token': 'tok123',
        },
      ),
    );

    final res = await repo.guest(name: 'Tester');
    final user = (res as Ok<AuthUser>).value;

    expect(user.token, 'tok123');
    verify(() => dio.post(any(), data: captureAny(named: 'data')))
        .captured
        .cast<Map<String, dynamic>>()
        .forEach(captured.add);
    expect(captured.single['device_id'], 'device-test');
    expect(captured.single['guest_name'], 'Tester');
    verify(() => storage.saveToken('tok123')).called(1);
  });

  test('login maps a 401 to an auth failure', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response:
            Response(requestOptions: RequestOptions(path: ''), statusCode: 401),
        type: DioExceptionType.badResponse,
      ),
    );

    final res = await repo.login('a@b.c', 'secret');
    expect(res, isA<Err<AuthUser>>());
  });

  group('restoreSession — automatic login on app start', () {
    setUp(() {
      when(() => storage.saveCachedUser(any())).thenAnswer((_) async {});
      when(() => storage.clearCachedUser()).thenAnswer((_) async {});
      when(() => storage.clearToken()).thenAnswer((_) async {});
    });

    test('returns null (login screen) when no token is stored', () async {
      when(() => storage.token).thenAnswer((_) async => null);

      expect(await repo.restoreSession(), isNull);
      verifyNever(() => dio.get(any()));
    });

    test('a valid stored token restores the session without any login',
        () async {
      when(() => storage.token).thenAnswer((_) async => 'tok123');
      when(() => dio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'data': {
              'id': 42,
              'name': 'FB Player',
              'is_guest': false,
              'avatar': 'https://cdn.example/a.jpg',
            },
          },
        ),
      );

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.id, '42');
      expect(user.name, 'FB Player');
      expect(user.avatarUrl, 'https://cdn.example/a.jpg');
      // The token itself must remain stored — no re-login required.
      verifyNever(() => storage.clearToken());
      // The fresh identity is cached for offline restoration next time.
      verify(() => storage.saveCachedUser(any())).called(1);
    });

    test('an expired/rejected token (401) is cleared safely', () async {
      when(() => storage.token).thenAnswer((_) async => 'expired');
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
              requestOptions: RequestOptions(path: ''), statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(await repo.restoreSession(), isNull);
      verify(() => storage.clearToken()).called(1);
      verify(() => storage.clearCachedUser()).called(1);
    });

    test('a network outage does NOT log the user out — cached user restores',
        () async {
      when(() => storage.token).thenAnswer((_) async => 'tok123');
      when(() => storage.cachedUser).thenAnswer(
        (_) async => '{"id":"42","name":"FB Player","is_guest":false}',
      );
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.id, '42');
      // Crucially the token survives, so the session heals when back online.
      verifyNever(() => storage.clearToken());
    });

    test('network outage with no cached user shows login but keeps the token',
        () async {
      when(() => storage.token).thenAnswer((_) async => 'tok123');
      when(() => storage.cachedUser).thenAnswer((_) async => null);
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(await repo.restoreSession(), isNull);
      verifyNever(() => storage.clearToken());
    });
  });

  group('logout', () {
    test('clears both the token and the cached user', () async {
      when(() => dio.post(any())).thenAnswer(
        (_) async => Response(
            requestOptions: RequestOptions(path: ''), statusCode: 200),
      );
      when(() => storage.clearToken()).thenAnswer((_) async {});
      when(() => storage.clearCachedUser()).thenAnswer((_) async {});

      await repo.logout();

      verify(() => storage.clearToken()).called(1);
      verify(() => storage.clearCachedUser()).called(1);
    });
  });
}
