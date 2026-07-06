import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_gradients.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../wallet/presentation/widgets/coin_balance_chip.dart';
import '../application/spin_controller.dart';
import '../data/spin_models.dart';
import 'widgets/spin_wheel.dart';

class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  Animation<double> _anim = const AlwaysStoppedAnimation(0);
  double _rotation = 0;
  bool _spinning = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the countdown every second when a spin is on cooldown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _onSpin(SpinStatus status) async {
    if (_spinning || !status.canSpin) return;
    setState(() => _spinning = true);

    final result = await ref.read(spinControllerProvider.notifier).spin();

    result.when(
      ok: (r) {
        final n = status.rewards.isEmpty ? 1 : status.rewards.length;
        final seg = 2 * math.pi / n;
        final desiredRaw = (-r.segmentIndex * seg) % (2 * math.pi);
        final desired = desiredRaw < 0 ? desiredRaw + 2 * math.pi : desiredRaw;
        final currentMod = _rotation % (2 * math.pi);
        var delta = desired - currentMod;
        if (delta < 0) delta += 2 * math.pi;
        final target = _rotation + 2 * math.pi * 5 + delta;

        _anim = Tween<double>(begin: _rotation, end: target)
            .animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic));
        _spin.forward(from: 0).whenComplete(() {
          _rotation = target;
          if (mounted) {
            setState(() => _spinning = false);
            _showReward(r.reward);
          }
        });
      },
      err: (f) {
        setState(() => _spinning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message)),
        );
      },
    );
  }

  void _showReward(int reward) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('You won!', textAlign: TextAlign.center, style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 48),
            const SizedBox(height: 12),
            Text('+${formatCoins(reward)} coins',
                style: AppTextStyles.title.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('Come back in an hour for another free spin!',
                style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: PrimaryButton(
              label: 'Awesome',
              expand: false,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(spinControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Spin'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: Center(child: CoinBalanceChip(compact: true))),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => _Message(text: 'Could not load the spin wheel.'),
            data: (status) {
              if (status == null || !status.enabled) {
                return _Message(text: 'Daily spin is currently unavailable.');
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                child: Column(
                  children: [
                    Text('Spin once a day for free coins!',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _spin,
                          builder: (_, __) => SpinWheel(
                            rewards: status.rewards,
                            rotation: _spinning ? _anim.value : _rotation,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (status.canSpin)
                      PrimaryButton(
                        label: _spinning ? 'Spinning…' : 'SPIN',
                        icon: Icons.casino_rounded,
                        gradient: AppGradients.accentButton,
                        loading: _spinning,
                        onPressed: _spinning ? null : () => _onSpin(status),
                      )
                    else
                      _Cooldown(until: status.nextAvailableAt),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cooldown extends StatelessWidget {
  const _Cooldown({required this.until});
  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = until?.difference(now) ?? Duration.zero;
    final txt = remaining.isNegative ? 'Ready soon…' : _fmt(remaining);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Text('Next free spin in  $txt',
          style: AppTextStyles.title.copyWith(color: Colors.white)),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              style: AppTextStyles.title.copyWith(color: Colors.white),
              textAlign: TextAlign.center),
        ),
      );
}
