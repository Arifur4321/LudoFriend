import 'ludo_color.dart';

/// Rich description of a single applied move — everything the UI needs to
/// animate it cell-by-cell, and everything the backend needs to log it.
class MoveResult {
  const MoveResult({
    required this.movedTokenId,
    required this.fromPosition,
    required this.toPosition,
    required this.path,
    required this.capturedTokenIds,
    required this.reachedHome,
    required this.grantsExtraTurn,
    this.capturedFromPositions = const {},
    this.sequence,
    this.winner,
  });

  final String movedTokenId;
  final int fromPosition;
  final int toPosition;

  /// Relative positions stepped through (excludes the start), for cell-by-cell
  /// movement animation.
  final List<int> path;

  final List<String> capturedTokenIds;

  /// Original relative positions for captured tokens. The board uses these to
  /// animate each captured pawn backwards along its own route into its base.
  final Map<String, int> capturedFromPositions;

  /// Server event sequence for online de-duplication/reconnect recovery.
  final int? sequence;
  final bool reachedHome;
  final bool grantsExtraTurn;
  final LudoColor? winner;

  bool get didCapture => capturedTokenIds.isNotEmpty;

  /// Longest reverse path among captured pawns: ring cells down to relative 0,
  /// plus the final hop from the start cell into the pawn's base slot.
  int get maxCapturedReturnSteps {
    var max = 0;
    for (final from in capturedFromPositions.values) {
      final steps = from >= 0 ? from + 1 : 1;
      if (steps > max) max = steps;
    }
    return max;
  }

  factory MoveResult.fromServer(
    Map<String, dynamic> json, {
    required String fallbackTokenId,
  }) {
    final from = (json['from'] as num?)?.toInt() ?? -1;
    final to = (json['to'] as num?)?.toInt() ?? from;
    final color = json['color'] as String?;
    final token = (json['token'] as num?)?.toInt();
    final tokenId =
        color != null && token != null ? '${color}_$token' : fallbackTokenId;

    final rawPath = json['path'];
    final path = rawPath is List
        ? rawPath.whereType<num>().map((n) => n.toInt()).toList()
        : (from < 0 ? <int>[0] : <int>[for (var p = from + 1; p <= to; p++) p]);

    final capturedIds = <String>[];
    final capturedFrom = <String, int>{};
    final rawCaptured = json['captured'];
    if (rawCaptured is List) {
      for (final item in rawCaptured.whereType<Map>()) {
        final capturedColor = item['color'] as String?;
        final capturedToken = (item['token'] as num?)?.toInt();
        if (capturedColor == null || capturedToken == null) continue;
        final id = '${capturedColor}_$capturedToken';
        capturedIds.add(id);
        final capturedPosition = (item['from'] as num?)?.toInt();
        if (capturedPosition != null) capturedFrom[id] = capturedPosition;
      }
    }

    final winnerId = json['winner'] as String?;
    return MoveResult(
      movedTokenId: tokenId,
      fromPosition: from,
      toPosition: to,
      path: path,
      capturedTokenIds: capturedIds,
      capturedFromPositions: capturedFrom,
      reachedHome: json['finished'] as bool? ?? false,
      grantsExtraTurn: json['extra_turn'] as bool? ?? false,
      sequence: (json['move_seq'] as num? ?? json['seq'] as num?)?.toInt(),
      winner: winnerId == null ? null : LudoColor.fromId(winnerId),
    );
  }

  Map<String, dynamic> toJson() => {
        'movedTokenId': movedTokenId,
        'fromPosition': fromPosition,
        'toPosition': toPosition,
        'path': path,
        'capturedTokenIds': capturedTokenIds,
        'capturedFromPositions': capturedFromPositions,
        'reachedHome': reachedHome,
        'grantsExtraTurn': grantsExtraTurn,
        'sequence': sequence,
        'winner': winner?.name,
      };
}

/// Outcome of a dice roll before any token is moved.
class RollOutcome {
  const RollOutcome({
    required this.state,
    required this.dice,
    this.forfeited = false,
    this.noMove = false,
    this.grantsExtraTurn = false,
    this.movableTokenIds = const [],
  });

  /// The new game state after the roll has been recorded.
  final dynamic state; // GameState — kept dynamic to avoid an import cycle.
  final int dice;

  /// True when this was a third consecutive six and the turn was forfeited.
  final bool forfeited;

  /// True when no token could legally move with this dice.
  final bool noMove;

  final bool grantsExtraTurn;
  final List<String> movableTokenIds;
}
