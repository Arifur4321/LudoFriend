import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_stats.dart';

/// Fetches the signed-in player's aggregate stats from `GET /profile/stats`.
///
/// Re-fetches whenever the auth user changes (login / logout / guest). Returns
/// empty stats — never throws to the UI — for signed-out users or when the
/// request fails (offline / 401), so the profile screen degrades gracefully.
final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return ProfileStats.empty;

  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get(ApiEndpoints.stats);
    final body = res.data;
    final data = body is Map<String, dynamic>
        ? ((body['data'] ?? body) as Map<String, dynamic>)
        : <String, dynamic>{};
    return ProfileStats.fromJson(data);
  } on DioException {
    return ProfileStats.empty;
  } catch (_) {
    return ProfileStats.empty;
  }
});
