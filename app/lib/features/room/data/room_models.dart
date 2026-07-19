/// Parsed backend room + match payloads used by the online lobby and the
/// online-match entry flow.

class RoomPlayerModel {
  const RoomPlayerModel({
    required this.seat,
    required this.color,
    required this.isBot,
    required this.isReady,
    this.userId,
    this.name,
    this.avatar,
    this.isGuest = false,
  });

  final int seat;
  final String color;
  final bool isBot;
  final bool isReady;
  final int? userId;
  final String? name;
  final String? avatar;
  final bool isGuest;

  bool get isWaiting => userId == null && !isBot;

  /// 2v2 team side derived from color: 0 = Team A (red/yellow), 1 = Team B
  /// (green/blue). Only meaningful in a team room; matches the backend seat%2.
  int get teamSide => (color == 'red' || color == 'yellow') ? 0 : 1;

  factory RoomPlayerModel.fromJson(Map<String, dynamic> j) {
    final user = j['user'];
    final u = user is Map<String, dynamic> ? user : null;
    return RoomPlayerModel(
      seat: (j['seat'] as num?)?.toInt() ?? 0,
      color: j['color'] as String? ?? 'red',
      isBot: j['is_bot'] as bool? ?? false,
      isReady: j['is_ready'] as bool? ?? false,
      userId: u?['id'] is num ? (u!['id'] as num).toInt() : null,
      // Seat-level `display_name`/`avatar` cover bots (which have no user
      // block) and still-empty seats, falling back to the human's account
      // fields. This is what lets a bot show a realistic name instead of "Bot".
      name: (u?['name'] as String?) ?? (j['display_name'] as String?),
      avatar: (u?['avatar'] as String?) ?? (j['avatar'] as String?),
      isGuest: u?['is_guest'] as bool? ?? false,
    );
  }
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.mode,
    required this.boardTier,
    required this.status,
    required this.capacity,
    required this.turnTimerSeconds,
    this.teamMode = false,
    this.matchId,
    this.players = const [],
  });

  final int id;
  final String code;
  final int hostUserId;
  final String mode;
  final String boardTier;
  final String status;
  final int capacity;
  final int turnTimerSeconds;
  final bool teamMode;
  final int? matchId;
  final List<RoomPlayerModel> players;

  bool get inProgress => status == 'in_progress';

  factory RoomModel.fromJson(Map<String, dynamic> j) {
    final players = (j['players'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(RoomPlayerModel.fromJson)
            .toList() ??
        const <RoomPlayerModel>[];
    return RoomModel(
      id: (j['id'] as num).toInt(),
      code: j['code'] as String? ?? '',
      hostUserId: (j['host_user_id'] as num?)?.toInt() ?? 0,
      mode: j['mode'] as String? ?? '4p',
      boardTier: j['board_tier'] as String? ?? 'casual',
      status: j['status'] as String? ?? 'lobby',
      capacity: (j['capacity'] as num?)?.toInt() ?? 4,
      turnTimerSeconds: (j['turn_timer_seconds'] as num?)?.toInt() ?? 20,
      teamMode: j['team_mode'] as bool? ?? false,
      matchId: (j['match_id'] as num?)?.toInt(),
      players: players,
    );
  }
}

/// A seat in a live match (from the match `players` payload).
class MatchSeatModel {
  const MatchSeatModel({
    this.userId,
    this.name,
    this.avatar,
    this.isGuest = false,
    required this.color,
    this.isBot = false,
  });

  final int? userId;
  final String? name;
  final String? avatar;
  final bool isGuest;
  final String color;
  final bool isBot;

  /// Shape consumed by [GamePlayer.fromServer] / GameConfig.online.
  Map<String, dynamic> toServerPlayerJson() => {
        'user_id': userId,
        'name': name,
        'avatar': avatar,
        'is_guest': isGuest,
        'color': color,
        'is_bot': isBot,
      };

  factory MatchSeatModel.fromJson(Map<String, dynamic> j) => MatchSeatModel(
        userId: j['user_id'] is num ? (j['user_id'] as num).toInt() : null,
        name: j['name'] as String?,
        avatar: j['avatar'] as String?,
        isGuest: j['is_guest'] as bool? ?? false,
        color: j['color'] as String? ?? 'red',
        isBot: j['is_bot'] as bool? ?? false,
      );
}

class OnlineMatchModel {
  const OnlineMatchModel({
    required this.id,
    required this.boardTier,
    this.players = const [],
    this.state,
  });

  final int id;
  final String boardTier;
  final List<MatchSeatModel> players;
  final Map<String, dynamic>? state;

  factory OnlineMatchModel.fromJson(Map<String, dynamic> j) {
    final players = (j['players'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MatchSeatModel.fromJson)
            .toList() ??
        const <MatchSeatModel>[];
    final state = j['state'];
    return OnlineMatchModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      boardTier: j['board_tier'] as String? ?? 'casual',
      players: players,
      state: state is Map<String, dynamic> ? state : null,
    );
  }
}

/// A read-only preview of a room fetched by its code (GET /rooms/lookup/{code}).
/// Used by the "Join Private Room" screen to confirm the host / board / free
/// seats before the user commits to joining. Does not seat the user.
class RoomPreview {
  const RoomPreview({
    required this.code,
    required this.boardTier,
    required this.mode,
    required this.status,
    required this.capacity,
    required this.players,
    required this.joinable,
    this.hostName,
    this.hostAvatar,
  });

  final String code;
  final String boardTier;
  final String mode;
  final String status;
  final int capacity;
  final int players;
  final bool joinable;
  final String? hostName;
  final String? hostAvatar;

  int get seatsLeft => (capacity - players).clamp(0, capacity);

  factory RoomPreview.fromJson(Map<String, dynamic> j) => RoomPreview(
        code: j['code'] as String? ?? '',
        boardTier: j['board_tier'] as String? ?? 'casual',
        mode: j['mode'] as String? ?? '4p',
        status: j['status'] as String? ?? 'lobby',
        capacity: (j['capacity'] as num?)?.toInt() ?? 4,
        players: (j['players'] as num?)?.toInt() ?? 0,
        joinable: j['joinable'] as bool? ?? false,
        hostName: j['host_name'] as String?,
        hostAvatar: j['host_avatar'] as String?,
      );
}
