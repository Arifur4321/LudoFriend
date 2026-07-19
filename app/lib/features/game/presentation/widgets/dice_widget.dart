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
    this.size = 78,
    this.tapTargetSize = 64,
    this.tint = AppColors.primary,
  });

  final int? face;
  final bool rolling;
  final bool enabled;
  final VoidCallback onRoll;
  final double size;
  final double tapTargetSize;
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

  bool get _canRoll => widget.enabled && !widget.rolling;

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
    final targetSize = math.max(widget.size, widget.tapTargetSize);

    return Semantics(
      button: true,
      enabled: _canRoll,
      label: _canRoll ? 'Roll dice' : 'Dice',
      onTap: _canRoll ? widget.onRoll : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        // React on the first press instead of waiting for a full tap-up
        // gesture. This matches the board-level pawn input and makes the die
        // reliable on small/high-density phone screens. The controller's
        // synchronous busy guard guarantees one server request per press.
        onPointerDown: _canRoll ? (_) => widget.onRoll() : null,
        child: SizedBox.square(
          dimension: targetSize,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_roll, _settle]),
              builder: (context, child) {
                final rolling = widget.rolling;
                final face =
                    rolling ? (_rng.nextInt(6) + 1) : (widget.face ?? _shown);

                double angle = 0, bounce = 0, sx = 1, sy = 1;
                if (rolling) {
                  final t = _roll.value;
                  // Hover + tumble CONTINUOUSLY while waiting on the server: the
                  // die never drops back to the ground mid-wait, so a single roll
                  // reads as one ongoing throw instead of a series of hops that
                  // each looked like a separate roll (the "dice rolls multiple
                  // times" report). It settles onto the authoritative face via
                  // _settle the instant `rolling` clears.
                  bounce =
                      -widget.size * (0.16 + 0.06 * math.sin(t * 2 * math.pi));
                  angle = math.sin(t * 2 * math.pi) * 0.5;
                  sy = 0.82 + 0.18 * math.cos(t * 2 * math.pi).abs();
                } else if (_settle.isAnimating) {
                  final e = Curves.elasticOut.transform(_settle.value);
                  sx = sy = 0.86 + 0.14 * e;
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
          ),
        ),
      ),
    );
  }
}

/// Paints a crisp, readable die face with a small 3D bevel. The front face
/// carries the rolled value, keeping the number understandable while the shadow
/// and side facets make it feel physical.
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
    final side = s * 0.1;
    final inset = s * 0.08;
    final radius = s * 0.18;
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, s - inset * 2 - side, s - inset * 2 - side),
      Radius.circular(radius),
    );
    final sideRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(front.right - radius * 0.35, front.top + side,
          side + radius * 0.35, front.height),
      Radius.circular(radius * 0.72),
    );
    final bottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(front.left + side, front.bottom - radius * 0.35,
          front.width, side + radius * 0.35),
      Radius.circular(radius * 0.72),
    );
    final frontRect = front.outerRect;
    final pipColor = Color.lerp(pip, Colors.black, 0.08) ?? pip;
    final cx = frontRect.center.dx;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.52, s * 0.88),
        width: s * 0.78,
        height: s * 0.18,
      ),
      Paint()
        ..color = shadow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final sidePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _lerp(bottom, Colors.white, 0.06),
          _lerp(bottom, Colors.black, 0.2),
        ],
      ).createShader(sideRect.outerRect);
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _lerp(bottom, Colors.white, 0.02),
          _lerp(bottom, Colors.black, 0.22),
        ],
      ).createShader(bottomRect.outerRect);

    canvas.drawRRect(sideRect, sidePaint);
    canvas.drawRRect(bottomRect, bottomPaint);

    canvas.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _lerp(top, Colors.white, 0.45),
            top,
            _lerp(bottom, Colors.black, 0.04),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(frontRect),
    );

    canvas.drawRRect(
      front.deflate(s * 0.025),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    canvas.drawRRect(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.032
        ..strokeJoin = StrokeJoin.round
        ..color = _lerp(shadow, Colors.black, 0.18).withValues(alpha: 0.55),
    );

    canvas.drawLine(
      Offset(front.right, front.top + radius * 0.48),
      Offset(front.right + side * 0.62, front.top + side + radius * 0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.13),
    );
    canvas.drawLine(
      Offset(front.left + radius * 0.48, front.bottom),
      Offset(front.left + side + radius * 0.35, front.bottom + side * 0.62),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.12),
    );

    canvas.save();
    canvas.clipRRect(front);
    canvas.drawCircle(
      Offset(cx - s * 0.12, front.top + s * 0.13),
      s * 0.32,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.restore();

    final radiusPip = s * 0.068;
    for (final p in _pipCenters(face)) {
      final c = Offset(
        frontRect.left + frontRect.width * p.dx,
        frontRect.top + frontRect.height * p.dy,
      );
      canvas.drawCircle(
        c.translate(s * 0.012, s * 0.014),
        radiusPip * 1.05,
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        c,
        radiusPip,
        Paint()..color = pipColor,
      );
      canvas.drawCircle(
        c.translate(-radiusPip * 0.26, -radiusPip * 0.28),
        radiusPip * 0.34,
        Paint()..color = Colors.white.withValues(alpha: 0.34),
      );
    }
  }

  // ---- helpers -------------------------------------------------------------

  Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  /// Unit-square pip centres for a die face.
  List<Offset> _pipCenters(int f) {
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
          Offset(a, a),
          Offset(c, a),
          Offset(b, b),
          Offset(a, c),
          Offset(c, c)
        ];
      case 6:
        return const [
          Offset(a, a),
          Offset(c, a),
          Offset(a, b),
          Offset(c, b),
          Offset(a, c),
          Offset(c, c)
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
