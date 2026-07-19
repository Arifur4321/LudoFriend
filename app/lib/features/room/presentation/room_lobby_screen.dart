import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../services/realtime/realtime_match_service.dart';
import '../../../services/realtime/websocket_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../game/application/online_entry.dart';
import '../data/room_models.dart';
import '../data/room_repository.dart';

/// Online room lobby: shows the real seated players (live over the room
/// WebSocket channel), lets everyone ready up, and lets the host start a shared
/// server match. Falls back gracefully if realtime isn't available.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  const RoomLobbyScreen({super.key});

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _poll;
  bool _navigated = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final room = ref.read(activeRoomProvider);
    if (room != null) {
      final rt = ref.read(realtimeMatchServiceProvider);
      rt.joinRoom(room.id);
      _sub = rt.events.listen(_onEvent);
      // Auto-ready the local player so the host only needs to press Start.
      ref.read(roomRepositoryProvider).ready(room.id, true).whenComplete(_refresh);
      // Polling fallback: even if a realtime event is missed (flaky network,
      // dropped websocket), joins still appear and — critically — the joiner
      // still enters the match shortly after the host presses Start.
      _poll = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_navigated) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    final room = ref.read(activeRoomProvider);
    if (room != null) {
      ref.read(realtimeMatchServiceProvider).leaveRoom(room.id);
    }
    super.dispose();
  }

  void _onEvent(RealtimeEvent ev) {
    if (!mounted) return;
    final room = ref.read(activeRoomProvider);
    if (room == null || ev.channel != 'private-room.${room.id}') return;
    if (ev.event == 'game.started') {
      final matchId = (ev.data['match_id'] as num?)?.toInt();
      if (matchId != null) _enter(matchId);
      return;
    }
    _refresh();
  }

  Future<void> _refresh() async {
    final room = ref.read(activeRoomProvider);
    if (room == null) return;
    final res = await ref.read(roomRepositoryProvider).show(room.id);
    if (!mounted) return;
    res.when(
      ok: (r) {
        ref.read(activeRoomProvider.notifier).state = r;
        if (r.inProgress && r.matchId != null) _enter(r.matchId!);
        setState(() {});
      },
      err: (_) {},
    );
  }

  Future<void> _enter(int matchId, {OnlineMatchModel? match}) async {
    if (_navigated) return;
    _navigated = true;
    await enterOnlineMatch(context, ref, matchId, match: match, onError: (m) {
      _navigated = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(m)));
      }
    });
  }

  Future<void> _start() async {
    final room = ref.read(activeRoomProvider);
    if (room == null || _starting) return;
    setState(() => _starting = true);
    final res = await ref.read(roomRepositoryProvider).start(room.id);
    if (!mounted) return;
    res.when(
      ok: (match) => _enter(match.id, match: match),
      err: (f) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  Future<void> _leave() async {
    final room = ref.read(activeRoomProvider);
    if (room != null) {
      await ref.read(roomRepositoryProvider).leave(room.id);
      ref.read(activeRoomProvider.notifier).state = null;
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(activeRoomProvider);
    final myId = ref.watch(authControllerProvider).valueOrNull?.id;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Lobby')),
        extendBodyBehindAppBar: true,
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.meeting_room_outlined,
                      color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text('This room is no longer available.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(color: Colors.white)),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Back to Home',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final isHost = '${room.hostUserId}' == myId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Lobby'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _leave,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room code', style: AppTextStyles.label),
                          Text(room.code,
                              style: AppTextStyles.display
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: AppColors.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: room.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded,
                            color: AppColors.primary),
                        tooltip: 'Share invite',
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: 'Join my Ludo Friends room! 🎲\n'
                                'Room code: ${room.code}\n'
                                'Get the game: '
                                'https://play.google.com/store/apps/details?id=com.arifurrahman.ludofriends',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: room.capacity,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final seat = i < room.players.length
                          ? room.players[i]
                          : null;
                      return _SeatTile(seat: seat, index: i);
                    },
                  ),
                ),
                Text(
                  isHost
                      ? 'Share the code or invite friends, then start.'
                      : 'Waiting for the host to start…',
                  style: AppTextStyles.label.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.friends),
                  icon: const Icon(Icons.group_rounded, color: Colors.white),
                  label: const Text('Invite friends',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                if (isHost)
                  PrimaryButton(
                    label: _starting ? 'Starting…' : 'Start Game',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _start,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.index});
  final RoomPlayerModel? seat;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color =
        AppColors.of(LudoColor.values[index % LudoColor.values.length]);
    final waiting = seat == null || seat!.isWaiting;
    final name = seat == null
        ? 'Waiting…'
        : seat!.isBot
            ? (seat!.name ?? 'Bot') // realistic persisted bot name
            : (seat!.name ?? 'Player');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,
            backgroundImage:
                (seat?.avatar != null && seat!.avatar!.isNotEmpty && !seat!.isBot)
                    ? NetworkImage(seat!.avatar!)
                    : null,
            child: (seat == null)
                ? const Icon(Icons.hourglass_empty,
                    color: Colors.white, size: 18)
                : seat!.isBot
                    ? const Icon(Icons.smart_toy, color: Colors.white, size: 18)
                    : (seat!.avatar == null || seat!.avatar!.isEmpty)
                        ? Text(
                            (seat!.name ?? 'P')
                                .characters
                                .first
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white))
                        : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppTextStyles.body)),
          if (!waiting)
            Icon(
              (seat!.isReady || seat!.isBot)
                  ? Icons.check_circle
                  : Icons.timelapse_rounded,
              color: (seat!.isReady || seat!.isBot)
                  ? AppColors.success
                  : AppColors.inkSoft,
            ),
        ],
      ),
    );
  }
}
