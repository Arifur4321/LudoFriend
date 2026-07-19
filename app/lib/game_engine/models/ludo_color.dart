/// The four player colors in Ludo Friends.
///
/// The declaration order defines clockwise seating **and** each color's start
/// cell offset on the shared 52-cell ring:
///   red = 0, green = 13, yellow = 26, blue = 39.
///
/// This enum is pure data — it has no Flutter dependency so the whole game
/// engine can be unit-tested without a widget binding.
enum LudoColor {
  red,
  green,
  yellow,
  blue;

  /// Offset (0..51) of this color's start cell on the shared ring.
  int get startOffset {
    switch (this) {
      case LudoColor.red:
        return 0;
      case LudoColor.green:
        return 13;
      case LudoColor.yellow:
        return 26;
      case LudoColor.blue:
        return 39;
    }
  }

  /// Stable string id used for serialization (`'red'`, `'green'`, ...).
  String get id => name;

  static LudoColor fromId(String id) =>
      LudoColor.values.firstWhere((c) => c.name == id);

  /// The two colors used for a 2-player game sit opposite each other.
  static const List<LudoColor> twoPlayerColors = [
    LudoColor.red,
    LudoColor.yellow,
  ];

  static const List<LudoColor> fourPlayerColors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];

  /// 2v2 team side for this color: 0 = Team A (red + yellow, seats 0 & 2),
  /// 1 = Team B (green + blue, seats 1 & 3). Matches the backend's seat%2 team
  /// assignment exactly (the canonical seat order is red, green, yellow, blue).
  int get teamSide =>
      (this == LudoColor.red || this == LudoColor.yellow) ? 0 : 1;

  /// The two colors that make up each 2v2 team side.
  static const List<LudoColor> teamA = [LudoColor.red, LudoColor.yellow];
  static const List<LudoColor> teamB = [LudoColor.green, LudoColor.blue];

  /// Human-readable label for a team side (0 => 'Team A', 1 => 'Team B').
  static String teamLabel(int side) => side == 0 ? 'Team A' : 'Team B';
}
