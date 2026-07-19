import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

class MatchmakingStatus {
  const MatchmakingStatus({
    required this.status,
    this.roomId,
    this.roomCode,
    this.matchId,
  });
  final String status; // none | queued | matched | cancelled
  final int? roomId;
  final String? roomCode;
  final int? matchId;

  bool get matched => status == 'matched' && roomId != null;

  factory MatchmakingStatus.fromJson(Map<String, dynamic> d) => MatchmakingStatus(
        status: d['status'] as String? ?? 'none',
        roomId: (d['room_id'] as num?)?.toInt(),
        roomCode: d['room_code'] as String?,
        matchId: (d['match_id'] as num?)?.toInt(),
      );
}

/// Random matchmaking against the backend FIFO queue. A solo queuer is paired
/// into a bot-filled room by the server sweep after a short wait, so you are
/// never stuck.
class MatchmakingRepository {
  MatchmakingRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(dynamic body) =>
      body is Map && body['data'] is Map
          ? (body['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

  /// Enqueue for [mode] ('2p' or '4p'). When a full human table was already
  /// waiting the ticket comes back already `matched` (with room + match ids),
  /// so the caller can navigate straight into the started match.
  Future<Result<MatchmakingStatus>> enqueue(String mode) async {
    try {
      final res = await _dio
          .post(ApiEndpoints.matchmakingEnqueue, data: {'mode': mode});
      return Ok(MatchmakingStatus.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<MatchmakingStatus>> status() async {
    try {
      final res = await _dio.get(ApiEndpoints.matchmakingStatus);
      return Ok(MatchmakingStatus.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<void> cancel() async {
    try {
      await _dio.post(ApiEndpoints.matchmakingCancel);
    } catch (_) {
      // Non-critical.
    }
  }
}

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>(
  (ref) => MatchmakingRepository(ref.watch(dioProvider)),
);
