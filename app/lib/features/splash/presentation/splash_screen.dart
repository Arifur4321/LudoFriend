import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/logger.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_user.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _go();
  }

  /// Restore the previous session while the logo animates, then route:
  /// a restored user goes straight to Home; otherwise the login screen shows.
  ///
  /// `authControllerProvider.future` is awaited (not just read after a fixed
  /// delay) so slow devices/networks still get a correct answer — the splash
  /// simply lasts as long as the longer of {animation, restoration}. The
  /// restoration itself is bounded by the Dio connect/receive timeouts, so
  /// this can never hang indefinitely.
  Future<void> _go() async {
    final results = await Future.wait<dynamic>([
      ref
          .read(authControllerProvider.future)
          .then<AuthUser?>((u) => u)
          .catchError((Object e) {
        AppLogger.e('Session restoration failed during splash', e);
        return null;
      }),
      Future<void>.delayed(const Duration(milliseconds: 1700)),
    ]);
    if (!mounted) return;

    final user = results.first as AuthUser?;
    if (user != null) {
      AppLogger.auth('Splash: session restored — going to home');
      context.go(AppRoutes.home);
    } else {
      AppLogger.auth('Splash: no session — going to login');
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
            child: SvgPicture.asset(AppAssets.splashLogo, width: 200),
          ),
        ),
      ),
    );
  }
}
