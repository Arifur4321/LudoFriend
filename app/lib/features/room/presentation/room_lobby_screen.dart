import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../services/facebook/facebook_auth_service.dart';
import '../../../services/social/social_auth_exception.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../game_engine/rules/rule_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../friends/data/friends_repository.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';
import '../application/room_draft.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({super.key});

  void _start(BuildContext context, WidgetRef ref, RoomDraft draft) {
    // Offline: fill the remaining seats with bots so the room is playable now.
    // Online (Phase 2) replaces these seats with networked players.
    ref.read(gameConfigProvider.notifier).state = GameConfig.local(
      humans: 1,
      bots: draft.seats - 1,
      rules: RuleConfig(turnTimerSeconds: draft.turnTimer),
    );
    context.go(AppRoutes.game);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(roomDraftProvider);
    if (draft == null) {
      return const Scaffold(body: Center(child: Text('No room')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Room Lobby')),
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
                          Text(draft.code,
                              style: AppTextStyles.display
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: AppColors.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: draft.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: draft.seats,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final you = i == 0;
                      final filled = you || draft.botFill;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.of(LudoColor.values[i % 4]),
                              child: Icon(
                                  you
                                      ? Icons.person
                                      : (draft.botFill
                                          ? Icons.smart_toy
                                          : Icons.hourglass_empty),
                                  color: Colors.white,
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              you
                                  ? 'You (host)'
                                  : draft.botFill
                                      ? 'Bot $i'
                                      : 'Waiting…',
                              style: AppTextStyles.body,
                            ),
                            const Spacer(),
                            if (filled)
                              const Icon(Icons.check_circle,
                                  color: AppColors.success),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  'Networked players join over your Laravel WebSocket server '
                  '(Phase 2). Start now to play this room against bots.',
                  style: AppTextStyles.label.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _InvitePanel(draft: draft),
                const SizedBox(height: 12),
                PrimaryButton(
                    label: 'Start Game',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => _start(context, ref, draft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitePanel extends ConsumerStatefulWidget {
  const _InvitePanel({required this.draft});

  final RoomDraft draft;

  @override
  ConsumerState<_InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends ConsumerState<_InvitePanel> {
  bool _loadingFriends = false;
  bool _sendingInvite = false;
  List<FacebookFriend>? _facebookFriends;

  Future<void> _shareRoom() async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Join my Ludo Friends room',
        text: 'Join my Ludo Friends room with code ${widget.draft.code}.',
      ),
    );
  }

  Future<void> _loadFacebookFriends() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null || user.isGuest) {
      _show('Sign in with Facebook first to invite Facebook friends.');
      return;
    }
    setState(() => _loadingFriends = true);
    try {
      final friends = await ref.read(facebookAuthServiceProvider).friends();
      if (!mounted) return;
      setState(() => _facebookFriends = friends);
      if (friends.isEmpty) {
        _show(
          'No app-connected Facebook friends found yet. You can still share the room code.',
        );
      }
    } on SocialAuthException catch (e) {
      _show(e.message);
    } finally {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _invite(FacebookFriend friend) async {
    setState(() => _sendingInvite = true);
    final res = await ref.read(friendsRepositoryProvider).inviteFacebookFriend(
          facebookUserId: friend.id,
          roomCode: widget.draft.code,
        );
    if (!mounted) return;
    setState(() => _sendingInvite = false);
    res.when(
      ok: (_) => _show('Invite sent to ${friend.name}.'),
      err: (failure) => _show(failure.message),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = _facebookFriends;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareRoom,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share Code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingFriends ? null : _loadFacebookFriends,
                  icon: _loadingFriends
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.people_alt_rounded),
                  label: const Text('Facebook'),
                ),
              ),
            ],
          ),
          if (friends != null && friends.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final friend in friends)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: friend.pictureUrl == null
                      ? null
                      : NetworkImage(friend.pictureUrl!),
                  child: friend.pictureUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                title: Text(friend.name, style: AppTextStyles.body),
                trailing: TextButton(
                  onPressed: _sendingInvite ? null : () => _invite(friend),
                  child: const Text('Invite'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
