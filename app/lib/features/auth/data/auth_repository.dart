import 'dart:convert';
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
      // Distinguish "the server answered with an error" from "we couldn't reach
      // the server". A server error (e.g. a 5xx) must SURFACE — silently
      // returning a token-less local guest is exactly what hid the guest-login
      // failure before: the player looked signed in, then every authenticated
      // call (create room, matchmaking) failed for lack of a bearer token.
      if (e is DioException && e.response != null) {
        AppLogger.auth(
            'Guest login server error status=${e.response?.statusCode}');
        return Err(DioClient.mapError(e));
      }
      // Genuine connectivity problem only: degrade gracefully to an offline
      // local guest so the player can still enjoy offline / bot games.
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

  /// Re-verify a fresh Facebook token with the backend so the stored
  /// SocialAccount access token is refreshed with the newest permission
  /// (used by "Sync Facebook friends"). This intentionally does NOT change the
  /// local session: the current Sanctum token stays in place, so a player who
  /// signed in another way is never switched to a different account.
  Future<void> refreshFacebookToken(String accessToken) async {
    try {
      await _dio.post(
        ApiEndpoints.facebook,
        data: {'access_token': accessToken},
      );
      AppLogger.auth('Facebook token refreshed for friend sync');
    } catch (e) {
      // Non-fatal: the sync simply falls back to an empty friends list.
      if (e is DioException) {
        AppLogger.auth(
          'Facebook token refresh failed status=${e.response?.statusCode}',
        );
      }
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

  /// Restore the previous session from secure storage, so returning users go
  /// straight to Home instead of the login screen.
  ///
  ///  - No stored token → null (show login).
  ///  - Token rejected by the server (401/403/419) → the session is genuinely
  ///    over: clear the token + cached user and return null (show login).
  ///  - Network/server unavailable → do NOT log the user out. Return the
  ///    cached user (offline session) if one exists; the token stays put and
  ///    every later request keeps sending it, so the session self-heals when
  ///    connectivity returns.
  Future<AuthUser?> restoreSession() async {
    final savedToken = await _storage.token;
    if (savedToken == null || savedToken.isEmpty) {
      AppLogger.auth('restoreSession: no stored token');
      return null;
    }

    try {
      final res = await _dio.get(ApiEndpoints.me);
      final user = _userFromResponse(res.data);
      await _cacheUser(user);
      AppLogger.auth('restoreSession: token valid, session restored');
      return user;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 419) {
        // The token is invalid/expired/revoked — clear it safely.
        AppLogger.auth('restoreSession: token rejected ($status); cleared');
        await _storage.clearToken();
        await _storage.clearCachedUser();
        return null;
      }
      // Offline / server hiccup: keep the token, restore from cache if we can.
      final cached = await _readCachedUser();
      AppLogger.auth(
        'restoreSession: network unavailable ($status); '
        'cached user ${cached == null ? 'absent' : 'used'}',
      );
      return cached;
    } catch (e, st) {
      AppLogger.e('restoreSession: unexpected error', e, st);
      // Fail safe: don't wipe credentials for a client-side bug; just show
      // the login screen this launch.
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {
      // ignore network errors on logout
    }
    await _storage.clearToken();
    await _storage.clearCachedUser();
  }

  Future<void> _persist(AuthUser user) async {
    final hasToken = user.token != null && user.token!.isNotEmpty;
    if (hasToken) {
      await _storage.saveToken(user.token!);
      AppLogger.auth('Sanctum token saved=true');
    } else {
      AppLogger.auth('Sanctum token saved=false');
    }
    await _cacheUser(user);
  }

  /// Cache identity/display data (never the token) for offline restoration.
  Future<void> _cacheUser(AuthUser user) async {
    try {
      await _storage.saveCachedUser(jsonEncode(user.toJson()));
    } catch (_) {
      // Cache write failures must never break login.
    }
  }

  Future<AuthUser?> _readCachedUser() async {
    try {
      final raw = await _storage.cachedUser;
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthUser.fromJson(decoded);
    } catch (_) {
      return null;
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
