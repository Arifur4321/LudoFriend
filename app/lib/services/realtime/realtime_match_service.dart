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
  RealtimeMatchService(this._ws, this._dio) {
    _connectionSub = _ws.connections.listen(_onConnected);
  }

  final WebSocketService _ws;
  final Dio _dio;
  final Set<String> _joined = {};
  final Set<String> _subscribing = {};
  final Map<String, Timer> _authRetries = {};
  late final StreamSubscription<String> _connectionSub;

  Stream<RealtimeEvent> get events => _ws.events;

  Future<void> joinMatch(int matchId) => _joinPrivate('match.$matchId');
  Future<void> joinRoom(int roomId) => _joinPrivate('room.$roomId');
  Future<void> joinUser(int userId) => _joinPrivate('user.$userId');

  Future<void> leaveMatch(int matchId) => _leave('match.$matchId');
  Future<void> leaveRoom(int roomId) => _leave('room.$roomId');

  Future<void> _joinPrivate(String name) async {
    final channel = 'private-$name';
    if (!_joined.add(channel)) return;

    await _subscribePrivate(channel);
  }

  Future<void> _subscribePrivate(String channel, {String? socketId}) async {
    if (!_joined.contains(channel) || !_subscribing.add(channel)) return;

    try {
      await _ws.connect();
      final currentSocketId = socketId ?? await _awaitSocketId();
      if (currentSocketId == null) {
        _scheduleAuthRetry(channel);
        return;
      }

      final auth = await _authorize(currentSocketId, channel);
      if (auth == null) {
        _scheduleAuthRetry(channel);
        return;
      }

      await _ws.subscribe(channel, auth: auth);
      _authRetries.remove(channel)?.cancel();
    } catch (e, st) {
      AppLogger.e('realtime join failed for $channel', e, st);
      _scheduleAuthRetry(channel);
    } finally {
      _subscribing.remove(channel);
    }
  }

  Future<void> _leave(String name) async {
    final channel = 'private-$name';
    if (_joined.remove(channel)) {
      _authRetries.remove(channel)?.cancel();
      await _ws.unsubscribe(channel);
    }
  }

  /// A private-channel signature is valid only for the socket id it was issued
  /// to. Re-authorize every active room/match/user subscription after the
  /// WebSocket reconnects so invites and turn events continue after a network
  /// switch or the app returning from the background.
  Future<void> _onConnected(String socketId) async {
    for (final channel in _joined.toList(growable: false)) {
      await _subscribePrivate(channel, socketId: socketId);
    }
  }

  void _scheduleAuthRetry(String channel) {
    if (!_joined.contains(channel)) return;
    _authRetries.remove(channel)?.cancel();
    _authRetries[channel] = Timer(const Duration(seconds: 3), () {
      _authRetries.remove(channel);
      _subscribePrivate(channel);
    });
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
    for (final timer in _authRetries.values) {
      timer.cancel();
    }
    _authRetries.clear();
  }

  void dispose() {
    _connectionSub.cancel();
    for (final timer in _authRetries.values) {
      timer.cancel();
    }
    _authRetries.clear();
  }
}

final realtimeMatchServiceProvider = Provider<RealtimeMatchService>((ref) {
  final service = RealtimeMatchService(
    ref.watch(webSocketServiceProvider),
    ref.watch(dioProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
