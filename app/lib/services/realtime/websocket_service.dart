import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';

/// A realtime event delivered on a channel.
class RealtimeEvent {
  const RealtimeEvent(this.channel, this.event, this.data);
  final String channel;
  final String event;
  final Map<String, dynamic> data;
}

/// A clean WebSocket client that speaks the Pusher protocol, so it works
/// against Laravel Reverb, Soketi or laravel-websockets without a heavy plugin.
///
/// Features: connection handshake, (re)subscription, ping/pong keep-alive, and
/// automatic reconnect with backoff. Private channels are authorised by passing
/// the `auth` string obtained from the backend `/broadcasting/auth` endpoint.
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<String> _connections =
      StreamController<String>.broadcast();
  final Map<String, String?> _subscriptions = {}; // channel -> auth (nullable)

  String? _socketId;
  bool _connected = false;
  bool _connecting = false;
  int _retry = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<String> get connections => _connections.stream;
  bool get isConnected => _connected;
  String? get socketId => _socketId;

  Uri _endpoint() {
    const scheme = AppConfig.wsTls ? 'wss' : 'ws';
    return Uri.parse(
      '$scheme://${AppConfig.wsHost}:${AppConfig.wsPort}/app/${AppConfig.wsKey}'
      '?protocol=7&client=ludo-friends&version=1.0.0',
    );
  }

  Future<void> connect() async {
    if (_disposed || _connected || _connecting) return;
    _connecting = true;
    try {
      final channel = WebSocketChannel.connect(_endpoint());
      _channel = channel;
      channel.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );
    } catch (e, st) {
      _connecting = false;
      AppLogger.e('WS connect failed', e, st);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = msg['event'] as String? ?? '';
    final channel = msg['channel'] as String? ?? '';
    dynamic data = msg['data'];
    if (data is String && data.isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        // leave as raw string
      }
    }
    final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};

    switch (event) {
      case 'pusher:connection_established':
        _socketId = dataMap['socket_id'] as String?;
        _connected = true;
        _connecting = false;
        _retry = 0;
        AppLogger.d('WS connected (socket $_socketId)');
        if (_socketId != null) {
          // Private-channel auth signatures are tied to the socket id. The
          // realtime coordinator listens here and obtains fresh signatures
          // before resubscribing after every reconnect.
          _connections.add(_socketId!);
        }
        break;
      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': {}});
        break;
      case 'pusher:error':
        AppLogger.e('WS pusher error: $dataMap');
        break;
      default:
        _events.add(RealtimeEvent(channel, event, dataMap));
    }
  }

  void _onDone() {
    _connected = false;
    _connecting = false;
    _socketId = null;
    if (!_disposed) _scheduleReconnect();
  }

  void _onError(Object error, StackTrace st) {
    AppLogger.e('WS stream error', error, st);
    _connected = false;
    _connecting = false;
    _socketId = null;
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _retry = (_retry + 1).clamp(1, 6);
    final delay = Duration(seconds: _retry * 2); // 2s, 4s ... capped at 12s
    AppLogger.d('WS reconnect in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, connect);
  }

  /// Subscribe to [channel]. For private/presence channels, pass [auth] from
  /// the backend `/broadcasting/auth` response.
  Future<void> subscribe(String channel, {String? auth}) async {
    _subscriptions[channel] = auth;
    if (_connected) _sendSubscribe(channel, auth);
  }

  void _sendSubscribe(String channel, String? auth) {
    final data = <String, dynamic>{'channel': channel};
    if (auth != null) data['auth'] = auth;
    _send({'event': 'pusher:subscribe', 'data': data});
  }

  Future<void> unsubscribe(String channel) async {
    _subscriptions.remove(channel);
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channel},
    });
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e, st) {
      AppLogger.e('WS send failed', e, st);
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _subscriptions.clear();
    _connected = false;
    _connecting = false;
    _socketId = null;
    await _channel?.sink.close();
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _events.close();
    _connections.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});
