import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../social/social_auth_exception.dart';

/// Minimal Facebook profile fetched after login.
class FacebookProfile {
  const FacebookProfile({
    required this.id,
    required this.name,
    required this.accessToken,
    this.email,
    this.pictureUrl,
  });

  final String id;
  final String name;
  final String accessToken;
  final String? email;
  final String? pictureUrl;
}

class FacebookFriend {
  const FacebookFriend({
    required this.id,
    required this.name,
    this.pictureUrl,
  });

  final String id;
  final String name;
  final String? pictureUrl;
}

/// Outcome of an explicit "Sync Facebook friends" permission request.
class FacebookFriendsSync {
  const FacebookFriendsSync({required this.completed, this.accessToken});

  /// True when the Facebook dialog finished (whether or not `user_friends`
  /// was actually granted); false when the user cancelled it.
  final bool completed;

  /// A fresh access token to hand to the backend so the stored token carries
  /// the newest permission. Null when the dialog was cancelled.
  final String? accessToken;
}

/// Wraps Facebook login. Facebook is **optional** — gameplay never requires it.
///
/// On success it returns the basic profile + access token, which the backend
/// verifies (`/auth/facebook`). Friend discovery falls back to invite links /
/// room codes / deep links when the `user_friends` permission is unavailable
/// (handled in the friends feature, not here).
class FacebookAuthService {
  /// Guards against overlapping native SDK calls: a second `login()` while the
  /// Facebook dialog is already open makes the SDK fail BOTH attempts on some
  /// devices ("only one login at a time"), which is a classic source of
  /// "sometimes it works, sometimes it doesn't".
  bool _loginInFlight = false;

  Future<FacebookProfile?> login() async {
    _ensureEnabled();
    if (_loginInFlight) {
      AppLogger.auth('Facebook login tap ignored: dialog already open');
      return null;
    }
    _loginInFlight = true;
    try {
      return await _loginOnce(allowRetry: true);
    } finally {
      _loginInFlight = false;
    }
  }

  Future<FacebookProfile?> _loginOnce({required bool allowRetry}) async {
    AppLogger.auth('Facebook login started');
    final result = await FacebookAuth.instance.login(
      // public_profile → name + photo. `user_friends` is intentionally NOT
      // requested: it is an "Invalid Scope" for apps that haven't been granted
      // Advanced Access via Facebook App Review, and requesting it hard-errors
      // the login dialog for developers. Friends work via friend-codes / invite
      // links (no FB permission needed). Only re-add 'user_friends' AFTER it has
      // been approved for this app in the Facebook dashboard.
      permissions: const ['public_profile'],
    );
    final token = result.accessToken;
    AppLogger.auth('Facebook LoginResult.status=${result.status.name}');
    AppLogger.auth('Facebook LoginResult.message=${result.message ?? ''}');
    AppLogger.auth('Facebook accessToken exists=${token != null}');
    AppLogger.auth('Facebook accessToken userId=${_tokenUserId(token) ?? ''}');
    AppLogger.auth(
      'Facebook token string length=${token?.tokenString.length ?? 0}',
    );

    if (result.status == LoginStatus.cancelled) return null;
    if (result.status != LoginStatus.success || token == null) {
      // A failed attempt can leave the native SDK holding a half-open session
      // (stale token from a previous account, an interrupted dialog, or an app
      // switch mid-login). Clear it and retry exactly once — this converts the
      // most common intermittent failure into a successful login, and also
      // makes account switching reliable.
      if (allowRetry) {
        AppLogger.auth('Facebook login failed — clearing SDK state, retrying');
        try {
          await FacebookAuth.instance.logOut();
        } catch (_) {
          // Nothing to clear — proceed with the retry regardless.
        }
        return _loginOnce(allowRetry: false);
      }
      throw SocialAuthException(
        result.message ?? 'Facebook sign-in could not be completed.',
      );
    }

    var data = <String, dynamic>{};
    try {
      data = await FacebookAuth.instance.getUserData(
        fields: 'id,name,picture.width(200)',
      );
    } catch (e, s) {
      AppLogger.e(
        'Facebook getUserData failed; continuing with access token',
        e,
        s,
      );
    }

    return FacebookProfile(
      id: '${data['id'] ?? _tokenUserId(token) ?? ''}',
      name: data['name'] as String? ?? 'Facebook Player',
      email: data['email'] as String?,
      pictureUrl: _pictureUrl(data),
      accessToken: token.tokenString,
    );
  }

  /// Requests the `user_friends` permission so the backend can list Facebook
  /// friends who ALSO play this app. This runs ONLY on an explicit
  /// "Sync Facebook friends" tap — never during normal login or app launch —
  /// so a player who never syncs is never prompted, and cancelling leaves
  /// login and gameplay completely unaffected.
  ///
  /// Returns a fresh access token when the dialog completes, so the caller can
  /// refresh the server-side token. `user_friends` only yields data once the
  /// app has Advanced Access approved in the Facebook dashboard; until then
  /// Facebook returns no friends and the caller shows a safe empty state.
  Future<FacebookFriendsSync?> requestFriendsSync() async {
    _ensureEnabled();
    if (_loginInFlight) {
      AppLogger.auth('Facebook friends-sync ignored: dialog already open');
      return null;
    }
    _loginInFlight = true;
    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['public_profile', 'user_friends'],
      );
      AppLogger.auth('Facebook friends-sync status=${result.status.name}');
      final token = result.accessToken;
      if (result.status != LoginStatus.success || token == null) {
        // Cancelled or could not complete — not an error.
        return const FacebookFriendsSync(completed: false);
      }
      return FacebookFriendsSync(
        completed: true,
        accessToken: token.tokenString,
      );
    } finally {
      _loginInFlight = false;
    }
  }

  Future<List<FacebookFriend>> friends() async {
    _ensureEnabled();
    final data = await FacebookAuth.instance.getUserData(
      fields: 'friends{id,name,picture.width(160)}',
    );
    final friends = data['friends'];
    final raw = friends is Map<String, dynamic> ? friends['data'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (friend) => FacebookFriend(
            id: '${friend['id']}',
            name: friend['name'] as String? ?? 'Facebook Friend',
            pictureUrl: _pictureUrl(friend),
          ),
        )
        .toList(growable: false);
  }

  Future<void> logout() async {
    if (AppConfig.facebookEnabled) await FacebookAuth.instance.logOut();
  }

  void _ensureEnabled() {
    if (!AppConfig.facebookEnabled) {
      throw const SocialAuthException(
        'Facebook sign-in needs FACEBOOK_ENABLED=true and native Facebook app settings.',
      );
    }
  }

  String? _pictureUrl(Map<String, dynamic> data) {
    final picture = data['picture'];
    if (picture is! Map<String, dynamic>) return null;
    final pictureData = picture['data'];
    if (pictureData is! Map<String, dynamic>) return null;
    return pictureData['url'] as String?;
  }

  String? _tokenUserId(AccessToken? token) {
    if (token is ClassicToken) return token.userId;
    if (token is LimitedToken) return token.userId;
    return null;
  }
}

final facebookAuthServiceProvider =
    Provider<FacebookAuthService>((ref) => FacebookAuthService());
