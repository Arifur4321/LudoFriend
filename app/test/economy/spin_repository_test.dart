import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/spin/data/spin_models.dart';
import 'package:ludo_friends/features/spin/data/spin_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _res(Object data) =>
    Response(requestOptions: RequestOptions(path: ''), data: data, statusCode: 200);

void main() {
  late _MockDio dio;
  late SpinRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = SpinRepository(dio);
  });

  test('spin returns the server-decided result', () async {
    when(() => dio.post(any()))
        .thenAnswer((_) async => _res({'reward': 2500, 'segment_index': 4, 'balance': 3000}));

    final res = await repo.spin();

    expect(res, isA<Ok<SpinResult>>());
    final r = (res as Ok<SpinResult>).value;
    expect(r.reward, 2500);
    expect(r.segmentIndex, 4);
    expect(r.balance, 3000);
  });

  test('spin surfaces a Failure on 422 (already claimed)', () async {
    when(() => dio.post(any())).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 422,
        data: {'message': 'Already claimed today.'},
      ),
    ));

    final res = await repo.spin();

    expect(res, isA<Err<SpinResult>>());
  });
}
