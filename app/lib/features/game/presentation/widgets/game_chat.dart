import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../application/game_chat_state.dart';
import '../../data/match_chat_repository.dart';

/// Opens the in-match chat sheet.
Future<void> showGameChat(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _ChatSheet(),
    ),
  );
}

/// Opens the quick-emoji picker; a chosen emoji is sent (online) or echoed
/// locally, then floats over the board.
Future<void> showGameEmojis(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in kQuickEmojis)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final matchId = ref.read(currentMatchIdProvider);
                Navigator.pop(ctx);
                if (matchId != null) {
                  // Online: the server echo floats it (avoids a double flash).
                  ref.read(matchChatRepositoryProvider).sendEmoji(matchId, e);
                } else {
                  ref.read(gameChatProvider.notifier).addLocal(e, isEmoji: true);
                  flashEmoji(context, e);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(e, style: const TextStyle(fontSize: 34)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Floats a big emoji up over the board, then removes itself. Self-contained
/// (no controller lifecycle) so it is safe to fire and forget.
void flashEmoji(BuildContext context, String emoji) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Positioned(
        left: size.width / 2 - 40,
        top: size.height * 0.52,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            onEnd: entry.remove,
            builder: (ctx, t, _) => Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -140 * t),
                child: Transform.scale(
                  scale: 0.6 + t * 1.1,
                  child: Text(emoji, style: const TextStyle(fontSize: 68)),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    final matchId = ref.read(currentMatchIdProvider);
    if (matchId != null) {
      ref.read(matchChatRepositoryProvider).sendMessage(matchId, v);
    } else {
      ref.read(gameChatProvider.notifier).addLocal(v);
    }
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(gameChatProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: messages.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Say hi to your table 👋',
                        style: TextStyle(color: AppColors.inkSoft)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final m = messages[messages.length - 1 - i];
                      return Align(
                        alignment: m.isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: m.isEmoji ? 4 : 8),
                          decoration: BoxDecoration(
                            color: m.isMe
                                ? AppColors.primary
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            m.isEmoji
                                ? m.text
                                : (m.isMe ? m.text : '${m.sender}: ${m.text}'),
                            style: TextStyle(
                              color: m.isMe ? Colors.white : AppColors.ink,
                              fontSize: m.isEmoji ? 26 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final phrase in kQuickPhrases)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(phrase),
                      onPressed: () => _send(phrase),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(_text.text),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
