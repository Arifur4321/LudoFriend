import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/logger.dart';
import 'auth_user.dart';

/// Talks to the auth API, persisting the Sanctum token on success.
///
/// Guest login degrades gracefully: if the backend is unreachable (offline /
/// Phase-1), it returns a **local** guest so the player can still enjoy offline
/// and bot games. The local progress can be migrated after registering.
class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final SecureStorage _storage;

  static String randomGuestName() {
    const animals = ['Fox', 'Panda', 'Otter', 'Koala', 'Tiger', 'Robin'];
    final n = Random();
    return '${animals[n.nextInt(animals.length)]}${1000 + n.nextInt(9000)}';
  }

  Future<String> _guestDeviceId() async {
    final existing = await _storage.guestId;
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final id = 'guest-${DateTime.now().millisecondsSinceEpoch}-$suffix';
    await _storage.saveGuestId(id);
    return id;
  }

  Future<Result<AuthUser>> guest({String? name}) async {
    final guestName =
        (name == null || name.trim().isEmpty) ? randomGuestName() : name.trim();
    try {
      final res = await _dio.post(ApiEndpoints.guest, data: {
        'device_id': await _guestDeviceId(),
        'guest_name': guestName,
      });
      final user =
          _userFromResponse(res.data, fallbackName: guestName).copyWith();
      await _persist(user);
      return Ok(user);
    } catch (e) {
      // Offline fallback — still let them play locally.
      final local = AuthUser(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        name: guestName,
        isGuest: true,
      );
      return Ok(local);
    }
  }

  Future<Result<AuthUser>> login(String email, String password) async {
    try {
      final res = await _dio.post(ApiEndpoints.login,
          data: {'email': email, 'password': password});
      final user = _userFromResponse(res.data);
      await _persist(user);
      return Ok(user);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<AuthUser>> register(
      String name, String email, String password) async {
    try {
      final res = await _dio.post(ApiEndpoints.register, data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      });
      final user = _userFromResponse(res.data, fallbackName: name);
      await _persist(user);
      return Ok(user);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<AuthUser>> facebook(String accessToken) async {
    try {
      AppLogger.auth('Backend POST /auth/facebook started');
      final res = await _dio.post(
        ApiEndpoints.facebook,
        data: {'access_token': accessToken},
      );
      AppLogger.auth('Backend /auth/facebook status=${res.statusCode}');
      final user = _userFromResponse(res.data);
      await _persist(user);
      return Ok(user);
    } catch (e) {
      if (e is DioException) {
        AppLogger.auth(
          'Backend /auth/facebook error status=${e.response?.statusCode}',
        );
        AppLogger.auth('Backend /auth/facebook error body=${e.response?.data}');
      }
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<AuthUser>> google({
    required String idToken,
    String? serverAuthCode,
  }) async {
    try {
      AppLogger.auth('Backend POST /auth/google started');
      final res = await _dio.post(ApiEndpoints.google, data: {
        'id_token': idToken,
        if (serverAuthCode != null) 'server_auth_code': serverAuthCode,
      });
      AppLogger.auth('Backend /auth/google status=${res.statusCode}');
      final user = _userFromResponse(res.data);
      await _persist(user);
      return Ok(user);
    } catch (e) {
      if (e is DioException) {
        AppLogger.auth(
          'Backend /auth/google error status=${e.response?.statusCode}',
        );
        AppLogger.auth('Backend /auth/google error body=${e.response?.data}');
      }
      return Err(DioClient.mapError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {
      // ignore network errors on logout
    }
    await _storage.clearToken();
  }

  Future<void> _persist(AuthUser user) async {
    final hasToken = user.token != null && user.token!.isNotEmpty;
    if (hasToken) {
      await _storage.saveToken(user.token!);
      AppLogger.auth('Sanctum token saved=true');
    } else {
      AppLogger.auth('Sanctum token saved=false');
    }
  }

  AuthUser _userFromResponse(dynamic data, {String? fallbackName}) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final userJson =
        (map['user'] ?? map['data'] ?? map) as Map<String, dynamic>;
    final token = (map['token'] ?? map['access_token']) as String?;
    return AuthUser(
      id: '${userJson['id'] ?? 'user'}',
      name: userJson['name'] as String? ?? fallbackName ?? 'Player',
      email: userJson['email'] as String?,
      isGuest: userJson['is_guest'] as bool? ?? false,
      avatarUrl: userJson['avatar'] as String?,
      token: token,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(secureStorageProvider)),
);
