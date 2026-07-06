import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import 'board_models.dart';

class BoardsRepository {
  BoardsRepository(this._dio);
  final Dio _dio;

  Future<Result<BoardsSnapshot>> list() async {
    try {
      final res = await _dio.get(ApiEndpoints.boards);
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      return Ok(BoardsSnapshot.fromJson(data));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final boardsRepositoryProvider =
    Provider<BoardsRepository>((ref) => BoardsRepository(ref.watch(dioProvider)));
