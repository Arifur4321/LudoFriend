import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import 'room_models.dart';

/// Talks to the backend room + match API so friends can create/join a real room
/// by code and start a shared, server-authoritative match.
class RoomRepository {
  RoomRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return (body['data'] as Map).cast<String, dynamic>();
    }
    return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<Result<RoomModel>> create({
    required String mode,
    String boardTier = 'casual',
    bool botFill = false,
    int turnTimer = 20,
    bool teamMode = false,
    String visibility = 'private',
  }) async {
    try {
      final res = await _dio.post(ApiEndpoints.rooms, data: {
        'mode': mode,
        'board_tier': boardTier,
        'bot_fill': botFill,
        'turn_timer_seconds': turnTimer,
        'team_mode': teamMode,
        'visibility': visibility,
      });
      return Ok(RoomModel.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<RoomModel>> join(String code) async {
    try {
      final res = await _dio.post(ApiEndpoints.joinRoom, data: {'code': code});
      return Ok(RoomModel.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<RoomModel>> show(int roomId) async {
    try {
      final res = await _dio.get(ApiEndpoints.roomById(roomId));
      return Ok(RoomModel.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<bool>> ready(int roomId, bool ready) async {
    try {
      await _dio.post(ApiEndpoints.readyRoom(roomId), data: {'ready': ready});
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<bool>> leave(int roomId) async {
    try {
      await _dio.post(ApiEndpoints.leaveRoom(roomId));
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<OnlineMatchModel>> start(int roomId) async {
    try {
      final res = await _dio.post(ApiEndpoints.startRoom(roomId));
      return Ok(OnlineMatchModel.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<OnlineMatchModel>> matchState(int matchId) async {
    try {
      final res = await _dio.get(ApiEndpoints.gameState('$matchId'));
      return Ok(OnlineMatchModel.fromJson(_data(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final roomRepositoryProvider =
    Provider<RoomRepository>((ref) => RoomRepository(ref.watch(dioProvider)));

/// The room the user is currently in (online lobby). Null when not in a room.
final activeRoomProvider = StateProvider<RoomModel?>((ref) => null);
