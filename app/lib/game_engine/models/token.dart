import '../rules/rule_config.dart';
import 'ludo_color.dart';

/// A single playing piece.
///
/// [position] is the token's **relative** progress along its own route:
///   * `-1`     — still in the base / yard
///   * `0..50`  — on the shared ring (relative to this color's start cell)
///   * `51..55` — inside the private home column
///   * `56`     — finished (reached home)
class Token {
  Token({required this.color, required this.index, this.position = -1});

  final LudoColor color;

  /// 0..3 — which of the player's four tokens this is.
  final int index;

  int position;

  bool get isInBase => position == RuleConfig.inBase;
  bool get isFinished => position == RuleConfig.homeIndex;
  bool get isOnRing => position >= 0 && position <= RuleConfig.lastRingRel;
  bool get isInHomeColumn =>
      position > RuleConfig.lastRingRel && position < RuleConfig.homeIndex;

  /// On the board (not in base, not finished).
  bool get isActive => !isInBase && !isFinished;

  /// Absolute ring cell (0..51) when on the shared ring, otherwise `null`
  /// (base and home-column cells are private and never collide).
  int? absoluteCell() {
    if (isOnRing) {
      return (color.startOffset + position) % RuleConfig.ringSize;
    }
    return null;
  }

  /// Stable id, e.g. `red_0`.
  String get id => '${color.name}_$index';

  Token copy() => Token(color: color, index: index, position: position);

  Map<String, dynamic> toJson() =>
      {'color': color.name, 'index': index, 'position': position};

  factory Token.fromJson(Map<String, dynamic> j) => Token(
        color: LudoColor.fromId(j['color'] as String),
        index: j['index'] as int,
        position: j['position'] as int,
      );

  @override
  String toString() => 'Token($id @ $position)';
}
