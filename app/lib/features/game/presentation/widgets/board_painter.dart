import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../game_engine/board_layout.dart';
import '../../../../game_engine/models/ludo_color.dart';
import '../../../../game_engine/rules/rule_config.dart';
import '../../../../shared/theme/app_colors.dart';

/// Paints the static Ludo board: four corner yards, the cross track, the
/// colored home lanes, the centre home (four triangles) and the safe-cell stars.
///
/// Tokens and dice are drawn as widgets on top of this (see `LudoBoard`).
class BoardPainter extends CustomPainter {
  const BoardPainter({this.highlightCells = const {}});

  /// Absolute ring indices to highlight (valid landing targets), drawn faintly.
  final Set<int> highlightCells;

  static final Map<int, LudoColor> _startOwner = {
    for (final c in LudoColor.values) c.startOffset: c,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardLayout.gridSize;

    // Board base.
    final boardRect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(boardRect, Radius.circular(cell * 0.6));
    canvas.drawRRect(rrect, Paint()..color = AppColors.boardCream);

    _drawYards(canvas, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawCenter(canvas, cell);

    // Thin outer frame.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.10
        ..color = AppColors.boardLine,
    );
  }

  Rect _cellRect(num row, num col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  void _drawYards(Canvas canvas, double cell) {
    BoardLayout.baseOrigin.forEach((color, origin) {
      final outer =
          Rect.fromLTWH(origin.y * cell, origin.x * cell, 6 * cell, 6 * cell);
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer, Radius.circular(cell * 0.5)),
        Paint()..color = AppColors.of(color),
      );
      final inner = outer.deflate(cell * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.4)),
        Paint()..color = Colors.white,
      );
      // four token nests (centre convention matches LudoBoard: (idx+0.5)*cell)
      for (final slot in BoardLayout.baseSlots[color]!) {
        final center = Offset((slot.col + 0.5) * cell, (slot.row + 0.5) * cell);
        canvas.drawCircle(
            center, cell * 0.42, Paint()..color = AppColors.tintOf(color));
        canvas.drawCircle(
          center,
          cell * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = AppColors.of(color),
        );
      }
    });
  }

  void _drawTrack(Canvas canvas, double cell) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = AppColors.boardLine;

    for (var i = 0; i < BoardLayout.ringCells.length; i++) {
      final p = BoardLayout.ringCells[i];
      final rect = _cellRect(p.x, p.y, cell);
      final owner = _startOwner[i];
      final fill = Paint()
        ..color = owner != null ? AppColors.of(owner) : Colors.white;
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);

      if (RuleConfig.defaultSafeCells.contains(i)) {
        _drawStar(
          canvas,
          rect.center,
          cell * 0.30,
          owner != null ? Colors.white : AppColors.inkSoft,
        );
      }
      if (highlightCells.contains(i)) {
        canvas.drawRect(
            rect, Paint()..color = AppColors.accent.withValues(alpha: 0.45));
      }
    }
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = AppColors.boardLine;
    BoardLayout.homeColumns.forEach((color, cells) {
      // Skip the innermost cell — it belongs to the centre triangles.
      for (var i = 0; i < cells.length - 1; i++) {
        final rect = _cellRect(cells[i].x, cells[i].y, cell);
        canvas.drawRect(rect, Paint()..color = AppColors.of(color));
        canvas.drawRect(rect, border);
      }
    });
  }

  void _drawCenter(Canvas canvas, double cell) {
    final l = 6 * cell, t = 6 * cell, r = 9 * cell, b = 9 * cell;
    final tl = Offset(l, t),
        tr = Offset(r, t),
        br = Offset(r, b),
        bl = Offset(l, b);
    final c = Offset((l + r) / 2, (t + b) / 2);

    void tri(Offset a, Offset b2, LudoColor color) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.of(color));
    }

    tri(tl, tr, LudoColor.green); // top
    tri(tr, br, LudoColor.yellow); // right
    tri(br, bl, LudoColor.blue); // bottom
    tri(bl, tl, LudoColor.red); // left

    canvas.drawRect(
      Rect.fromLTRB(l, t, r, b),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.08
        ..color = Colors.white,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = (math.pi / points) * i - math.pi / 2;
      final pt = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.highlightCells != highlightCells;
}
