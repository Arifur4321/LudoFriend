import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
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
  MatchChatRepository(this._dio, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _clock;

  /// Client-side floor between emoji sends. The picker sheet closing after a
  /// tap is the primary throttle; this catches reopen-and-spam bursts before
  /// they even reach the server's `throttle:emoji` limiter.
  static const Duration _emojiMinInterval = Duration(milliseconds: 600);
  DateTime? _lastEmojiAt;

  /// POST the message and return the **authoritative stored message** from the
  /// response (never null on success). Applying this reconciles the sender's
  /// optimistic bubble even when the Reverb echo is lost — important because a
  /// retried duplicate send is answered idempotently WITHOUT a second
  /// broadcast, so the response is then the only carrier of the server id.
  Future<Result<ChatMessage>> sendMessage(
    String matchId,
    String body, {
    String? clientId,
    String? myUserId,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.chatMessage(matchId),
        data: {
          'body': body,
          if (clientId != null) 'client_id': clientId,
        },
      );
      final raw = res.data;
      final data = raw is Map ? raw['data'] : null;
      final msg = data is Map
          ? _parseMessage(data.cast<String, dynamic>(), myUserId: myUserId)
          : null;
      if (msg == null) {
        // Confirmed but unparseable: let the echo/history reconcile instead.
        return const Err(UnknownFailure());
      }
      return Ok(msg);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  /// Send an emoji reaction. Returns Ok(false) when locally throttled (the tap
  /// is deliberately dropped), Ok(true) when accepted by the server.
  Future<Result<bool>> sendEmoji(String matchId, String emoji) async {
    final now = _clock();
    final last = _lastEmojiAt;
    if (last != null && now.difference(last) < _emojiMinInterval) {
      return const Ok(false);
    }
    _lastEmojiAt = now;
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
          final msg =
              _parseMessage(item.cast<String, dynamic>(), myUserId: myUserId);
          if (msg != null) out.add(msg);
        }
      }
      return Ok(out);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  /// One shared shape for the send response and history rows
  /// (MatchMessageResource): id/client_id/user_id/name/avatar/color/type/body/ts.
  ChatMessage? _parseMessage(Map<String, dynamic> item, {String? myUserId}) {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return null;
    final uid = item['user_id']?.toString();
    final ts = item['ts'] as String?;
    return ChatMessage(
      id: id,
      clientId: item['client_id'] as String?,
      sender: (item['name'] as String?) ?? 'Player',
      avatarUrl: item['avatar'] as String?,
      color: item['color'] as String?,
      text: (item['body'] as String?) ?? '',
      isMe: myUserId != null && uid == myUserId,
      isEmoji: (item['type'] as String?) == 'emoji',
      at: ts == null ? null : DateTime.tryParse(ts)?.toLocal(),
      sortKey: id,
    );
  }
}

final matchChatRepositoryProvider = Provider<MatchChatRepository>(
  (ref) => MatchChatRepository(ref.watch(dioProvider)),
);
