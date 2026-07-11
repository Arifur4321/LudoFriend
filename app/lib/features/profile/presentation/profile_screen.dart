import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../friends/data/friends_repository.dart';
import '../../room/data/room_repository.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/profile_stats_controller.dart';
import '../data/match_history_repository.dart';
import '../data/profile_stats.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final signedIn = user != null && !user.isGuest;
    final stats =
        ref.watch(profileStatsProvider).valueOrNull ?? ProfileStats.empty;
    final coins = ref.watch(coinsProvider);

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
                children: [
                  _StatTile(label: 'Matches', value: '${stats.matchesPlayed}'),
                  _StatTile(label: 'Wins', value: '${stats.wins}'),
                  _StatTile(label: 'Losses', value: '${stats.losses}'),
                  _StatTile(label: 'Win rate', value: stats.winRateLabel),
                  _StatTile(label: 'Best streak', value: '${stats.bestStreak}'),
                  _StatTile(label: 'Coins', value: formatCoins(coins)),
                ],
              ),
              const SizedBox(height: 16),
              const _RecentPlayersCard(),
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

/// Recent human players the user has played with, each with a one-tap "Play"
/// that opens a private room and re-invites them. Falls back to the original
/// empty state when there's no match history yet.
class _RecentPlayersCard extends ConsumerStatefulWidget {
  const _RecentPlayersCard();

  @override
  ConsumerState<_RecentPlayersCard> createState() => _RecentPlayersCardState();
}

class _RecentPlayersCardState extends ConsumerState<_RecentPlayersCard> {
  int? _invitingId;

  Future<void> _play(RecentPlayer p) async {
    if (_invitingId != null) return;
    setState(() => _invitingId = p.id);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final roomRes = await ref
        .read(roomRepositoryProvider)
        .create(mode: '4p', botFill: false, visibility: 'private');
    if (!mounted) return;

    await roomRes.when(
      ok: (room) async {
        ref.read(activeRoomProvider.notifier).state = room;
        final inv = await ref
            .read(friendsRepositoryProvider)
            .inviteToRoom(roomId: room.id, friendUserId: p.id);
        if (!mounted) return;
        inv.when(
          ok: (_) => messenger.showSnackBar(SnackBar(
              content: Text('Invited ${p.name} — waiting in the lobby.'))),
          err: (f) =>
              messenger.showSnackBar(SnackBar(content: Text(f.message))),
        );
        // The room exists regardless, so head to the lobby where the host can
        // also share the code if the realtime invite didn't reach them.
        router.push(AppRoutes.lobby);
      },
      err: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );

    if (mounted) setState(() => _invitingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recentPlayersProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const _NoHistoryCard(),
      data: (players) {
        if (players.isEmpty) return const _NoHistoryCard();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Recent players', style: AppTextStyles.title),
                ],
              ),
              const SizedBox(height: 2),
              Text('People you played with — tap Play to invite them again.',
                  style: AppTextStyles.bodyMuted),
              const SizedBox(height: 6),
              for (final p in players)
                _RecentPlayerTile(
                  player: p,
                  busy: _invitingId == p.id,
                  onPlay: () => _play(p),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentPlayerTile extends StatelessWidget {
  const _RecentPlayerTile(
      {required this.player, required this.busy, required this.onPlay});
  final RecentPlayer player;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = player.avatar != null && player.avatar!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: hasAvatar ? NetworkImage(player.avatar!) : null,
            child: hasAvatar
                ? null
                : Text(
                    player.name.isNotEmpty
                        ? player.name.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppColors.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(player.name, style: AppTextStyles.body)),
          FilledButton(
            onPressed: busy ? null : onPlay,
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
            child: Text(busy ? '…' : 'Play'),
          ),
        ],
      ),
    );
  }
}

/// Original empty-state, shown until the user has played a match.
class _NoHistoryCard extends StatelessWidget {
  const _NoHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
