import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../services/realtime/realtime_match_service.dart';
import '../../../services/realtime/websocket_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_user.dart';
import '../../room/data/room_repository.dart';
import '../data/friends_repository.dart';

/// App-wide wrapper that keeps the signed-in user subscribed to their private
/// channel and shows a "Play with {name}" dialog when a friend invite arrives —
/// so invited friends can one-tap join without a room code.
///
/// Fully defensive: if realtime isn't available (e.g. Reverb isn't running) it
/// simply does nothing and never crashes the app.
class InviteListener extends ConsumerStatefulWidget {
  const InviteListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends ConsumerState<InviteListener> {
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _presence;
  int? _userId;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sync(ref.read(authControllerProvider).valueOrNull));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _presence?.cancel();
    super.dispose();
  }

  void _sync(AuthUser? user) {
    final id = user == null ? null : int.tryParse(user.id);
    if (id == _userId) return;
    _userId = id;
    if (id == null) return;
    try {
      final rt = ref.read(realtimeMatchServiceProvider);
      rt.joinUser(id);
      _sub ??= rt.events.listen(_onEvent);
      // App-wide presence heartbeat so friends see this user as online anywhere
      // in the app — not only while the Friends screen is open. Server TTL is
      // 60s, so a 30s cadence keeps the flag warm.
      final friends = ref.read(friendsRepositoryProvider);
      friends.presencePing();
      _presence ??= Timer.periodic(
          const Duration(seconds: 30), (_) => friends.presencePing());
    } catch (_) {
      // Realtime unavailable — invites just won't arrive; no crash.
    }
  }

  void _onEvent(RealtimeEvent ev) {
    if (ev.event != 'friend.invite' || _dialogOpen) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final from = ev.data['from'];
    final name =
        (from is Map && from['name'] is String) ? from['name'] as String : 'A friend';
    final codeRaw = ev.data['code'];
    final code = codeRaw is String ? codeRaw : null;
    if (code == null) return;

    _dialogOpen = true;
    showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('Invitation from $name'),
        content: Text('$name invited you to play Ludo. Jump in?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Later')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(d);
              await _accept(code);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play'),
          ),
        ],
      ),
    ).whenComplete(() => _dialogOpen = false);
  }

  Future<void> _accept(String code) async {
    final res = await ref.read(roomRepositoryProvider).join(code);
    res.when(
      ok: (room) {
        ref.read(activeRoomProvider.notifier).state = room;
        rootNavigatorKey.currentContext?.push(AppRoutes.lobby);
      },
      err: (f) {
        final c = rootNavigatorKey.currentContext;
        if (c != null) {
          ScaffoldMessenger.of(c)
              .showSnackBar(SnackBar(content: Text(f.message)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) => _sync(next.valueOrNull));
    return widget.child;
  }
}
