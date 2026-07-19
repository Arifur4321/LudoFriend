import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../game_engine/models/ludo_color.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_assets.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Celebration overlay shown when a match ends: raining confetti (drawn in
/// code, so it always plays), a golden trophy cup, and the winner's name in
/// their color, with Rematch / Home actions.
class WinnerOverlay extends StatefulWidget {
  const WinnerOverlay({
    super.key,
    required this.winner,
    required this.winnerName,
    required this.onRematch,
    required this.onHome,
    this.teamWin = false,
    this.teamLabel,
    this.teammateNames = const [],
  });

  final LudoColor winner;
  final String winnerName;
  final VoidCallback onRematch;
  final VoidCallback onHome;

  /// True when the match was a 2v2 team game — the overlay then celebrates the
  /// winning TEAM rather than a single player.
  final bool teamWin;

  /// e.g. 'Team A' — the headline shown when [teamWin].
  final String? teamLabel;

  /// The winning team's two player names, shown under the team headline.
  final List<String> teammateNames;

  @override
  State<WinnerOverlay> createState() => _WinnerOverlayState();
}

class _WinnerOverlayState extends State<WinnerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(widget.winner);
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        // Code-drawn confetti rain — guaranteed to play on every device.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.sizeOf(context),
              painter: _ConfettiPainter(progress: _confetti.value),
            ),
          ),
        ),
        // Bonus Lottie confetti when the asset is available.
        IgnorePointer(
          child: Lottie.asset(
            AppAssets.confetti,
            repeat: true,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Golden trophy cup on a laurel-gold medallion.
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFE082),
                          Color(0xFFFFB300),
                          Color(0xFFFF8F00),
                        ],
                      ),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(widget.teamWin ? 'WINNING TEAM' : 'WINNER',
                      style: AppTextStyles.label.copyWith(
                        color: const Color(0xFFFF8F00),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 4),
                  Text(
                      widget.teamWin
                          ? '${widget.teamLabel ?? 'Team'} wins! 🏆'
                          : '${widget.winnerName} wins! 🏆',
                      style: AppTextStyles.heading.copyWith(color: color),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                      widget.teamWin && widget.teammateNames.isNotEmpty
                          ? widget.teammateNames.join('  &  ')
                          : 'What a game 🎉',
                      style: AppTextStyles.bodyMuted,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  PrimaryButton(
                      label: 'Rematch',
                      icon: Icons.refresh,
                      onPressed: widget.onRematch),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    onPressed: widget.onHome,
                    gradient: const LinearGradient(
                        colors: [AppColors.inkSoft, AppColors.ink]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple deterministic confetti rain (no randomness source needed: each
/// piece's trajectory derives from its index).
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const List<Color> _palette = [
    Color(0xFFFF5A5F),
    Color(0xFF2BD9A1),
    Color(0xFF3A86FF),
    Color(0xFFFFB23E),
    Color(0xFFB388FF),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      // Pseudo-random but stable attributes per piece.
      final fx = (math.sin(i * 12.9898) * 43758.5453).abs() % 1.0;
      final speed = 0.55 + ((i * 37) % 10) / 18.0;
      final phase = ((i * 61) % 17) / 17.0;
      final t = (progress * speed + phase) % 1.0;

      final x = fx * size.width +
          math.sin((progress * 2 * math.pi * speed) + i) * 22;
      final y = t * (size.height + 40) - 20;
      final rot = (progress * 2 * math.pi * (1 + (i % 4))) + i;
      final c = _palette[i % _palette.length];

      paint.color = c.withValues(alpha: 0.92);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
              const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
