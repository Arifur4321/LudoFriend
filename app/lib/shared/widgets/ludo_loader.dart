import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A lively, on-brand loading indicator: four ludo tokens orbit a softly
/// pulsing centre die. Reusable anywhere a spinner is needed.
class LudoLoader extends StatefulWidget {
  const LudoLoader({super.key, this.size = 88});

  final double size;

  @override
  State<LudoLoader> createState() => _LudoLoaderState();
}

class _LudoLoaderState extends State<LudoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _LudoLoaderPainter(_c.value),
        ),
      ),
    );
  }
}

class _LudoLoaderPainter extends CustomPainter {
  _LudoLoaderPainter(this.t);

  /// 0..1 loop progress.
  final double t;

  static const _colors = [
    AppColors.tokenRed,
    AppColors.tokenGreen,
    AppColors.tokenYellow,
    AppColors.tokenBlue,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final orbit = size.width * 0.34;
    final tokenR = size.width * 0.13;
    final spin = t * 2 * math.pi;

    // Faint guide ring.
    canvas.drawCircle(
      center,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // Four orbiting tokens, each breathing slightly out of phase.
    for (var i = 0; i < 4; i++) {
      final a = spin + i * (math.pi / 2);
      final breathe = 1 + 0.18 * math.sin(spin + i * (math.pi / 2));
      final pos = center + Offset(math.cos(a), math.sin(a)) * orbit;
      final r = tokenR * breathe;
      final color = _colors[i];

      // Soft shadow for depth.
      canvas.drawCircle(
        pos + const Offset(0, 1.5),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      // Token body.
      canvas.drawCircle(pos, r, Paint()..color = color);
      // Glossy highlight.
      canvas.drawCircle(
        pos - Offset(r * 0.3, r * 0.35),
        r * 0.34,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Centre die: a rounded square counter-rotating with a pip pattern.
    final dieSize = size.width * 0.24;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-spin * 0.6);
    final dieRect = Rect.fromCenter(
        center: Offset.zero, width: dieSize, height: dieSize);
    final rrect = RRect.fromRectAndRadius(dieRect, Radius.circular(dieSize * 0.28));
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white,
    );
    // Five pips.
    final pip = dieSize * 0.10;
    final off = dieSize * 0.26;
    final pipPaint = Paint()..color = AppColors.primary;
    for (final p in [
      Offset(-off, -off),
      Offset(off, -off),
      Offset.zero,
      Offset(-off, off),
      Offset(off, off),
    ]) {
      canvas.drawCircle(p, pip, pipPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LudoLoaderPainter old) => old.t != t;
}

/// A full-screen, dimmed + blurred loading overlay with a label. Place it as
/// the top layer of a Stack; toggle [visible]. Absorbs touches while shown.
class LudoLoadingOverlay extends StatelessWidget {
  const LudoLoadingOverlay({
    super.key,
    required this.visible,
    this.message = 'Just a moment…',
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher cross-fades in/out AND removes the (expensive) blurred
    // subtree when hidden — so the BackdropFilter only composites while the
    // overlay is actually shown, avoiding continuous blur cost on the login
    // screen.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: visible
            ? Stack(
                key: const ValueKey('ludo-loading'),
                fit: StackFit.expand,
                children: [
                  // Blurred, dimmed backdrop.
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(color: Colors.black.withValues(alpha: 0.45)),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LudoLoader(size: 96),
                          const SizedBox(height: 18),
                          Text(
                            message,
                            style: AppTextStyles.title.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(key: ValueKey('ludo-idle')),
      ),
    );
  }
}
