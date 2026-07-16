import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/board_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../room/data/room_models.dart';
import '../../room/data/room_repository.dart';
import 'game_config.dart';
import 'game_controller.dart';

/// Load the authoritative match, build an online [GameConfig] with real player
/// identities (name / photo / guest flag), set the board theme, and navigate to
/// the game. Pass [match] if you already have it (e.g. from `start`) to skip a
/// fetch. Returns false and calls [onError] if it can't load.
Future<bool> enterOnlineMatch(
  BuildContext context,
  WidgetRef ref,
  int matchId, {
  OnlineMatchModel? match,
  void Function(String message)? onError,
}) async {
  OnlineMatchModel? m = match;
  if (m == null || m.players.isEmpty) {
    final res = await ref.read(roomRepositoryProvider).matchState(matchId);
    m = res.when(
      ok: (v) => v,
      err: (f) {
        onError?.call(f.message);
        return null;
      },
    );
    if (m == null) return false;
  }

  if (!context.mounted) return false;

  // Resolve MY Laravel user id — the authoritative identity every login type
  // (Facebook, Google, guest) shares. Await the auth future if it has not
  // settled yet: a momentarily-unloaded session (more likely right after a
  // Facebook round-trip) must never leave us without a seat colour, which would
  // make our own dice and tokens silently unresponsive.
  var myId = ref.read(authControllerProvider).valueOrNull?.id;
  myId ??= (await ref.read(authControllerProvider.future))?.id;
  if (!context.mounted) return false;

  String? myColor;
  for (final p in m.players) {
    // Match on the Laravel user id (never the Facebook/Google profile id): the
    // int seat id is stringified so it compares cleanly with the String auth id.
    if (p.userId != null && myId != null && '${p.userId}' == myId) {
      myColor = p.color;
      break;
    }
  }
  // A seated participant must always resolve to a colour. If identity is
  // genuinely unavailable, surface a recoverable error instead of dropping the
  // player onto a board whose dice and tokens would silently do nothing.
  if (myColor == null) {
    onError?.call('Could not confirm your seat — please reopen the match.');
    return false;
  }

  ref.read(activeBoardThemeProvider.notifier).state =
      BoardTheme.forKey(m.boardTier);
  ref.read(gameConfigProvider.notifier).state = GameConfig.online(
    matchId: '$matchId',
    serverPlayers: m.players.map((p) => p.toServerPlayerJson()).toList(),
    myColor: myColor,
    boardThemeKey: m.boardTier,
  );

  if (context.mounted) context.go(AppRoutes.game);
  return true;
}
