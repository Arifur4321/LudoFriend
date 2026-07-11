import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/theme/board_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/bouncing_button.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';
import '../../room/data/room_repository.dart';
import '../../wallet/presentation/widgets/coin_balance_chip.dart';
import '../application/boards_controller.dart';
import '../data/board_models.dart';
import 'widgets/board_preview.dart';

class BoardSelectScreen extends ConsumerStatefulWidget {
  const BoardSelectScreen({super.key});

  @override
  ConsumerState<BoardSelectScreen> createState() => _BoardSelectScreenState();
}

class _BoardSelectScreenState extends ConsumerState<BoardSelectScreen> {
  late final PageController _pageController =
      PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _play(
    BuildContext context,
    WidgetRef ref, {
    required BoardTier tier,
    required int humans,
    required int bots,
    required bool teamMode,
  }) {
    ref.read(activeBoardThemeProvider.notifier).state =
        BoardTheme.forKey(tier.key);
    ref.read(localCacheProvider).setSelectedBoardTier(tier.key);
    ref.read(gameConfigProvider.notifier).state = GameConfig.local(
      humans: humans,
      bots: bots,
      boardThemeKey: tier.key,
      teamMode: teamMode,
    );
    context.go(AppRoutes.game);
  }

  /// Create a real, server-authoritative private room for this board tier and
  /// open the lobby, where the host can share the room code, invite friends and
  /// start once someone joins. Replaces the old local-draft path that pushed the
  /// lobby with no server room (which rendered a blank "No room" screen).
  Future<void> _createOnlineRoom(
    BuildContext context,
    WidgetRef ref, {
    required BoardTier tier,
    required int seats,
    required bool teamMode,
  }) async {
    ref.read(activeBoardThemeProvider.notifier).state =
        BoardTheme.forKey(tier.key);
    ref.read(localCacheProvider).setSelectedBoardTier(tier.key);

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final res = await ref.read(roomRepositoryProvider).create(
          mode: seats == 2 ? '2p' : '4p',
          boardTier: tier.key,
          botFill: false,
          turnTimer: 20,
          teamMode: teamMode,
          visibility: 'private',
        );
    if (!mounted) return;
    res.when(
      ok: (room) {
        ref.read(activeRoomProvider.notifier).state = room;
        router.push(AppRoutes.lobby);
      },
      err: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _openSheet(
      BuildContext context, WidgetRef ref, BoardTier tier) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ModeSheet(
          tier: tier,
          onPlay: (h, b, team) {
            Navigator.pop(ctx);
            _play(context, ref, tier: tier, humans: h, bots: b, teamMode: team);
          },
          onPlayOnline: (seats, team) {
            Navigator.pop(ctx);
            _createOnlineRoom(context, ref,
                tier: tier, seats: seats, teamMode: team);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(boardsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Boards'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: CoinBalanceChip(compact: true)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white)),
            error: (_, __) => const Center(
              child: Text('Could not load boards.',
                  style: TextStyle(color: Colors.white)),
            ),
            data: (snap) {
              final tiers = [...snap.tiers]
                ..sort((a, b) => a.order.compareTo(b.order));
              if (tiers.isEmpty) {
                return const Center(
                  child: Text('No boards available.',
                      style: TextStyle(color: Colors.white)),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 84, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Higher stakes, bigger pots. Winner takes all.',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.joinRoom),
                        icon: const Icon(Icons.vpn_key_rounded,
                            color: Colors.white),
                        label: const Text('Join Private Room',
                            style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 440,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: tiers.length,
                      onPageChanged: (value) => setState(() => _page = value),
                      itemBuilder: (context, index) {
                        final tier = tiers[index];
                        return _BoardCard(
                          tier: tier,
                          onJoin: () => _openSheet(context, ref, tier),
                          onInvite: () => _createOnlineRoom(context, ref,
                              tier: tier,
                              seats: tier.supportsFour ? 4 : 2,
                              teamMode: false),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < tiers.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _page ? 0.95 : 0.38,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.tier,
    required this.onJoin,
    required this.onInvite,
  });

  final BoardTier tier;
  final VoidCallback onJoin;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = BoardTheme.forKey(tier.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.frame.withValues(alpha: 0.62),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onJoin,
              child: BoardPreview(theme: theme, size: 188),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(tier.name, style: AppTextStyles.title)),
                if (tier.badge != null)
                  _Badge(text: tier.badge!, color: theme.frame),
              ],
            ),
            const SizedBox(height: 6),
            if (tier.description != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tier.description!, style: AppTextStyles.bodyMuted),
              ),
            const Spacer(),
            Row(
              children: [
                const CoinIcon(size: 22),
                const SizedBox(width: 7),
                Text('${formatCoins(tier.stake)} entry',
                    style: AppTextStyles.label.copyWith(color: AppColors.ink)),
                const Spacer(),
                Icon(
                  tier.affordable
                      ? Icons.check_circle_rounded
                      : Icons.lock_clock_rounded,
                  color:
                      tier.affordable ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    label: 'Join Board',
                    icon: Icons.login_rounded,
                    color: theme.frame,
                    onTap: onJoin,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Action(
                    label: 'Invite Friends',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.primary,
                    onTap: onInvite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BouncingButton(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ModeAction extends StatelessWidget {
  const _ModeAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: AppTextStyles.label.copyWith(color: color, fontSize: 11)),
      );
}

class _ModeSheet extends StatefulWidget {
  const _ModeSheet(
      {required this.tier, required this.onPlay, required this.onPlayOnline});
  final BoardTier tier;
  final void Function(int humans, int bots, bool teamMode) onPlay;
  final void Function(int seats, bool teamMode) onPlayOnline;

  @override
  State<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends State<_ModeSheet> {
  int _seats = 4;
  bool _teams = false;

  @override
  Widget build(BuildContext context) {
    final theme = BoardTheme.forKey(widget.tier.key);
    final canTeam = _seats == 4 && widget.tier.team;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoardPreview(theme: theme, size: 90),
          const SizedBox(height: 10),
          Text(widget.tier.name, style: AppTextStyles.heading),
          Text('${formatCoins(widget.tier.stake)} entry · winner takes the pot',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: 18),
          Row(
            children: [
              _Seat(
                  label: '2 Players',
                  selected: _seats == 2,
                  onTap: () => setState(() {
                        _seats = 2;
                        _teams = false;
                      })),
              const SizedBox(width: 12),
              _Seat(
                  label: '4 Players',
                  selected: _seats == 4,
                  onTap: () => setState(() => _seats = 4)),
            ],
          ),
          if (canTeam) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('2v2 Teams', style: AppTextStyles.body),
              subtitle: Text('Winning team splits the pot',
                  style: AppTextStyles.bodyMuted),
              value: _teams,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _teams = v),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _ModeAction(
              label: 'Play Online — Invite Friends',
              color: AppColors.primary,
              onTap: () => widget.onPlayOnline(_seats, _teams && canTeam),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeAction(
                  label: 'vs Computer',
                  color: AppColors.tokenBlue,
                  onTap: () => widget.onPlay(1, _seats - 1, _teams),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeAction(
                  label: 'Pass & Play',
                  color: AppColors.tokenGreen,
                  onTap: () => widget.onPlay(_seats, 0, _teams),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Online lets your Facebook friends join with the room code.',
              style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: AppTextStyles.label
                    .copyWith(color: selected ? Colors.white : AppColors.ink)),
          ),
        ),
      );
}
