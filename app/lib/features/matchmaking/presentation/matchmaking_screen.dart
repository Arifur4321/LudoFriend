import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/bouncing_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';
import '../../room/data/room_repository.dart';
import '../data/matchmaking_repository.dart';

/// Random matchmaking. The player picks 2- or 4-player, we enqueue against the
/// backend FIFO queue and poll for a match. When paired (with real players, or
/// with bots after a short wait via the server sweep) we drop into the shared
/// room lobby. A "Play bots instead" escape hatch means the player is never
/// stuck waiting.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

enum _Phase { choosing, searching }

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  Timer? _elapsedTimer;
  Timer? _pollTimer;
  int _elapsed = 0;
  _Phase _phase = _Phase.choosing;
  String _mode = '4p';
  bool _polling = false;
  bool _navigated = false;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    // Withdraw a still-queued ticket if we're leaving mid-search. Safe after a
    // match too: the backend only cancels tickets still in the 'queued' state.
    if (_phase == _Phase.searching && !_navigated) {
      ref.read(matchmakingRepositoryProvider).cancel();
    }
    super.dispose();
  }

  Future<void> _startSearch(String mode) async {
    if (_phase != _Phase.choosing) return; // guard rapid double-taps
    setState(() {
      _mode = mode;
      _phase = _Phase.searching;
      _elapsed = 0;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });

    final res = await ref.read(matchmakingRepositoryProvider).enqueue(mode);
    if (!mounted) return;
    res.when(
      ok: (roomId) {
        if (roomId != null) {
          _enterMatched(roomId);
        } else {
          _pollTimer = Timer.periodic(
              const Duration(seconds: 2), (_) => _poll());
        }
      },
      err: (f) {
        _showError(f.message);
        _backToChoosing();
      },
    );
  }

  Future<void> _poll() async {
    if (_polling || _navigated || !mounted) return;
    _polling = true;
    try {
      final res = await ref.read(matchmakingRepositoryProvider).status();
      if (!mounted) return;
      res.when(
        ok: (s) {
          if (s.matched && s.roomId != null) {
            _enterMatched(s.roomId!);
          } else if (s.status == 'cancelled' || s.status == 'none') {
            _backToChoosing();
          }
        },
        err: (_) {/* transient — keep polling */},
      );
    } finally {
      _polling = false;
    }
  }

  Future<void> _enterMatched(int roomId) async {
    if (_navigated) return;
    _navigated = true;
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();

    final res = await ref.read(roomRepositoryProvider).show(roomId);
    if (!mounted) return;
    res.when(
      ok: (room) {
        ref.read(activeRoomProvider.notifier).state = room;
        context.go(AppRoutes.lobby);
      },
      err: (f) {
        _navigated = false;
        _showError(f.message);
        _backToChoosing();
      },
    );
  }

  void _backToChoosing() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    if (mounted) {
      setState(() {
        _phase = _Phase.choosing;
        _elapsed = 0;
      });
    }
  }

  Future<void> _cancelSearch() async {
    await ref.read(matchmakingRepositoryProvider).cancel();
    _backToChoosing();
  }

  void _playBots() {
    if (_navigated) return;
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    // Withdraw the queue ticket so the server doesn't later pair us elsewhere.
    if (_phase == _Phase.searching) {
      ref.read(matchmakingRepositoryProvider).cancel();
    }
    _navigated = true;
    final me = ref.read(authControllerProvider).valueOrNull;
    ref.read(gameConfigProvider.notifier).state = GameConfig.local(
      humans: 1,
      bots: _mode == '2p' ? 1 : 3,
      meName: me?.name,
      meAvatarUrl: me?.avatarUrl,
      meIsGuest: me?.isGuest ?? false,
    );
    context.go(AppRoutes.game);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _phase == _Phase.choosing
                ? _buildChooser()
                : _buildSearching(),
          ),
        ),
      ),
    );
  }

  Widget _buildChooser() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Online Match', style: AppTextStyles.display),
        const SizedBox(height: 8),
        Text('Pick a mode — we\'ll find you opponents.',
            style: AppTextStyles.body.copyWith(color: Colors.white70),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        _ModeChoice(
          title: '2 Players',
          subtitle: 'Head-to-head',
          icon: Icons.person_2_rounded,
          color: AppColors.tokenGreen,
          onTap: () => _startSearch('2p'),
        ),
        const SizedBox(height: 16),
        _ModeChoice(
          title: '4 Players',
          subtitle: 'Classic four-way race',
          icon: Icons.groups_rounded,
          color: AppColors.tokenRed,
          onTap: () => _startSearch('4p'),
        ),
        const SizedBox(height: 28),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          child: const Text('Back', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSearching() {
    final showFallback = _elapsed >= 6;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          child: Lottie.asset(
            AppAssets.loading,
            errorBuilder: (_, __, ___) =>
                const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text('Finding players…', style: AppTextStyles.display),
        const SizedBox(height: 8),
        Text('${_mode == '2p' ? '2-player' : '4-player'} · searching ${_elapsed}s',
            style: AppTextStyles.body.copyWith(color: Colors.white70)),
        const SizedBox(height: 36),
        if (showFallback) ...[
          Text('Taking a while — you can start against bots.',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          PrimaryButton(
              label: 'Play bots instead',
              icon: Icons.smart_toy,
              onPressed: _playBots),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: _cancelSearch,
          child:
              const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
