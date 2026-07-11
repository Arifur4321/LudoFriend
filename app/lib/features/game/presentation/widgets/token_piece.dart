import 'package:flutter/material.dart';

import '../../../../game_engine/models/token.dart';
import '../../../../shared/theme/app_colors.dart';

/// A single rendered pawn. Drawn in code (no asset scaling blur): a chess-pawn
/// silhouette in the player's color with a radial highlight, dark rim, white
/// outline and a soft ground shadow — so every player's pieces are large,
/// glossy and instantly distinguishable. Pulses with a glow ring when it is a
/// legal move target.
class TokenPiece extends StatefulWidget {
  const TokenPiece({
    super.key,
    required this.token,
    required this.size,
    this.movable = false,
    this.onTap,
  });

  final Token token;
  final double size;
  final bool movable;
  final VoidCallback? onTap;

  @override
  State<TokenPiece> createState() => _TokenPieceState();
}

class _TokenPieceState extends State<TokenPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    lowerBound: 0.96,
    upperBound: 1.14,
  );

  @override
  void initState() {
    super.initState();
    if (widget.movable) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TokenPiece old) {
    super.didUpdateWidget(old);
    if (widget.movable && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.movable && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final piece = CustomPaint(
      size: Size.square(widget.size),
      painter: _PawnPainter(
        color: AppColors.of(widget.token.color),
        glow: widget.movable,
      ),
    );
    final child =
        widget.movable ? ScaleTransition(scale: _pulse, child: piece) : piece;
    // Non-tappable pawns must not swallow taps: at the larger pawn size,
    // neighbours overlap slightly and an opaque dead pawn could shave the
    // edge of a movable pawn's tap target.
    if (widget.onTap == null) {
      return IgnorePointer(child: child);
    }
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class _PawnPainter extends CustomPainter {
  const _PawnPainter({required this.color, required this.glow});

  final Color color;
  final bool glow;

  Color _shade(Color c, double amount) =>
      Color.lerp(c, Colors.black, amount) ?? c;
  Color _tint(Color c, double amount) =>
      Color.lerp(c, Colors.white, amount) ?? c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    // Glow halo behind a movable pawn.
    if (glow) {
      final glowPaint = Paint()
        ..color = _tint(color, 0.35).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset(cx, s * 0.52), s * 0.46, glowPaint);
    }

    // Soft ground shadow.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, s * 0.90), width: s * 0.62, height: s * 0.16),
      shadow,
    );

    // Pawn silhouette: head + curved waist flaring into the base.
    final body = Path()
      // Base (bottom bar with rounded corners).
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, s * 0.82), width: s * 0.64, height: s * 0.16),
        Radius.circular(s * 0.08),
      ))
      // Waist: narrow at the neck, flaring down onto the base.
      ..moveTo(cx - s * 0.13, s * 0.40)
      ..cubicTo(cx - s * 0.16, s * 0.56, cx - s * 0.30, s * 0.66, cx - s * 0.26,
          s * 0.78)
      ..lineTo(cx + s * 0.26, s * 0.78)
      ..cubicTo(cx + s * 0.30, s * 0.66, cx + s * 0.16, s * 0.56, cx + s * 0.13,
          s * 0.40)
      ..close()
      // Head.
      ..addOval(Rect.fromCircle(center: Offset(cx, s * 0.28), radius: s * 0.20));

    // White outline first (slightly thicker), so the piece pops on any cell.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..color = Colors.white;
    canvas.drawPath(body, outline);

    // Fill with a top-lit radial gradient of the player color.
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.55),
        radius: 1.15,
        colors: [_tint(color, 0.45), color, _shade(color, 0.28)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    canvas.drawPath(body, fill);

    // Dark rim for depth.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..color = _shade(color, 0.45).withValues(alpha: 0.85);
    canvas.drawPath(body, rim);

    // Glossy highlight on the head.
    final gloss = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - s * 0.07, s * 0.21),
          width: s * 0.14,
          height: s * 0.10),
      gloss,
    );
  }

  @override
  bool shouldRepaint(_PawnPainter old) =>
      old.color != color || old.glow != glow;
}
