import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';

/// Random matchmaking. Online play (Phase 2) enqueues against the backend and
/// joins the matched game over the WebSocket. Until a server is reachable, this
/// offers a quick bot match so the player is never stuck waiting.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  Timer? _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    // TODO(phase2): ref.read(matchmakingRepositoryProvider).enqueue(...)
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _playBots() {
    ref.read(gameConfigProvider.notifier).state =
        GameConfig.local(humans: 1, bots: 3);
    context.go(AppRoutes.game);
  }

  @override
  Widget build(BuildContext context) {
    final showFallback = _elapsed >= 4;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                Text('Searching for ${_elapsed}s',
                    style: AppTextStyles.body.copyWith(color: Colors.white70)),
                const SizedBox(height: 36),
                if (showFallback) ...[
                  Text('No opponents yet.',
                      style:
                          AppTextStyles.body.copyWith(color: Colors.white70)),
                  const SizedBox(height: 12),
                  PrimaryButton(
                      label: 'Play bots instead',
                      icon: Icons.smart_toy,
                      onPressed: _playBots),
                  const SizedBox(height: 12),
                ],
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
