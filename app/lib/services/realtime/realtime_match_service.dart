import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import '../../core/utils/logger.dart';
import 'websocket_service.dart';

/// Subscribes to private Reverb/Pusher channels for rooms, live matches, and the
/// signed-in user's own channel, and exposes their events.
///
/// Private channels are authorised through Laravel's Sanctum-guarded
/// `/broadcasting/auth` endpoint: we send the connection's `socket_id` + the
/// channel name with the bearer token and forward the returned `auth` signature
/// to the WebSocket subscribe frame. Every method is defensive — if the socket
/// or auth fails (e.g. Reverb isn't running) it logs and no-ops rather than
/// throwing, so the rest of the app keeps working.
class RealtimeMatchService {
  RealtimeMatchService(this._ws, this._dio);

  final WebSocketService _ws;
  final Dio _dio;
  final Set<String> _joined = {};

  Stream<RealtimeEvent> get events => _ws.events;

  Future<void> joinMatch(int matchId) => _joinPrivate('match.$matchId');
  Future<void> joinRoom(int roomId) => _joinPrivate('room.$roomId');
  Future<void> joinUser(int userId) => _joinPrivate('user.$userId');

  Future<void> leaveMatch(int matchId) => _leave('match.$matchId');
  Future<void> leaveRoom(int roomId) => _leave('room.$roomId');

  Future<void> _joinPrivate(String name) async {
    final channel = 'private-$name';
    if (_joined.contains(channel)) return;

    try {
      await _ws.connect();
      final socketId = await _awaitSocketId();
      String? auth;
      if (socketId != null) {
        auth = await _authorize(socketId, channel);
      }
      await _ws.subscribe(channel, auth: auth);
      _joined.add(channel);
    } catch (e, st) {
      AppLogger.e('realtime join failed for $channel', e, st);
    }
  }

  Future<void> _leave(String name) async {
    final channel = 'private-$name';
    if (_joined.remove(channel)) {
      await _ws.unsubscribe(channel);
    }
  }

  Future<String?> _awaitSocketId() async {
    for (var i = 0; i < 50 && _ws.socketId == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _ws.socketId;
  }

  Future<String?> _authorize(String socketId, String channel) async {
    try {
      final res = await _dio.post(
        AppConfig.broadcastingAuthUrl,
        data: {'socket_id': socketId, 'channel_name': channel},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = res.data;
      if (data is Map && data['auth'] is String) {
        return data['auth'] as String;
      }
    } catch (e, st) {
      AppLogger.e('broadcasting/auth failed for $channel', e, st);
    }
    return null;
  }

  Future<void> leaveAll() async {
    for (final c in _joined) {
      await _ws.unsubscribe(c);
    }
    _joined.clear();
  }
}

final realtimeMatchServiceProvider = Provider<RealtimeMatchService>((ref) {
  return RealtimeMatchService(
    ref.watch(webSocketServiceProvider),
    ref.watch(dioProvider),
  );
});
