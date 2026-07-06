import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';

/// A weighted-looking prize wheel. It only *renders* the segments; the parent
/// drives [rotation] with an AnimationController so the winning segment (chosen
/// by the server) lands under the fixed top pointer.
class SpinWheel extends StatelessWidget {
  const SpinWheel({super.key, required this.rewards, required this.rotation});

  final List<int> rewards;
  final double rotation; // radians

  static const _wedgeColors = [
    Color(0xFF6A4CE0),
    Color(0xFF8E6BFF),
    Color(0xFFFF6B6B),
    Color(0xFFFFB23E),
    Color(0xFF2BD9A1),
    Color(0xFF3A86FF),
    Color(0xFF7C4DFF),
    Color(0xFFFF8FB1),
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: Size.infinite,
              painter: _WheelPainter(rewards: rewards, colors: _wedgeColors),
            ),
          ),
          // Hub.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.casino_rounded, color: Color(0xFF6A4CE0)),
          ),
          // Fixed pointer at the top.
          Positioned(
            top: -2,
            child: CustomPaint(size: const Size(30, 26), painter: _PointerPainter()),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.rewards, required this.colors});
  final List<int> rewards;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final n = rewards.length;
    if (n == 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final seg = 2 * math.pi / n;

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 - seg / 2 + i * seg; // segment 0 centered on top
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, seg, true, paint,
      );
      // Divider.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, seg, true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.6),
      );

      // Reward label along the mid-angle.
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: compactCoins(rewards[i]),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelRadius = radius * 0.66;
      final pos = center +
          Offset(math.cos(mid) * labelRadius, math.sin(mid) * labelRadius);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(mid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer rim.
    canvas.drawCircle(
      center, radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.rewards != rewards;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawShadow(p, Colors.black, 3, false);
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFC542));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
