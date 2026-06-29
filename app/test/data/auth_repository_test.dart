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
  });

  test('successful guest login persists the token', () async {
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
}
