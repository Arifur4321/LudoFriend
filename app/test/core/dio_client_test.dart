import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/errors/exceptions.dart';
import 'package:ludo_friends/core/errors/failures.dart';
import 'package:ludo_friends/core/network/dio_client.dart';
import 'package:ludo_friends/core/storage/secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

class _MockStorage extends Mock implements SecureStorage {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  group('mapError — backend errors become clean, typed failures', () {
    test('401 -> AuthFailure', () {
      final f = DioClient.mapError(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(requestOptions: RequestOptions(path: ''), statusCode: 401),
        type: DioExceptionType.badResponse,
      ));
      expect(f, isA<AuthFailure>());
    });

    test('422 -> ValidationFailure with the server message + field errors', () {
      final f = DioClient.mapError(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 422,
          data: {
            'message': 'Invalid mode',
            'errors': {
              'mode': ['The selected mode is invalid.']
            }
          },
        ),
        type: DioExceptionType.badResponse,
      ));
      expect(f, isA<ValidationFailure>());
      expect(f.message, 'Invalid mode');
      expect((f as ValidationFailure).errors['mode'], contains('The selected mode is invalid.'));
    });

    test('a 5xx surfaces its message as a ServerFailure', () {
      final f = DioClient.mapError(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Boom'},
        ),
        type: DioExceptionType.badResponse,
      ));
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Boom');
    });

    test('a typed ApiException 401 also maps to AuthFailure', () {
      final f = DioClient.mapError(ApiException(401, 'nope'));
      expect(f, isA<AuthFailure>());
    });
  });

  test('the interceptor attaches the guest bearer token on every request',
      () async {
    final storage = _MockStorage();
    when(() => storage.token).thenAnswer((_) async => 'guest-bearer-123');

    final adapter = _MockAdapter();
    RequestOptions? captured;
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((inv) async {
      captured = inv.positionalArguments[0] as RequestOptions;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    });

    final client = DioClient(storage);
    client.dio.httpClientAdapter = adapter;

    await client.dio.get('/me');

    expect(captured, isNotNull);
    expect(captured!.headers['Authorization'], 'Bearer guest-bearer-123');
  });
}
