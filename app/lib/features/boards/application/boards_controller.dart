import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/application/wallet_controller.dart';
import '../data/board_models.dart';
import '../data/boards_repository.dart';

/// Loads the staked board tiers. Falls back to the built-in six boards (with
/// affordability derived from the local wallet) if the API can't be reached, so
/// the boards are always browsable and playable as themed practice.
class BoardsController extends AsyncNotifier<BoardsSnapshot> {
  @override
  Future<BoardsSnapshot> build() => _fetch();

  Future<BoardsSnapshot> _fetch() async {
    final res = await ref.read(boardsRepositoryProvider).list();
    return res.when(
      ok: (s) => s,
      err: (_) => BoardsSnapshot.fallback(ref.read(coinsProvider)),
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final boardsControllerProvider =
    AsyncNotifierProvider<BoardsController, BoardsSnapshot>(BoardsController.new);
