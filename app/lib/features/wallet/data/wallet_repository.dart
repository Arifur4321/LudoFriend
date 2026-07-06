import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import 'wallet_models.dart';

/// Reads the player's wallet balance and ledger history.
class WalletRepository {
  WalletRepository(this._dio);
  final Dio _dio;

  Future<Result<WalletSnapshot>> fetch() async {
    try {
      final res = await _dio.get(ApiEndpoints.wallet);
      return Ok(WalletSnapshot.fromJson(_asMap(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<WalletSnapshot>> transactions({int limit = 50}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.walletTransactions,
        queryParameters: {'limit': limit},
      );
      return Ok(WalletSnapshot.fromJson(_asMap(res.data)));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};
}

final walletRepositoryProvider =
    Provider<WalletRepository>((ref) => WalletRepository(ref.watch(dioProvider)));
