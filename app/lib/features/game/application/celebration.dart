import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_engine/models/ludo_color.dart';

/// Transient celebration signals fired by the game controller and consumed by
/// the game screen (which flashes a short overlay). Kept tiny on purpose —
/// capture plays a sound only, and the match win has its own WinnerOverlay.
enum CelebrationKind { tokenHome }

class CelebrationEvent {
  CelebrationEvent(this.kind, this.color) : seq = ++_counter;

  final CelebrationKind kind;

  /// The celebrating player's color (used to tint the burst).
  final LudoColor color;

  /// Monotonic sequence so identical back-to-back events still notify.
  final int seq;

  static int _counter = 0;
}

/// Set by [GameController]; the game screen listens, flashes the celebration,
/// then resets it to null.
final celebrationProvider = StateProvider<CelebrationEvent?>((ref) => null);
