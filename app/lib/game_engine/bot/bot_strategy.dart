import '../models/game_state.dart';

/// Strategy interface for AI opponents.
///
/// Implementations choose which movable token to play. Kept tiny and modular so
/// new difficulty levels can be dropped in without touching the engine or UI.
abstract class BotStrategy {
  /// Given the [state], the rolled [dice], and the ids of legally [movable]
  /// tokens, return the id of the token the bot will move.
  String chooseMove(GameState state, int dice, List<String> movable);
}
