import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

/// A friend as returned by the API — an internal user (Facebook app-friend or an
/// accepted friend), with an online flag driven by presence heartbeats.
class AppFriend {
  const AppFriend({
    required this.id,
    required this.name,
    this.avatar,
    this.isGuest = false,
    this.online = false,
  });

  final int id;
  final String name;
  final String? avatar;
  final bool isGuest;
  final bool online;

  factory AppFriend.fromJson(Map<String, dynamic> j) => AppFriend(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? 'Player',
        avatar: j['avatar'] as String?,
        isGuest: j['is_guest'] as bool? ?? false,
        online: j['online'] as bool? ?? false,
      );
}

class FriendsRepository {
  FriendsRepository(this._dio);

  final Dio _dio;

  /// Accepted friends (any provider / friend-code).
  Future<Result<List<AppFriend>>> list() => _fetch(ApiEndpoints.friends);

  /// Facebook friends who also play this app (mapped to internal users). Empty
  /// unless the account is Facebook-linked with the user_friends permission.
  Future<Result<List<AppFriend>>> facebookFriends() =>
      _fetch(ApiEndpoints.friendsFacebook);

  Future<Result<List<AppFriend>>> _fetch(String path) async {
    try {
      final res = await _dio.get(path);
      final data = (res.data is Map ? res.data['data'] : null) as List? ?? [];
      final friends = data
          .whereType<Map<String, dynamic>>()
          .map(AppFriend.fromJson)
          .toList(growable: false);
      return Ok(friends);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  /// Invite a friend to a room the caller is already seated in. Delivered to the
  /// friend's private channel as a "come play" notification.
  Future<Result<bool>> inviteToRoom({
    required int roomId,
    required int friendUserId,
  }) async {
    try {
      await _dio.post(ApiEndpoints.inviteToRoom, data: {
        'room_id': roomId,
        'friend_user_id': friendUserId,
      });
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  /// Add a friend by their share code (resolves to a user id server-side).
  Future<Result<bool>> addByCode(String code) async {
    try {
      await _dio.post(ApiEndpoints.friendsAccept, data: {'code': code});
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  /// Heartbeat so friends can see you online. Fire-and-forget.
  Future<void> presencePing() async {
    try {
      await _dio.post(ApiEndpoints.presencePing);
    } catch (_) {
      // Non-critical.
    }
  }
}

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(dioProvider)),
);
