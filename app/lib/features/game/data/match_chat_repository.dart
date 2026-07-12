import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../application/game_chat_state.dart';

/// Sends in-match chat text and emoji reactions, and fetches recent history.
///
/// The server validates the sender is a participant, applies guest/profanity
/// rules, stores the message with an authoritative id, and broadcasts it to
/// everyone (including the sender) so the log is one de-duplicated stream. A
/// [clientId] makes a send idempotent against retries and rapid taps.
class MatchChatRepository {
  MatchChatRepository(this._dio);

  final Dio _dio;

  Future<Result<bool>> sendMessage(
    String matchId,
    String body, {
    String? clientId,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.chatMessage(matchId),
        data: {
          'body': body,
          if (clientId != null) 'client_id': clientId,
        },
      );
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

  /// Fetch a bounded, most-recent page of chat history (oldest → newest).
  /// [myUserId] lets each row be tagged as mine for right/left alignment.
  Future<Result<List<ChatMessage>>> history(
    String matchId, {
    String? myUserId,
    int limit = 30,
    int? beforeId,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.chatMessage(matchId),
        queryParameters: {
          'limit': limit,
          if (beforeId != null) 'before_id': beforeId,
        },
      );
      final raw = res.data;
      final list = (raw is Map ? raw['data'] : null);
      final out = <ChatMessage>[];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final id = (item['id'] as num?)?.toInt();
          if (id == null) continue;
          final uid = item['user_id']?.toString();
          out.add(ChatMessage(
            id: id,
            clientId: item['client_id'] as String?,
            sender: (item['name'] as String?) ?? 'Player',
            avatarUrl: item['avatar'] as String?,
            color: item['color'] as String?,
            text: (item['body'] as String?) ?? '',
            isMe: myUserId != null && uid == myUserId,
            isEmoji: (item['type'] as String?) == 'emoji',
            sortKey: id,
          ));
        }
      }
      return Ok(out);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final matchChatRepositoryProvider = Provider<MatchChatRepository>(
  (ref) => MatchChatRepository(ref.watch(dioProvider)),
);
