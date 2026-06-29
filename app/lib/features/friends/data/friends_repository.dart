import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

class FriendsRepository {
  FriendsRepository(this._dio);

  final Dio _dio;

  Future<Result<bool>> inviteFacebookFriend({
    required String facebookUserId,
    required String roomCode,
  }) async {
    try {
      await _dio.post(ApiEndpoints.invite, data: {
        'provider': 'facebook',
        'friend_id': facebookUserId,
        'room_code': roomCode,
      });
      return const Ok(true);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(dioProvider)),
);
