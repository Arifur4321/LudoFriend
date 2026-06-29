import 'ludo_color.dart';

enum PlayerKind { human, bot, remote }

/// A seat in a match: a color plus who controls it (local human, AI bot, or a
/// remote networked player). Pure data — serializable for save/restore and for
/// reconciling online game state.
class GamePlayer {
  const GamePlayer({
    required this.color,
    required this.name,
    this.kind = PlayerKind.human,
    this.avatarAsset,
    this.userId,
  });

  final LudoColor color;
  final String name;
  final PlayerKind kind;
  final String? avatarAsset;

  /// Backend user id for online players (null for local/bot seats).
  final String? userId;

  bool get isBot => kind == PlayerKind.bot;
  bool get isRemote => kind == PlayerKind.remote;
  bool get isHuman => kind == PlayerKind.human;

  GamePlayer copyWith({String? name, PlayerKind? kind, String? avatarAsset}) =>
      GamePlayer(
        color: color,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        avatarAsset: avatarAsset ?? this.avatarAsset,
        userId: userId,
      );

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'name': name,
        'kind': kind.name,
        'avatarAsset': avatarAsset,
        'userId': userId,
      };

  factory GamePlayer.fromJson(Map<String, dynamic> j) => GamePlayer(
        color: LudoColor.fromId(j['color'] as String),
        name: j['name'] as String,
        kind: PlayerKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => PlayerKind.human),
        avatarAsset: j['avatarAsset'] as String?,
        userId: j['userId'] as String?,
      );
}
