import '../models/game_state.dart';
import '../models/token.dart';
import '../rules/rule_config.dart';
import 'bot_strategy.dart';

/// A simple, readable heuristic bot.
///
/// Priority (highest first):
///   1. Capture an opponent.
///   2. Launch a token out of base.
///   3. Move a token into / toward home.
///   4. Land on a safe cell.
///   5. Otherwise advance the most progressed token.
///
/// Deliberately easy to extend — swap in a smarter [BotStrategy] later for a
/// "hard" difficulty without changing the engine.
class EasyBot implements BotStrategy {
  const EasyBot();

  @override
  String chooseMove(GameState state, int dice, List<String> movable) {
    final byId = {for (final t in state.tokens) t.id: t};
    final rules = state.rules;

    String? capture;
    String? leaveBase;
    String? reachHome;
    String? toSafe;
    String? farthest;
    var farthestPos = -2;

    for (final id in movable) {
      final t = byId[id]!;
      final to = t.isInBase ? 0 : t.position + dice;

      if (t.isInBase) {
        leaveBase ??= id;
      }
      if (to == RuleConfig.homeIndex) {
        reachHome ??= id;
      }

      final absTo = _absoluteOf(t, to);
      if (absTo != null && !rules.safeCells.contains(absTo)) {
        // Would this land on an opponent?
        for (final o in state.tokens) {
          if (o.color != t.color && o.isOnRing && o.absoluteCell() == absTo) {
            capture ??= id;
            break;
          }
        }
      }
      if (absTo != null && rules.safeCells.contains(absTo)) {
        toSafe ??= id;
      }

      final progressed = t.isInBase ? 0 : to;
      if (progressed > farthestPos) {
        farthestPos = progressed;
        farthest = id;
      }
    }

    return capture ??
        leaveBase ??
        reachHome ??
        toSafe ??
        farthest ??
        movable.first;
  }

  /// Absolute ring cell for [token] arriving at relative position [rel].
  int? _absoluteOf(Token token, int rel) {
    if (rel >= 0 && rel <= RuleConfig.lastRingRel) {
      return (token.color.startOffset + rel) % RuleConfig.ringSize;
    }
    return null;
  }
}
