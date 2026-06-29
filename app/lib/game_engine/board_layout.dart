import 'dart:math';

import 'models/ludo_color.dart';
import 'models/token.dart';
import 'rules/rule_config.dart';

/// A grid cell-centre as fractional (row, col) coordinates on the 15×15 board.
///
/// Kept as a tiny value type (instead of `dart:ui` `Offset`) so this whole
/// layer stays Flutter-free and unit-testable. The painter multiplies by the
/// pixel cell size to get screen coordinates.
class GridPoint {
  const GridPoint(this.row, this.col);
  final double row;
  final double col;

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// Maps engine positions to 15×15 grid coordinates for rendering and animation.
///
/// Coordinates are (row, col) with origin top-left. This layout was verified to
/// form the standard Ludo cross, with the colored start cells at ring indices
/// 0 (red), 13 (green), 26 (yellow) and 39 (blue).
class BoardLayout {
  const BoardLayout._();

  static const int gridSize = 15;

  /// The 52 shared-ring cells in clockwise order (absolute index 0..51).
  static const List<Point<int>> ringCells = [
    Point(6, 1),
    Point(6, 2),
    Point(6, 3),
    Point(6, 4),
    Point(6, 5),
    Point(5, 6),
    Point(4, 6),
    Point(3, 6),
    Point(2, 6),
    Point(1, 6),
    Point(0, 6),
    Point(0, 7),
    Point(0, 8),
    Point(1, 8),
    Point(2, 8),
    Point(3, 8),
    Point(4, 8),
    Point(5, 8),
    Point(6, 9),
    Point(6, 10),
    Point(6, 11),
    Point(6, 12),
    Point(6, 13),
    Point(6, 14),
    Point(7, 14),
    Point(8, 14),
    Point(8, 13),
    Point(8, 12),
    Point(8, 11),
    Point(8, 10),
    Point(8, 9),
    Point(9, 8),
    Point(10, 8),
    Point(11, 8),
    Point(12, 8),
    Point(13, 8),
    Point(14, 8),
    Point(14, 7),
    Point(14, 6),
    Point(13, 6),
    Point(12, 6),
    Point(11, 6),
    Point(10, 6),
    Point(9, 6),
    Point(8, 5),
    Point(8, 4),
    Point(8, 3),
    Point(8, 2),
    Point(8, 1),
    Point(8, 0),
    Point(7, 0),
    Point(6, 0),
  ];

  /// 6 private home-column cells per color (relative positions 51..56).
  static const Map<LudoColor, List<Point<int>>> homeColumns = {
    LudoColor.red: [
      Point(7, 1),
      Point(7, 2),
      Point(7, 3),
      Point(7, 4),
      Point(7, 5),
      Point(7, 6)
    ],
    LudoColor.green: [
      Point(1, 7),
      Point(2, 7),
      Point(3, 7),
      Point(4, 7),
      Point(5, 7),
      Point(6, 7)
    ],
    LudoColor.yellow: [
      Point(7, 13),
      Point(7, 12),
      Point(7, 11),
      Point(7, 10),
      Point(7, 9),
      Point(7, 8)
    ],
    LudoColor.blue: [
      Point(13, 7),
      Point(12, 7),
      Point(11, 7),
      Point(10, 7),
      Point(9, 7),
      Point(8, 7)
    ],
  };

  /// The four base/yard slots per color (where un-launched tokens rest).
  static const Map<LudoColor, List<GridPoint>> baseSlots = {
    LudoColor.red: [
      GridPoint(1.5, 1.5),
      GridPoint(1.5, 3.5),
      GridPoint(3.5, 1.5),
      GridPoint(3.5, 3.5)
    ],
    LudoColor.green: [
      GridPoint(1.5, 10.5),
      GridPoint(1.5, 12.5),
      GridPoint(3.5, 10.5),
      GridPoint(3.5, 12.5)
    ],
    LudoColor.yellow: [
      GridPoint(10.5, 10.5),
      GridPoint(10.5, 12.5),
      GridPoint(12.5, 10.5),
      GridPoint(12.5, 12.5)
    ],
    LudoColor.blue: [
      GridPoint(10.5, 1.5),
      GridPoint(10.5, 3.5),
      GridPoint(12.5, 1.5),
      GridPoint(12.5, 3.5)
    ],
  };

  /// Grid centre of the corner where each color's base sits (for drawing yards).
  static const Map<LudoColor, Point<int>> baseOrigin = {
    LudoColor.red: Point(0, 0),
    LudoColor.green: Point(0, 9),
    LudoColor.yellow: Point(9, 9),
    LudoColor.blue: Point(9, 0),
  };

  /// Grid cell-centre for a token in its current position.
  static GridPoint cellOf(Token t) {
    if (t.isInBase) return baseSlots[t.color]![t.index];
    if (t.isOnRing) {
      final p = ringCells[t.absoluteCell()!];
      return GridPoint(p.x.toDouble(), p.y.toDouble());
    }
    final idx = t.position - (RuleConfig.lastRingRel + 1); // 0..5
    final p = homeColumns[t.color]![idx];
    return GridPoint(p.x.toDouble(), p.y.toDouble());
  }

  /// Grid cell-centre for a relative position of [color] (used for path tweens).
  static GridPoint offsetForRelative(LudoColor color, int rel) {
    if (rel >= 0 && rel <= RuleConfig.lastRingRel) {
      final p = ringCells[(color.startOffset + rel) % RuleConfig.ringSize];
      return GridPoint(p.x.toDouble(), p.y.toDouble());
    }
    final idx = rel - (RuleConfig.lastRingRel + 1);
    final p = homeColumns[color]![idx];
    return GridPoint(p.x.toDouble(), p.y.toDouble());
  }

  /// Absolute ring cell as a grid point.
  static GridPoint ringPoint(int absIndex) {
    final p = ringCells[absIndex % RuleConfig.ringSize];
    return GridPoint(p.x.toDouble(), p.y.toDouble());
  }
}
