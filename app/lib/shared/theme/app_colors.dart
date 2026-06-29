import 'package:flutter/material.dart';

import '../../game_engine/models/ludo_color.dart';

/// Ludo Friends original brand palette.
///
/// These exact values are shared with the SVG asset set so the UI and the
/// artwork stay perfectly in sync.
abstract class AppColors {
  // Brand
  static const Color primary = Color(0xFF5B3FD6); // grape
  static const Color primaryDeep = Color(0xFF3F2BA8);
  static const Color primaryLight = Color(0xFF8E6BFF);
  static const Color secondary = Color(0xFFFF6B6B); // coral
  static const Color accent = Color(0xFFFFC542); // sunny

  // Surfaces
  static const Color boardCream = Color(0xFFFFF7EC);
  static const Color boardLine = Color(0xFFE7DCC8);
  static const Color ink = Color(0xFF2A2440);
  static const Color inkSoft = Color(0xFF6B6588);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F0FA);

  // Token / player colors (original tones)
  static const Color tokenRed = Color(0xFFFF5A5F);
  static const Color tokenGreen = Color(0xFF2BD9A1);
  static const Color tokenYellow = Color(0xFFFFB23E);
  static const Color tokenBlue = Color(0xFF3A86FF);

  // Feedback
  static const Color success = Color(0xFF2BD9A1);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color warning = Color(0xFFFFB23E);

  // Background gradient stops
  static const Color bgTop = Color(0xFF6A4CE0);
  static const Color bgBottom = Color(0xFF8E6BFF);

  /// Maps an engine [LudoColor] to its brand token color.
  static Color of(LudoColor c) {
    switch (c) {
      case LudoColor.red:
        return tokenRed;
      case LudoColor.green:
        return tokenGreen;
      case LudoColor.yellow:
        return tokenYellow;
      case LudoColor.blue:
        return tokenBlue;
    }
  }

  /// A darker shade of a token color for shadows / outlines.
  static Color deepOf(LudoColor c) =>
      Color.lerp(of(c), Colors.black, 0.28) ?? of(c);

  /// A soft tint of a token color for the yard / home tinting.
  static Color tintOf(LudoColor c) =>
      Color.lerp(of(c), Colors.white, 0.72) ?? of(c);
}
