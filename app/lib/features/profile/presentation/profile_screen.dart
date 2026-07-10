import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final signedIn = user != null && !user.isGuest;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              Column(
                children: [
                  _ProfileAvatar(
                    photoUrl: signedIn ? user?.avatarUrl : null,
                  ),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'Guest', style: AppTextStyles.display),
                  Text(signedIn ? (user?.email ?? '') : 'Guest player',
                      style:
                          AppTextStyles.body.copyWith(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: const [
                  _StatTile(label: 'Matches', value: '0'),
                  _StatTile(label: 'Wins', value: '0'),
                  _StatTile(label: 'Losses', value: '0'),
                  _StatTile(label: 'Win rate', value: '—'),
                  _StatTile(label: 'Best streak', value: '0'),
                  _StatTile(label: 'Coins', value: '0'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    SvgPicture.asset(AppAssets.illusEmpty, height: 120),
                    const SizedBox(height: 12),
                    Text('No matches yet', style: AppTextStyles.title),
                    Text('Your match history will appear here.',
                        style: AppTextStyles.bodyMuted,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (signedIn)
                PrimaryButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  gradient: const LinearGradient(
                      colors: [AppColors.secondary, Color(0xFFD64545)]),
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go(AppRoutes.home);
                  },
                )
              else
                PrimaryButton(
                  label: 'Sign in to save progress',
                  icon: Icons.login,
                  onPressed: () => context.push(AppRoutes.login),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular profile avatar.
///
/// Shows the signed-in user's real Facebook / Google photo when a [photoUrl] is
/// available, falling back to the bundled guest face while the image loads, on
/// any network error, or for guests / accounts without a photo. It never throws
/// on a bad or slow URL, so the profile header always renders.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.photoUrl, this.size = 96});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final fallback =
        SvgPicture.asset(AppAssets.avatarGuest, width: size, height: size);

    final Widget inner = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : fallback,
            errorBuilder: (ctx, _, __) => fallback,
          )
        : fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
      ),
      child: ClipOval(child: inner),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMuted),
          Text(value,
              style: AppTextStyles.heading.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
