import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import 'spin_models.dart';

class SpinRepository {
  SpinRepository(this._dio);
  final Dio _dio;

  Future<Result<SpinStatus>> status() async {
    try {
      final res = await _dio.get(ApiEndpoints.spinStatus);
      return Ok(SpinStatus.fromJson(_asMap(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<SpinResult>> spin() async {
    try {
      final res = await _dio.post(ApiEndpoints.spin);
      return Ok(SpinResult.fromJson(_asMap(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};
}

final spinRepositoryProvider =
    Provider<SpinRepository>((ref) => SpinRepository(ref.watch(dioProvider)));
