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

/// Wraps Facebook login. Facebook is **optional** — gameplay never requires it.
///
/// On success it returns the basic profile + access token, which the backend
/// verifies (`/auth/facebook`). Friend discovery falls back to invite links /
/// room codes / deep links when the `user_friends` permission is unavailable
/// (handled in the friends feature, not here).
class FacebookAuthService {
  Future<FacebookProfile?> login() async {
    _ensureEnabled();
    AppLogger.auth('Facebook login started');
    final result = await FacebookAuth.instance.login(
      // public_profile → name + photo (default). user_friends → list friends who
      // also play this app (requires FB App Review for public use; works for
      // testers/developers in the meantime). Declined perms don't block login.
      permissions: const ['public_profile', 'user_friends'],
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
