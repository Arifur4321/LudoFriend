import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/core/errors/failures.dart';
import 'package:ludo_friends/core/network/api_result.dart';
import 'package:ludo_friends/features/auth/application/auth_controller.dart';
import 'package:ludo_friends/features/auth/data/auth_repository.dart';
import 'package:ludo_friends/features/auth/data/auth_user.dart';
import 'package:ludo_friends/services/facebook/facebook_auth_service.dart';
import 'package:ludo_friends/services/google/google_auth_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

class _MockFacebook extends Mock implements FacebookAuthService {}

class _MockGoogle extends Mock implements GoogleAuthService {}

/// Behavioural coverage for the login-flow guarantees the Facebook fix relies
/// on: session restoration at startup, exactly ONE sign-in attempt per burst of
/// taps, and clean cancelled/failed handling.
void main() {
  late _MockRepo repo;
  late _MockFacebook facebook;
  late _MockGoogle google;
  late ProviderContainer container;

  const user = AuthUser(id: '7', name: 'FB Player', token: 'tok');
  const profile = FacebookProfile(
    id: 'fb-1',
    name: 'FB Player',
    accessToken: 'fb-token',
    pictureUrl: 'https://cdn.example/p.jpg',
  );

  setUp(() {
    repo = _MockRepo();
    facebook = _MockFacebook();
    google = _MockGoogle();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      facebookAuthServiceProvider.overrideWithValue(facebook),
      googleAuthServiceProvider.overrideWithValue(google),
    ]);
    addTearDown(container.dispose);
  });

  Future<AuthController> readyController({AuthUser? restored}) async {
    when(() => repo.restoreSession()).thenAnswer((_) async => restored);
    // Keep the provider alive for the whole test.
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    return container.read(authControllerProvider.notifier);
  }

  group('session restoration at startup', () {
    test('build() restores the stored session — no login required', () async {
      await readyController(restored: user);
      final state = container.read(authControllerProvider);
      expect(state.value?.id, '7');
      verify(() => repo.restoreSession()).called(1);
    });

    test('build() yields null when nothing is stored (login screen)',
        () async {
      await readyController();
      expect(container.read(authControllerProvider).value, isNull);
    });
  });

  group('Facebook login', () {
    test('successful login lands the backend user with the fresh photo',
        () async {
      final controller = await readyController();
      when(() => facebook.login()).thenAnswer((_) async => profile);
      when(() => repo.facebook('fb-token'))
          .thenAnswer((_) async => const Ok(user));

      expect(await controller.loginWithFacebook(), isTrue);
      final state = container.read(authControllerProvider);
      expect(state.value?.id, '7');
      expect(state.value?.avatarUrl, 'https://cdn.example/p.jpg');
    });

    test('cancelled Facebook dialog is not an error', () async {
      final controller = await readyController();
      when(() => facebook.login()).thenAnswer((_) async => null);

      expect(await controller.loginWithFacebook(), isFalse);
      final state = container.read(authControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value, isNull);
      verifyNever(() => repo.facebook(any()));
    });

    test('backend rejection surfaces a readable error state', () async {
      final controller = await readyController();
      when(() => facebook.login()).thenAnswer((_) async => profile);
      when(() => repo.facebook(any())).thenAnswer(
          (_) async => const Err(AuthFailure('Facebook session expired')));

      expect(await controller.loginWithFacebook(), isFalse);
      expect(container.read(authControllerProvider).hasError, isTrue);
      expect(controller.errorMessage, 'Facebook session expired');
    });

    test('duplicate login-button taps run exactly ONE Facebook attempt',
        () async {
      final controller = await readyController();
      final gate = Completer<FacebookProfile?>();
      when(() => facebook.login()).thenAnswer((_) => gate.future);
      when(() => repo.facebook(any()))
          .thenAnswer((_) async => const Ok(user));

      // Burst of taps while the Facebook dialog is opening.
      final first = controller.loginWithFacebook();
      final second = controller.loginWithFacebook();
      final third = controller.loginWithFacebook();

      expect(await second, isFalse); // ignored, no second SDK call
      expect(await third, isFalse);

      gate.complete(profile); // the ONE dialog finishes
      expect(await first, isTrue);

      verify(() => facebook.login()).called(1);
      verify(() => repo.facebook('fb-token')).called(1);
      expect(container.read(authControllerProvider).value?.id, '7');
    });

    test('a failed attempt releases the guard so the user can retry',
        () async {
      final controller = await readyController();
      when(() => facebook.login()).thenAnswer((_) async => null); // cancelled

      expect(await controller.loginWithFacebook(), isFalse);
      // Second, deliberate attempt succeeds — the single-flight guard reset.
      when(() => facebook.login()).thenAnswer((_) async => profile);
      when(() => repo.facebook(any()))
          .thenAnswer((_) async => const Ok(user));
      expect(await controller.loginWithFacebook(), isTrue);
    });
  });
}
