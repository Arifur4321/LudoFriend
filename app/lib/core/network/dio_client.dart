import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';

/// Configured [Dio] instance with auth, logging and error-normalising
/// interceptors. The bearer token is injected from secure storage on every
/// request, so screens never touch credentials directly.
class DioClient {
  DioClient(this._storage) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        AppLogger.d('→ ${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (e, handler) {
        AppLogger.e('✗ ${e.requestOptions.uri} :: ${e.message}');
        handler.next(e);
      },
    ));
  }

  final SecureStorage _storage;
  late final Dio dio;

  /// Maps a [DioException] to a typed [Failure].
  static Failure mapError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return const AuthFailure();
      if (error.statusCode == 422) {
        return ValidationFailure('Please check your input.', error.errors);
      }
      return ServerFailure(error.message);
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const TimeoutFailure();
        case DioExceptionType.connectionError:
          return const NetworkFailure();
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 500;
          final data = error.response?.data;
          final message = (data is Map && data['message'] is String)
              ? data['message'] as String
              : 'Request failed ($code).';
          if (code == 401) return const AuthFailure();
          if (code == 422) {
            final errs = <String, List<String>>{};
            if (data is Map && data['errors'] is Map) {
              (data['errors'] as Map).forEach((k, v) {
                errs['$k'] = (v as List).map((e) => '$e').toList();
              });
            }
            return ValidationFailure(message, errs);
          }
          return ServerFailure(message);
        default:
          return const UnknownFailure();
      }
    }
    return const UnknownFailure();
  }
}
