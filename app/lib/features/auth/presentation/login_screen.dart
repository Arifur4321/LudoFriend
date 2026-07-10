import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/external_links.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/ludo_loader.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Continuous gentle idle motion for the hero.
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  // One-shot spin-in entrance for the hero.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _animation.dispose();
    _entrance.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
    if (ok && mounted) context.go(AppRoutes.home);
  }

  Future<void> _guest() async {
    final ok =
        await ref.read(authControllerProvider.notifier).continueAsGuest();
    if (ok && mounted) context.go(AppRoutes.home);
  }

  Future<void> _facebook() async {
    final ok =
        await ref.read(authControllerProvider.notifier).loginWithFacebook();
    if (!mounted) return;
    if (ok) {
      AppLogger.auth('Navigation after successful Facebook login: /home');
      context.go(AppRoutes.home);
      return;
    }

    final message = ref.read(authControllerProvider.notifier).errorMessage ??
        'Facebook sign-in could not be completed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _google() async {
    final ok =
        await ref.read(authControllerProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    if (ok) {
      AppLogger.auth('Navigation after successful Google login: /home');
      context.go(AppRoutes.home);
      return;
    }

    final message = ref.read(authControllerProvider.notifier).errorMessage ??
        'Google sign-in could not be completed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;
    final error = state.hasError
        ? ref.read(authControllerProvider.notifier).errorMessage
        : null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    _LandingLudoHero(entrance: _entrance, idle: _animation),
                    const SizedBox(height: 10),
                    Text('Ludo Friends',
                        style: AppTextStyles.display,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('Login or create an account to play with friends',
                        style:
                            AppTextStyles.body.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Continue as Guest',
                      icon: Icons.bolt_rounded,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8E8AA6), Color(0xFF5C5874)]),
                      onPressed: loading ? null : _guest,
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Facebook',
                      asset: AppAssets.facebookBrand,
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      onPressed: loading ? null : _facebook,
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Gmail',
                      asset: AppAssets.gmailBrand,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      onPressed: loading ? null : _google,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : () => context.push(AppRoutes.register),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Register with Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.58)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.35))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('manual email login',
                              style: AppTextStyles.label
                                  .copyWith(color: Colors.white70)),
                        ),
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.35))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Field(controller: _email, hint: 'Email', icon: Icons.mail),
                    const SizedBox(height: 14),
                    _Field(
                        controller: _password,
                        hint: 'Password',
                        icon: Icons.lock,
                        obscure: true),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error,
                          style: AppTextStyles.label
                              .copyWith(color: Colors.amberAccent)),
                    ],
                    const SizedBox(height: 22),
                    PrimaryButton(
                        label: 'Login with Email',
                        onPressed: loading ? null : _login),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text('Create a new account',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    const _LegalFooter(),
                  ],
                ),
              ),
            ),
          ),
          LudoLoadingOverlay(visible: loading, message: 'Signing you in…'),
        ],
      ),
    );
  }
}

/// The hero ludo illustration. On first build it spins in (a couple of turns
/// while scaling + fading up), settles upright, then keeps a subtle idle float.
class _LandingLudoHero extends StatelessWidget {
  const _LandingLudoHero({required this.entrance, required this.idle});

  final Animation<double> entrance; // one-shot 0→1
  final Animation<double> idle; // continuous 0→1 loop

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: Listenable.merge([entrance, idle]),
        builder: (context, child) {
          // Entrance: ease-out spin + scale + fade.
          final e = Curves.easeOutCubic.transform(entrance.value);
          final settle =
              Curves.easeOutBack.transform(entrance.value.clamp(0.0, 1.0));
          final spinIn =
              (1 - e) * (2 * math.pi * 2); // ~2 turns, unwinding to 0
          final scale = 0.35 + 0.65 * settle;
          final opacity = e;

          // Idle float (only once mostly settled, scaled by entrance progress).
          final t = idle.value * math.pi * 2;
          final floatY = math.sin(t) * 6 * e;
          final wobble = math.sin(t * 0.7) * 0.03 * e;

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, floatY),
              child: Transform.rotate(
                angle: spinIn + wobble,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        child: SvgPicture.asset(AppAssets.landingLudoMotion),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.asset,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final String asset;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color:
          enabled ? backgroundColor : backgroundColor.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(asset, width: 26, height: 26),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.button.copyWith(color: foregroundColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small consent line under the sign-in buttons linking to the public legal
/// pages (required for Play / Meta / Google review).
class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(color: Colors.white70);
    final linkStyle = style.copyWith(
        color: Colors.white, decoration: TextDecoration.underline);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: style),
        GestureDetector(
          onTap: () => openExternalUrl(context, AppConfig.termsUrl),
          child: Text('Terms', style: linkStyle),
        ),
        Text(' and ', style: style),
        GestureDetector(
          onTap: () => openExternalUrl(context, AppConfig.privacyPolicyUrl),
          child: Text('Privacy Policy', style: linkStyle),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
    );
  }
}
