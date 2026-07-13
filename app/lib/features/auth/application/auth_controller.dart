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
///
/// On construction it restores the previous session from secure storage (see
/// [AuthRepository.restoreSession]), so a returning player lands on Home
/// without logging in again. All sign-in methods share a single-flight guard:
/// while one attempt is running, further taps are ignored instead of spawning
/// a second SDK call that would make the first one fail spuriously.
class AuthController extends AsyncNotifier<AuthUser?> {
  /// True while any sign-in attempt is in flight. This is intentionally
  /// separate from `state.isLoading`: it also covers the window before the
  /// first `state = AsyncLoading()` propagates, so two taps in the same frame
  /// still collapse into one attempt.
  bool _inFlight = false;

  @override
  Future<AuthUser?> build() async {
    final restored = await ref.read(authRepositoryProvider).restoreSession();
    AppLogger.auth(
      restored == null
          ? 'Startup: no session — showing login'
          : 'Startup: session restored for user ${restored.id}',
    );
    return restored;
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> continueAsGuest({String? name}) => _run(() async {
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
      });

  Future<bool> login(String email, String password) => _run(() async {
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
      });

  Future<bool> register(String name, String email, String password) =>
      _run(() async {
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
      });

  Future<bool> loginWithFacebook() => _run(() async {
        try {
          final profile = await ref.read(facebookAuthServiceProvider).login();
          if (profile == null) {
            // User cancelled the Facebook dialog — not an error.
            state = const AsyncData(null);
            return false;
          }
          final res = await _repo.facebook(profile.accessToken);
          return res.when(
            ok: (u) {
              AppLogger.auth('Facebook backend login succeeded');
              // Prefer the freshly-fetched Facebook photo URL (guaranteed
              // loadable for this session) over the backend-stored one, which
              // may be a stale/expired/not-yet-deployed value.
              state = AsyncData(u.copyWith(
                  name: u.name, avatarUrl: profile.pictureUrl ?? u.avatarUrl));
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
      });

  Future<bool> loginWithGoogle() => _run(() async {
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
              // Prefer the fresh Google photo URL over the backend-stored one.
              state = AsyncData(u.copyWith(
                  name: u.name, avatarUrl: profile.photoUrl ?? u.avatarUrl));
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
      });

  /// Single-flight wrapper for every sign-in path: the first call runs, any
  /// overlapping call is a no-op returning false. The guard is released in
  /// `finally` so a thrown error can never wedge the login buttons.
  Future<bool> _run(Future<bool> Function() attempt) async {
    if (_inFlight) {
      AppLogger.auth('Sign-in tap ignored: another attempt is in flight');
      return false;
    }
    _inFlight = true;
    state = const AsyncLoading();
    try {
      return await attempt();
    } finally {
      _inFlight = false;
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
