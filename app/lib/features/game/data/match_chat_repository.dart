import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

/// Sends in-match chat text and emoji reactions. The server validates the
/// sender is a participant, applies guest/profanity rules, and broadcasts the
/// message to everyone (including the sender) so the log is one stream.
class MatchChatRepository {
  MatchChatRepository(this._dio);

  final Dio _dio;

  Future<Result<bool>> sendMessage(String matchId, String body) async {
    try {
      await _dio.post(ApiEndpoints.chatMessage(matchId), data: {'body': body});
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<bool>> sendEmoji(String matchId, String emoji) async {
    try {
      await _dio.post(ApiEndpoints.chatEmoji(matchId), data: {'emoji': emoji});
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final matchChatRepositoryProvider = Provider<MatchChatRepository>(
  (ref) => MatchChatRepository(ref.watch(dioProvider)),
);
