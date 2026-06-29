import 'dart:math';

import 'package:flutter/widgets.dart';

/// Helpers for sizing the board and adapting layout across phones and tablets.
abstract class Responsive {
  /// Largest square that fits the available space, capped so the board never
  /// becomes uncomfortably large on tablets.
  static double boardSide(Size size,
      {double fraction = 0.96, double cap = 540}) {
    final side = min(size.width, size.height) * fraction;
    return min(side, cap);
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;
}
