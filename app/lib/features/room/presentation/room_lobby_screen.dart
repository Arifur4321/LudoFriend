import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/storage/local_cache.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../game_engine/rules/rule_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/theme/board_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../game/application/game_config.dart';
import '../../game/application/game_controller.dart';
import '../application/room_draft.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({super.key});

  void _start(BuildContext context, WidgetRef ref, RoomDraft draft) {
    // Offline: fill the remaining seats with bots so the room is playable now.
    // Online rooms (backend RoomController) replace these seats with networked
    // players and start via the API — the game then runs server-authoritatively.
    ref.read(activeBoardThemeProvider.notifier).state =
        BoardTheme.forKey(draft.boardThemeKey);
    ref.read(localCacheProvider).setSelectedBoardTier(draft.boardThemeKey);
    ref.read(gameConfigProvider.notifier).state = GameConfig.local(
      humans: 1,
      bots: draft.seats - 1,
      rules: RuleConfig(turnTimerSeconds: draft.turnTimer),
      boardThemeKey: draft.boardThemeKey,
      teamMode: draft.teamMode,
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
                          if (draft.boardName != null)
                            Text(draft.boardName!,
                                style: AppTextStyles.bodyMuted),
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
                  'Share the code so friends can join, or open Friends to invite '
                  'Facebook friends who play. Start now to play against bots.',
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

class _InvitePanel extends StatelessWidget {
  const _InvitePanel({required this.draft});

  final RoomDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  subject: 'Join my Ludo Friends room',
                  text:
                      'Join my ${draft.boardName ?? 'Ludo Friends'} room with code ${draft.code}.',
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share Code'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.friends),
              icon: const Icon(Icons.group_rounded),
              label: const Text('Friends'),
            ),
          ),
        ],
      ),
    );
  }
}
