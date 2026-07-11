import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Flash a ~1 second "token reached home" celebration over the current screen:
/// a starburst of rays + sparks in the player's color and a rising
/// "🎉 Home!" chip. Purely visual, auto-removes itself, never blocks input.
void flashTokenHome(BuildContext context, Color color) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _CelebrationBurst(color: color, onDone: () {
        if (entry.mounted) entry.remove();
      }),
    ),
  );
  overlay.insert(entry);
}

class _CelebrationBurst extends StatefulWidget {
  const _CelebrationBurst({required this.color, required this.onDone});

  final Color color;
  final VoidCallback onDone;

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final fade = t < 0.15
            ? t / 0.15
            : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: MediaQuery.sizeOf(context),
              painter: _BurstPainter(
                  progress: t, color: widget.color, opacity: fade),
            ),
            Transform.translate(
              offset: Offset(0, -40 * t),
              child: Opacity(
                opacity: fade,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: widget.color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    '🎉 Home!',
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(
      {required this.progress, required this.color, required this.opacity});

  final double progress;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final maxR = size.shortestSide * 0.42;
    final r = maxR * Curves.easeOutCubic.transform(progress);

    final ray = Paint()
      ..color = color.withValues(alpha: 0.85 * opacity)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final spark = Paint()
      ..color = Colors.amber.withValues(alpha: 0.9 * opacity);

    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a));
      // Rays: short segments flying outward.
      canvas.drawLine(
          center + dir * (r * 0.72), center + dir * r, ray);
      // Sparks: dots between rays, slightly behind.
      final sa = a + math.pi / 12;
      final sdir = Offset(math.cos(sa), math.sin(sa));
      canvas.drawCircle(
          center + sdir * (r * 0.85), 5 * (1 - progress) + 2, spark);
    }

    // Expanding ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.7 * opacity);
    canvas.drawCircle(center, r * 0.6, ring);
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.opacity != opacity;
}
