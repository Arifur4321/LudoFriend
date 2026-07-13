import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Thin wrapper around platform secure storage for the auth token & guest id.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<String?> get token => read(AppConstants.kAuthToken);
  Future<void> saveToken(String value) => write(AppConstants.kAuthToken, value);
  Future<void> clearToken() => delete(AppConstants.kAuthToken);

  Future<String?> get guestId => read(AppConstants.kGuestId);
  Future<void> saveGuestId(String value) => write(AppConstants.kGuestId, value);

  /// Cached user profile JSON (identity/display data only — never a secret).
  /// Saved at login so the session can be restored offline; cleared on logout
  /// and whenever the token is invalidated.
  Future<String?> get cachedUser => read(AppConstants.kAuthUser);
  Future<void> saveCachedUser(String json) =>
      write(AppConstants.kAuthUser, json);
  Future<void> clearCachedUser() => delete(AppConstants.kAuthUser);
}
