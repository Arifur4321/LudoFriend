import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/local_cache.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/bouncing_button.dart';
import '../../../wallet/presentation/widgets/coin_balance_chip.dart';
import '../../application/spin_controller.dart';

/// Shown once per app session: if a free spin is ready when the home screen
/// appears, prompt the player to claim it.
final spinPromptShownProvider = StateProvider<bool>((ref) => false);

/// A prominent home tile for the free spin. Glows + pulses when a spin is ready,
/// otherwise shows a live countdown to the next one. Also fires the one-time
/// "your free spin is ready" popup.
class FreeSpinBadge extends ConsumerStatefulWidget {
  const FreeSpinBadge({super.key});

  @override
  ConsumerState<FreeSpinBadge> createState() => _FreeSpinBadgeState();
}

class _FreeSpinBadgeState extends ConsumerState<FreeSpinBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.0,
    upperBound: 1.0,
  )..repeat(reverse: true);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _showReadyPopup() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Free spin ready!',
            textAlign: TextAlign.center, style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, size: 52, color: AppColors.accent),
            const SizedBox(height: 12),
            Text('Spin the wheel now for bonus coins — a fresh spin unlocks every hour.',
                style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.spin);
            },
            child: const Text('Spin now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // One-time popup when a spin is confirmed ready.
    ref.listen(spinControllerProvider, (prev, next) {
      final s = next.valueOrNull;
      if (s != null && s.canSpin && !ref.read(spinPromptShownProvider)) {
        ref.read(spinPromptShownProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showReadyPopup();
        });
      }
    });

    final async = ref.watch(spinControllerProvider);
    final status = async.valueOrNull;
    final cachedNext = ref.read(localCacheProvider).nextFreeSpinAt;
    final nextAt = status?.nextAvailableAt ?? cachedNext;
    final ready = status?.canSpin ?? (nextAt == null || DateTime.now().isAfter(nextAt));

    return BouncingButton(
      onTap: () => context.push(AppRoutes.spin),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = ready ? (0.25 + 0.35 * _pulse.value) : 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ready
                    ? const [Color(0xFFFFB23E), Color(0xFFFF7A59)]
                    : [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.82)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: glow),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ready ? Colors.white.withValues(alpha: 0.28) : AppColors.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.casino_rounded,
                  color: ready ? Colors.white : AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Free Spin',
                      style: AppTextStyles.title.copyWith(
                          color: ready ? Colors.white : AppColors.ink)),
                  Text(
                    ready ? 'Tap to win bonus coins!' : 'Next free spin in ${_fmt(nextAt)}',
                    style: AppTextStyles.bodyMuted.copyWith(
                        color: ready ? Colors.white70 : AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            if (ready)
              const CoinIcon(size: 26)
            else
              const Icon(Icons.timer_outlined, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? next) {
    if (next == null) return '00:00';
    var d = next.difference(DateTime.now());
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    }
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
