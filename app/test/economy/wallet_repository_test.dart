import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/wallet/data/wallet_models.dart';
import 'package:ludo_friends/features/wallet/data/wallet_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _res(Object data) =>
    Response(requestOptions: RequestOptions(path: ''), data: data, statusCode: 200);

void main() {
  late _MockDio dio;
  late WalletRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = WalletRepository(dio);
  });

  test('fetch returns a parsed snapshot', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _res({'coins': 500, 'recent': []}));

    final res = await repo.fetch();

    expect(res, isA<Ok<WalletSnapshot>>());
    expect((res as Ok<WalletSnapshot>).value.coins, 500);
  });

  test('fetch maps network errors to a Failure', () async {
    when(() => dio.get(any()))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    final res = await repo.fetch();

    expect(res, isA<Err<WalletSnapshot>>());
  });
}
