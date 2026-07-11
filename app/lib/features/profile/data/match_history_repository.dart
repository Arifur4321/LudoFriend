import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/application/auth_controller.dart';

/// A real human the signed-in user has played with recently — derived from
/// match history so they can be invited again with one tap.
class RecentPlayer {
  const RecentPlayer({required this.id, required this.name, this.avatar});

  final int id;
  final String name;
  final String? avatar;
}

/// Reads GET /profile/matches and distills the recent, distinct human opponents
/// (excluding self, bots and guests) so the profile screen can offer a quick
/// "play again" re-invite.
class MatchHistoryRepository {
  MatchHistoryRepository(this._dio);

  final Dio _dio;

  Future<Result<List<RecentPlayer>>> recentPlayers({
    required int? meId,
    int max = 12,
  }) async {
    try {
      final res = await _dio.get(ApiEndpoints.matchHistory);
      final body = res.data;
      final matches =
          (body is Map && body['data'] is List) ? body['data'] as List : const [];

      final seen = <int>{};
      final out = <RecentPlayer>[];
      for (final m in matches) {
        if (m is! Map) continue;
        final players = m['players'];
        if (players is! List) continue;
        for (final p in players) {
          if (p is! Map) continue;
          if (p['is_bot'] == true || p['is_guest'] == true) continue;
          final uid = (p['user_id'] as num?)?.toInt();
          if (uid == null || uid == meId || seen.contains(uid)) continue;
          seen.add(uid);
          out.add(RecentPlayer(
            id: uid,
            name: (p['name'] as String?) ?? 'Player',
            avatar: p['avatar'] as String?,
          ));
          if (out.length >= max) return Ok(out);
        }
      }
      return Ok(out);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final matchHistoryRepositoryProvider = Provider<MatchHistoryRepository>(
  (ref) => MatchHistoryRepository(ref.watch(dioProvider)),
);

/// Recent distinct human players the signed-in user has played with. Auto-
/// disposes so it re-fetches each time the profile screen is opened.
final recentPlayersProvider =
    FutureProvider.autoDispose<List<RecentPlayer>>((ref) async {
  final me = ref.watch(authControllerProvider).valueOrNull;
  final meId = me == null ? null : int.tryParse(me.id);
  final res =
      await ref.read(matchHistoryRepositoryProvider).recentPlayers(meId: meId);
  return res.when(ok: (v) => v, err: (f) => throw Exception(f.message));
});
