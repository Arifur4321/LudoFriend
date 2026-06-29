import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../social/social_auth_exception.dart';

class GoogleProfile {
  const GoogleProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.idToken,
    this.photoUrl,
    this.serverAuthCode,
  });

  final String id;
  final String name;
  final String email;
  final String idToken;
  final String? photoUrl;
  final String? serverAuthCode;
}

class GoogleAuthService {
  bool _initialized = false;

  Future<GoogleProfile?> login() async {
    if (!AppConfig.googleEnabled) {
      throw const SocialAuthException(
        'Google sign-in is disabled for this build.',
      );
    }

    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException(
          'Google did not return an ID token for backend login.',
        );
      }

      final serverAuth =
          await account.authorizationClient.authorizeServer(const <String>[]);

      return GoogleProfile(
        id: account.id,
        name: account.displayName ?? account.email,
        email: account.email,
        photoUrl: account.photoUrl,
        idToken: idToken,
        serverAuthCode: serverAuth?.serverAuthCode,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw SocialAuthException(
          'Google sign-in needs OAuth client setup for this app. ${e.description ?? ''}',
        );
      }
      throw SocialAuthException(
        e.description ?? 'Google sign-in could not be completed.',
      );
    }
  }

  Future<void> logout() async {
    if (_initialized) await GoogleSignIn.instance.signOut();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
    _initialized = true;
  }
}

final googleAuthServiceProvider =
    Provider<GoogleAuthService>((ref) => GoogleAuthService());
