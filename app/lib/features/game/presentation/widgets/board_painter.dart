import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../game_engine/board_layout.dart';
import '../../../../game_engine/models/ludo_color.dart';
import '../../../../game_engine/rules/rule_config.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/board_theme.dart';

/// Paints the static Ludo board with a faux-3D treatment: a graded base with a
/// vignette, per-tier motif, embossed/beveled cells and yards, glossy centre,
/// and a raised frame. Gameplay geometry (BoardLayout) is unchanged, so tokens
/// and rules line up exactly; the [theme] restyles the surface per staked tier.
///
/// Tokens and dice are drawn as widgets on top of this (see `LudoBoard`).
class BoardPainter extends CustomPainter {
  const BoardPainter({
    this.highlightCells = const {},
    this.theme = BoardTheme.classic,
  });

  /// Absolute ring indices to highlight (valid landing targets), drawn faintly.
  final Set<int> highlightCells;

  /// Visual identity for the current board tier.
  final BoardTheme theme;

  static final Map<int, LudoColor> _startOwner = {
    for (final c in LudoColor.values) c.startOffset: c,
  };

  // ---- shading helpers -----------------------------------------------------

  static Color _lighten(Color c, [double amt = 0.16]) =>
      Color.lerp(c, Colors.white, amt) ?? c;
  static Color _darken(Color c, [double amt = 0.20]) =>
      Color.lerp(c, Colors.black, amt) ?? c;

