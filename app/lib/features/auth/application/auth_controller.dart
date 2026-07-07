import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/logger.dart';
import '../../../services/facebook/facebook_auth_service.dart';
import '../../../services/google/google_auth_service.dart';
import '../../../services/social/social_auth_exception.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

/// Holds the current [AuthUser] (null when signed out). Screens watch this to
/// react to sign-in / sign-out.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async => null;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> continueAsGuest({String? name}) async {
    state = const AsyncLoading();
    final res = await _repo.guest(name: name);
    return res.when(
      ok: (u) {
        state = AsyncData(u);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    final res = await _repo.login(email, password);
    return res.when(
      ok: (u) {
        state = AsyncData(u);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> register(String name, String email, String password) async {
    state = const AsyncLoading();
    final res = await _repo.register(name, email, password);
    return res.when(
      ok: (u) {
        state = AsyncData(u);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> loginWithFacebook() async {
    state = const AsyncLoading();
    try {
      final profile = await ref.read(facebookAuthServiceProvider).login();
      if (profile == null) {
        state = const AsyncData(null);
        return false;
      }
      final res = await _repo.facebook(profile.accessToken);
      return res.when(
        ok: (u) {
          AppLogger.auth('Facebook backend login succeeded');
          state = AsyncData(u.copyWith(
              name: u.name, avatarUrl: u.avatarUrl ?? profile.pictureUrl));
          return true;
        },
        err: (f) {
          AppLogger.auth('Facebook backend login failed: ${f.message}');
          state = AsyncError(f, StackTrace.current);
          return false;
        },
      );
    } on SocialAuthException catch (e) {
      AppLogger.auth('Facebook login failed before backend: ${e.message}');
      state = AsyncError(AuthFailure(e.message), StackTrace.current);
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncLoading();
    try {
      final profile = await ref.read(googleAuthServiceProvider).login();
      if (profile == null) {
        state = const AsyncData(null);
        return false;
      }
      final res = await _repo.google(
        idToken: profile.idToken,
        serverAuthCode: profile.serverAuthCode,
      );
      return res.when(
        ok: (u) {
          state = AsyncData(u.copyWith(
              name: u.name, avatarUrl: u.avatarUrl ?? profile.photoUrl));
          return true;
        },
        err: (f) {
          state = AsyncError(f, StackTrace.current);
          return false;
        },
      );
    } on SocialAuthException catch (e) {
      state = AsyncError(AuthFailure(e.message), StackTrace.current);
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    await ref.read(facebookAuthServiceProvider).logout();
    await ref.read(googleAuthServiceProvider).logout();
    state = const AsyncData(null);
  }

  String? get errorMessage {
    final s = state;
    return s is AsyncError ? (s.error as Failure?)?.message : null;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
