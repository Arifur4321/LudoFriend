import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/board_theme.dart';

/// A real 3D-looking six-sided die, drawn as an isometric cube (top + two side
/// faces, each shaded and pipped). While [rolling] it tumbles (hops, rocks,
/// squashes) and flickers faces, then lands on [face] with a springy overshoot.
/// Face colours follow the active board tier; [tint] colours the drop shadow.
/// Tapping calls [onRoll] when [enabled].
class DiceWidget extends ConsumerStatefulWidget {
  const DiceWidget({
    super.key,
    required this.face,
    required this.rolling,
    required this.enabled,
    required this.onRoll,
    this.size = 66,
    this.tint = AppColors.primary,
  });

  final int? face;
  final bool rolling;
  final bool enabled;
  final VoidCallback onRoll;
  final double size;
  final Color tint;

  @override
  ConsumerState<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends ConsumerState<DiceWidget>
    with TickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  final math.Random _rng = math.Random();
  int _shown = 1;

  @override
  void initState() {
    super.initState();
    _shown = widget.face ?? 1;
    if (widget.rolling) _roll.repeat();
  }

  @override
  void didUpdateWidget(covariant DiceWidget old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _roll.repeat();
    } else if (!widget.rolling && old.rolling) {
      _roll.reset();
      setState(() => _shown = widget.face ?? _shown);
      _settle.forward(from: 0); // springy landing
    } else if (!widget.rolling && widget.face != null) {
      _shown = widget.face!;
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(activeBoardThemeProvider);

    return GestureDetector(
      onTap: widget.enabled && !widget.rolling ? widget.onRoll : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_roll, _settle]),
        builder: (context, child) {
          final rolling = widget.rolling;
          final face = rolling ? (_rng.nextInt(6) + 1) : (widget.face ?? _shown);

          double angle = 0, bounce = 0, sx = 1, sy = 1;
          if (rolling) {
            final t = _roll.value;
            bounce = -math.sin(t * math.pi) * widget.size * 0.22; // hop
            angle = math.sin(t * 2 * math.pi) * 0.5; // rock, not a full spin
            sy = 0.82 + 0.18 * math.cos(t * 2 * math.pi).abs(); // squash
          } else if (_settle.isAnimating) {
            final e = Curves.elasticOut.transform(_settle.value);
            sx = sy = 0.86 + 0.14 * e; // overshoot into place
          }

          return Opacity(
            opacity: widget.enabled || rolling ? 1 : 0.6,
            child: Transform.translate(
              offset: Offset(0, bounce),
              child: Transform.rotate(
                angle: angle,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(sx, sy, 1),
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: CustomPaint(
                      painter: _CubeDiePainter(
                        face: face,
                        top: theme.diceTop,
                        bottom: theme.diceBottom,
                        pip: theme.dicePip,
                        shadow: widget.tint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints an isometric cube die: a top diamond + left and right parallelogram
/// faces, each shaded and carrying real pips. The top face shows the rolled
/// value; the side faces show two valid adjacent faces so it reads as a real
/// die from a corner.
class _CubeDiePainter extends CustomPainter {
  _CubeDiePainter({
    required this.face,
    required this.top,
    required this.bottom,
    required this.pip,
    required this.shadow,
  });

  final int face; // top face value
  final Color top;
  final Color bottom;
  final Color pip;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final u = s * 0.32; // top diamond half-width
    final v = u * 0.5; // top diamond half-height (2:1 iso)
    final h = s * 0.34; // side face height
    final cx = s * 0.5;
    // Vertically centre the cube (it spans v above and v+h below its centre).
    final cy = s * 0.5 - h / 2;

    // Cube corners.
    final t = Offset(cx, cy - v); // top
    final l = Offset(cx - u, cy); // left
    final r = Offset(cx + u, cy); // right
    final b = Offset(cx, cy + v); // front-middle
    final l2 = Offset(cx - u, cy + h); // left-down
    final r2 = Offset(cx + u, cy + h); // right-down
    final b2 = Offset(cx, cy + v + h); // front-bottom

    // Contact shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + v + h * 0.95), width: u * 2.0, height: v * 1.1),
      Paint()
        ..color = shadow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Face colours (top brightest, right darkest).
    final topA = _lerp(top, Colors.white, 0.06);
    final topB = _lerp(top, bottom, 0.35);
    final leftC = _lerp(top, bottom, 0.55);
    final rightC = _lerp(bottom, Colors.black, 0.10);

    // Left face.
    _fillQuad(canvas, [l, b, b2, l2], leftC, _lerp(leftC, Colors.black, 0.08));
    // Right face.
    _fillQuad(canvas, [b, r, r2, b2], rightC, _lerp(rightC, Colors.black, 0.06));
    // Top face.
    _fillQuad(canvas, [l, t, r, b], topA, topB);

    // Edge outlines for crisp definition.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: 0.16);
    // Silhouette.
    canvas.drawPath(
      Path()
        ..moveTo(t.dx, t.dy)
        ..lineTo(r.dx, r.dy)
        ..lineTo(r2.dx, r2.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(l2.dx, l2.dy)
        ..lineTo(l.dx, l.dy)
        ..close(),
      edge,
    );
    // Inner edges (the three that meet at the front-top corner b).
    canvas.drawLine(l, b, edge);
    canvas.drawLine(r, b, edge);
    canvas.drawLine(b, b2, edge);

    // Top-face gloss.
    canvas.save();
    canvas.clipPath(Path()
      ..moveTo(l.dx, l.dy)
      ..lineTo(t.dx, t.dy)
      ..lineTo(r.dx, r.dy)
      ..lineTo(b.dx, b.dy)
      ..close());
    canvas.drawCircle(Offset(cx - u * 0.2, cy - v * 0.4), u * 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.restore();

    // Pips: top = rolled value, sides = two valid adjacent faces.
    final sides = _sideFaces(face);
    _pipsOnQuad(canvas, [l, t, r, b], face, pip, u * 0.155);
    _pipsOnQuad(canvas, [l, b, b2, l2], sides[0], pip, u * 0.135);
    _pipsOnQuad(canvas, [b, r, r2, b2], sides[1], pip, u * 0.135);
  }

  // ---- helpers -------------------------------------------------------------

  Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  Rect _bounds(List<Offset> q) {
    var minX = q.first.dx, maxX = q.first.dx, minY = q.first.dy, maxY = q.first.dy;
    for (final p in q) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _fillQuad(Canvas canvas, List<Offset> q, Color topColor, Color bottomColor) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(_bounds(q));
    final path = Path()
      ..moveTo(q[0].dx, q[0].dy)
      ..lineTo(q[1].dx, q[1].dy)
      ..lineTo(q[2].dx, q[2].dy)
      ..lineTo(q[3].dx, q[3].dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Bilinear map of a unit-square point onto a quad (corners in P00,P10,P11,P01
  /// order), then draw the face's pips there.
  void _pipsOnQuad(Canvas canvas, List<Offset> q, int value, Color color, double radius) {
    Offset mapPoint(double pu, double pv) {
      final topEdge = Offset.lerp(q[0], q[1], pu)!;
      final botEdge = Offset.lerp(q[3], q[2], pu)!;
      return Offset.lerp(topEdge, botEdge, pv)!;
    }

    for (final p in _pips(value)) {
      final c = mapPoint(p.dx, p.dy);
      canvas.drawCircle(c.translate(0, radius * 0.16), radius,
          Paint()..color = Colors.black.withValues(alpha: 0.16));
      canvas.drawCircle(c, radius, Paint()..color = color);
      canvas.drawCircle(c.translate(-radius * 0.28, -radius * 0.3), radius * 0.34,
          Paint()..color = Colors.white.withValues(alpha: 0.4));
    }
  }

  /// Two visible side faces for a given top value — both adjacent to the top and
  /// to each other, so the corner is a valid die corner.
  List<int> _sideFaces(int topValue) {
    final opp = 7 - topValue;
    final avail = [1, 2, 3, 4, 5, 6]
        .where((x) => x != topValue && x != opp)
        .toList();
    final left = avail.first;
    final right = avail.firstWhere(
      (x) => x != left && x != (7 - left),
      orElse: () => avail[1],
    );
    return [left, right];
  }

  /// Unit-square pip centres for a die face.
  List<Offset> _pips(int f) {
    const a = 0.27, b = 0.5, c = 0.73;
    switch (f) {
      case 1:
        return const [Offset(b, b)];
      case 2:
        return const [Offset(a, a), Offset(c, c)];
      case 3:
        return const [Offset(a, a), Offset(b, b), Offset(c, c)];
      case 4:
        return const [Offset(a, a), Offset(c, a), Offset(a, c), Offset(c, c)];
      case 5:
        return const [
          Offset(a, a), Offset(c, a), Offset(b, b), Offset(a, c), Offset(c, c)
        ];
      case 6:
        return const [
          Offset(a, a), Offset(c, a), Offset(a, b),
          Offset(c, b), Offset(a, c), Offset(c, c)
        ];
      default:
        return const [Offset(b, b)];
    }
  }

  @override
  bool shouldRepaint(covariant _CubeDiePainter old) =>
      old.face != face ||
      old.top != top ||
      old.bottom != bottom ||
      old.pip != pip ||
      old.shadow != shadow;
}