  Paint _vGradient(Rect r, Color top, Color bottom) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ).createShader(r);

  /// A thin two-tone bevel: light top/left edges, dark bottom/right edges.
  void _bevel(Canvas canvas, Rect r, double cell) {
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = theme.bevelHi;
    final lo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = theme.bevelLo;
    canvas.drawLine(r.topLeft, r.topRight, hi);
    canvas.drawLine(r.topLeft, r.bottomLeft, hi);
    canvas.drawLine(r.bottomLeft, r.bottomRight, lo);
    canvas.drawLine(r.topRight, r.bottomRight, lo);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardLayout.gridSize;
    final boardRect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(boardRect, Radius.circular(cell * 0.6));

    // Graded base.
    canvas.drawRRect(rrect, _vGradient(boardRect, theme.base, theme.baseAlt));

    canvas.save();
    canvas.clipRRect(rrect);

    // Edge vignette for depth.
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: theme.isDark ? 0.30 : 0.10),
          ],
          stops: const [0.62, 1.0],
        ).createShader(boardRect),
    );

    // Faint centre watermark + per-tier motif.
    canvas.drawCircle(boardRect.center, size.width * 0.30,
        Paint()..color = theme.watermark.withValues(alpha: 0.06));
    _drawPattern(canvas, size, cell);

    _drawYards(canvas, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawCenter(canvas, cell);

    canvas.restore();

    // Raised frame: main colour + inner gloss + (premium) accent ring.
    final fw = cell * (theme.premium ? 0.16 : 0.11);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw
        ..color = theme.frame,
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(fw * 0.35), Radius.circular(cell * 0.55)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw * 0.4
        ..color = theme.bevelHi,
    );
    canvas.restore();

    if (theme.premium) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(boardRect.deflate(cell * 0.42), Radius.circular(cell * 0.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05
          ..color = theme.frame.withValues(alpha: 0.55),
      );
    }
  }

  Rect _cellRect(num row, num col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  void _drawPattern(Canvas canvas, Size size, double cell) {
    final paint = Paint()..color = theme.watermark.withValues(alpha: 0.05);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.04
      ..color = theme.watermark.withValues(alpha: 0.05);
    switch (theme.pattern) {
      case BoardPattern.none:
        break;
      case BoardPattern.dots:
        for (var x = 0.0; x < size.width; x += cell) {
          for (var y = 0.0; y < size.height; y += cell) {
            canvas.drawCircle(Offset(x + cell / 2, y + cell / 2), cell * 0.06, paint);
          }
        }
        break;
      case BoardPattern.diagonal:
        for (var x = -size.height; x < size.width; x += cell * 0.9) {
          canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), stroke);
        }
        break;
      case BoardPattern.grid:
        for (var x = 0.0; x <= size.width; x += cell) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
        }
        for (var y = 0.0; y <= size.height; y += cell) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
        }
        break;
      case BoardPattern.rings:
        for (var r = cell; r < size.width; r += cell * 1.1) {
          canvas.drawCircle(size.center(Offset.zero), r, stroke);
        }
        break;
      case BoardPattern.sparkle:
        final rnd = math.Random(7);
        for (var i = 0; i < 26; i++) {
          final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
          final s = cell * (0.10 + rnd.nextDouble() * 0.12);
          canvas.drawLine(c.translate(-s, 0), c.translate(s, 0), stroke);
          canvas.drawLine(c.translate(0, -s), c.translate(0, s), stroke);
        }
        break;
    }
  }

  void _drawYards(Canvas canvas, double cell) {
    BoardLayout.baseOrigin.forEach((color, origin) {
      final base = AppColors.of(color);
      final outer = Rect.fromLTWH(origin.y * cell, origin.x * cell, 6 * cell, 6 * cell);
      // Graded, raised yard.
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer, Radius.circular(cell * 0.5)),
        _vGradient(outer, _lighten(base), _darken(base)),
      );
      _bevel(canvas, outer.deflate(cell * 0.06), cell);

      final inner = outer.deflate(cell * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.4)),
        _vGradient(inner, Colors.white, const Color(0xFFEDEDF3)),
      );
      // Inner shadow line at the top of the well.
      canvas.drawLine(
        inner.topLeft + Offset(cell * 0.2, cell * 0.04),
        inner.topRight - Offset(cell * 0.2, -cell * 0.04),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05
          ..color = Colors.black.withValues(alpha: 0.06),
      );

      for (final slot in BoardLayout.baseSlots[color]!) {
        final center = Offset((slot.col + 0.5) * cell, (slot.row + 0.5) * cell);
        final nest = Rect.fromCircle(center: center, radius: cell * 0.42);
        canvas.drawCircle(center, cell * 0.42,
            _vGradient(nest, _lighten(base, 0.55), _lighten(base, 0.3)));
        canvas.drawCircle(
          center,
          cell * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = _darken(base, 0.05),
        );
        // Glossy highlight.
        canvas.drawCircle(center - Offset(cell * 0.12, cell * 0.14), cell * 0.12,
            Paint()..color = Colors.white.withValues(alpha: 0.5));
      }
    });
  }

  void _drawTrack(Canvas canvas, double cell) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = theme.line;

    for (var i = 0; i < BoardLayout.ringCells.length; i++) {
      final p = BoardLayout.ringCells[i];
      final rect = _cellRect(p.x, p.y, cell);
      final owner = _startOwner[i];
      final base = owner != null ? AppColors.of(owner) : Colors.white;

      canvas.drawRect(rect, _vGradient(rect, _lighten(base, owner != null ? 0.16 : 0.02), _darken(base, owner != null ? 0.16 : 0.06)));
      canvas.drawRect(rect, border);
      _bevel(canvas, rect.deflate(cell * 0.02), cell);

      if (RuleConfig.defaultSafeCells.contains(i)) {
        _drawStar(canvas, rect.center, cell * 0.30,
            owner != null ? Colors.white : theme.safeStar);
      }
      if (highlightCells.contains(i)) {
        canvas.drawRect(rect, Paint()..color = AppColors.accent.withValues(alpha: 0.45));
      }
    }
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = theme.line;
    BoardLayout.homeColumns.forEach((color, cells) {
      final base = AppColors.of(color);
      // Skip the innermost cell — it belongs to the centre triangles.
      for (var i = 0; i < cells.length - 1; i++) {
        final rect = _cellRect(cells[i].x, cells[i].y, cell);
        canvas.drawRect(rect, _vGradient(rect, _lighten(base), _darken(base)));
        canvas.drawRect(rect, border);
        _bevel(canvas, rect.deflate(cell * 0.02), cell);
      }
    });
  }

  void _drawCenter(Canvas canvas, double cell) {
    final l = 6 * cell, t = 6 * cell, r = 9 * cell, b = 9 * cell;
    final tl = Offset(l, t), tr = Offset(r, t), br = Offset(r, b), bl = Offset(l, b);
    final c = Offset((l + r) / 2, (t + b) / 2);

    void tri(Offset a, Offset b2, LudoColor color) {
      final base = AppColors.of(color);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
      // Radial gloss from the outer edge toward the centre for a pyramid look.
      final mid = Offset((a.dx + b2.dx) / 2, (a.dy + b2.dy) / 2);
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              (mid.dx - (l + r) / 2) / (3 * cell / 2),
              (mid.dy - (t + b) / 2) / (3 * cell / 2),
            ),
            radius: 1.1,
            colors: [_lighten(base, 0.22), _darken(base, 0.16)],
          ).createShader(Rect.fromLTRB(l, t, r, b)),
      );
    }

    tri(tl, tr, LudoColor.green);
    tri(tr, br, LudoColor.yellow);
    tri(br, bl, LudoColor.blue);
    tri(bl, tl, LudoColor.red);

    canvas.drawRect(
      Rect.fromLTRB(l, t, r, b),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.08
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // Raised centre gem.
    final gem = cell * 0.7;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);
    final gemRect = Rect.fromCenter(center: Offset.zero, width: gem, height: gem);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gemRect, Radius.circular(gem * 0.18)),
      _vGradient(gemRect, _lighten(theme.frame, 0.3), _darken(theme.frame, 0.1)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gemRect, Radius.circular(gem * 0.18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gem * 0.06
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? radius : radius * 0.45;
      final angle = (math.pi / points) * i - math.pi / 2;
      final pt = center + Offset(math.cos(angle) * rr, math.sin(angle) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    // Emboss: shadow then fill.
    canvas.drawPath(path.shift(Offset(0, radius * 0.08)),
        Paint()..color = Colors.black.withValues(alpha: 0.10));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.highlightCells != highlightCells || old.theme.key != theme.key;
}
