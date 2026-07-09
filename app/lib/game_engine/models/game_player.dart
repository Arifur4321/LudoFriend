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
    this.avatarUrl,
    this.isGuest = false,
    this.userId,
  });

  final LudoColor color;
  final String name;
  final PlayerKind kind;

  /// Bundled SVG avatar path (used for guests / offline seats without a photo).
  final String? avatarAsset;

  /// Remote profile-photo URL (Facebook / Google) for signed-in players.
  final String? avatarUrl;

  /// True when this seat is a guest — renders an SVG avatar, never a photo.
  final bool isGuest;

  /// Backend user id for online players (null for local/bot seats).
  final String? userId;

  bool get isBot => kind == PlayerKind.bot;
  bool get isRemote => kind == PlayerKind.remote;
  bool get isHuman => kind == PlayerKind.human;

  GamePlayer copyWith({
    String? name,
    PlayerKind? kind,
    String? avatarAsset,
    String? avatarUrl,
    bool? isGuest,
  }) =>
      GamePlayer(
        color: color,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        avatarAsset: avatarAsset ?? this.avatarAsset,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isGuest: isGuest ?? this.isGuest,
        userId: userId,
      );

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'name': name,
        'kind': kind.name,
        'avatarAsset': avatarAsset,
        'avatarUrl': avatarUrl,
        'isGuest': isGuest,
        'userId': userId,
      };

  factory GamePlayer.fromJson(Map<String, dynamic> j) => GamePlayer(
        color: LudoColor.fromId(j['color'] as String),
        name: j['name'] as String,
        kind: PlayerKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => PlayerKind.human),
        avatarAsset: j['avatarAsset'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        isGuest: j['isGuest'] as bool? ?? false,
        userId: j['userId'] as String?,
      );

  /// Build a seat from a backend match/room player payload
  /// (`{user_id, name, avatar, is_guest, color, is_bot}`). Non-bot seats are
  /// [PlayerKind.remote]; the online config promotes the local seat to human.
  factory GamePlayer.fromServer(Map<String, dynamic> j) {
    final isBot = j['is_bot'] as bool? ?? false;
    final name = j['name'] as String?;
    return GamePlayer(
      color: LudoColor.fromId(j['color'] as String),
      name: (name != null && name.isNotEmpty) ? name : (isBot ? 'Bot' : 'Player'),
      kind: isBot ? PlayerKind.bot : PlayerKind.remote,
      avatarUrl: j['avatar'] as String?,
      isGuest: j['is_guest'] as bool? ?? false,
      userId: j['user_id']?.toString(),
    );
  }
}
