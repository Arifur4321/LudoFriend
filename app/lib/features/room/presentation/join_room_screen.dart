import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/room_draft.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid code')));
      return;
    }
    // Offline: open the lobby for this code. Online (Phase 2) verifies the
    // code against the backend and joins the live room over the WebSocket.
    ref.read(roomDraftProvider.notifier).state = RoomDraft(
      code: code,
      seats: 4,
      botFill: true,
      turnTimer: 20,
      isPrivate: true,
      isHost: false,
    );
    context.push(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter room code', style: AppTextStyles.display),
                const SizedBox(height: 20),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading,
                  decoration: const InputDecoration(hintText: 'ABC123'),
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Join', onPressed: _join),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
