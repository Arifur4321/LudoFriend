import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One floated emoji reaction. [id] is the server-issued per-send identifier
/// (or a `local_…` id offline) used to de-duplicate: the same reaction is never
/// played twice, even if the Reverb event is re-delivered or the socket
/// reconnects.
class EmojiReaction {
  const EmojiReaction({
    required this.id,
    required this.emoji,
    this.sender = '',
    this.color,
  });

  final String id;
  final String emoji;
  final String sender;
  final String? color;
}

/// Holds the currently-floating reactions. Several may be live at once (players
/// reacting together never overwrite one another), each auto-expires after a
/// short TTL, and all timers are cancelled on [clear]/[dispose] so nothing
/// leaks or replays when leaving a match.
class EmojiReactionsController extends StateNotifier<List<EmojiReaction>> {
  EmojiReactionsController() : super(const []);

  final Set<String> _seen = <String>{};
  final Map<String, Timer> _timers = <String, Timer>{};

  static const Duration _ttl = Duration(milliseconds: 1500);
  static const int _seenCap = 300;

  void add(EmojiReaction reaction) {
    if (reaction.id.isEmpty || _seen.contains(reaction.id)) return;
    _seen.add(reaction.id);
    _boundSeen();

    state = [...state, reaction];
    _timers[reaction.id]?.cancel();
    _timers[reaction.id] = Timer(_ttl, () => _expire(reaction.id));
  }

  void _expire(String id) {
    _timers.remove(id)?.cancel();
    if (state.any((r) => r.id == id)) {
      state = [
        for (final r in state)
          if (r.id != id) r,
      ];
    }
  }

  /// Keep the de-dup set bounded during very long sessions.
  void _boundSeen() {
    if (_seen.length > _seenCap) {
      final drop = _seen.take(_seenCap ~/ 3).toList();
      _seen.removeAll(drop);
    }
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _seen.clear();
    state = const [];
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

final emojiReactionsProvider =
    StateNotifierProvider<EmojiReactionsController, List<EmojiReaction>>(
  (ref) => EmojiReactionsController(),
);
