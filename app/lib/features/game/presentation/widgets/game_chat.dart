import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/emoji_reactions.dart';
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

/// Opens the quick-emoji picker; a chosen emoji is sent (online) or floated
/// locally (offline). Online reactions float for everyone via the server echo
/// (with a stable id + sender), so the sender never sees a double.
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
                  ref.read(matchChatRepositoryProvider).sendEmoji(matchId, e);
                } else {
                  ref.read(emojiReactionsProvider.notifier).add(
                        EmojiReaction(
                          id: 'local_${DateTime.now().microsecondsSinceEpoch}',
                          emoji: e,
                          sender: 'You',
                        ),
                      );
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
/// (no controller lifecycle) so it is safe to fire and forget; several can run
/// at once without overwriting one another.
void flashEmoji(BuildContext context, String emoji, {String sender = ''}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final size = MediaQuery.of(context).size;
  // Small deterministic horizontal jitter so simultaneous reactions fan out.
  final jitter = ((emoji.hashCode ^ sender.hashCode) % 120) - 60;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        left: size.width / 2 - 40 + jitter,
        top: size.height * 0.52,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            // Guarded removal: if the route/overlay was torn down first (e.g.
            // the player left the match mid-animation), removing again would
            // throw — `mounted` makes disposal race-free.
            onEnd: () {
              if (entry.mounted) entry.remove();
            },
            builder: (ctx, t, _) => Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -150 * t),
                child: Transform.scale(
                  scale: 0.6 + t * 1.1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 64)),
                      if (sender.isNotEmpty)
                        Text(
                          sender,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
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
  final ScrollController _scroll = ScrollController();
  DateTime? _lastSend;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0); // reverse:true → 0 is newest
    });
  }

  void _send(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    // Debounce accidental double-fires (rapid Send taps / quick-phrase taps).
    final now = DateTime.now();
    if (_lastSend != null && now.difference(_lastSend!).inMilliseconds < 400) {
      return;
    }
    _lastSend = now;

    final matchId = ref.read(currentMatchIdProvider);
    final chat = ref.read(gameChatProvider.notifier);
    if (matchId != null) {
      final clientId = chat.addOptimistic(v);
      _deliver(matchId, v, clientId);
    } else {
      chat.addLocal(v);
    }
    _text.clear();
    _scrollToNewest();
  }

  /// POST the message and reconcile the optimistic bubble from the API
  /// response itself. The Reverb echo usually gets there first — then the
  /// response is a de-duplicated no-op — but when the echo is dropped (or the
  /// send was an idempotent retry, which broadcasts nothing) this is what
  /// resolves the bubble instead of leaving it pending forever.
  void _deliver(String matchId, String text, String clientId) {
    final chat = ref.read(gameChatProvider.notifier);
    final myId = ref.read(authControllerProvider).valueOrNull?.id;
    ref
        .read(matchChatRepositoryProvider)
        .sendMessage(matchId, text, clientId: clientId, myUserId: myId)
        .then(
          (res) => res.when(
            ok: (msg) {
              final id = msg.id;
              if (id == null) return; // echo/history will reconcile
              chat.applyServer(
                id: id,
                clientId: clientId,
                sender: msg.sender,
                avatarUrl: msg.avatarUrl,
                color: msg.color,
                text: msg.text,
                isMe: true,
                at: msg.at,
              );
            },
            err: (_) => chat.markFailed(clientId),
          ),
        );
  }

  /// Tap-to-retry for a failed bubble: resends the SAME text with the SAME
  /// client id, so however many retries race, the server stores at most one.
  void _retry(ChatMessage m) {
    final matchId = ref.read(currentMatchIdProvider);
    final clientId = m.clientId;
    if (matchId == null || clientId == null) return;
    final pendingAgain =
        ref.read(gameChatProvider.notifier).retryFailed(clientId);
    if (pendingAgain == null) return; // already reconciled meanwhile
    _deliver(matchId, pendingAgain.text, clientId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.chatEmpty,
                        style: const TextStyle(color: AppColors.inkSoft)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final m = messages[messages.length - 1 - i];
                      return _MessageBubble(
                        message: m,
                        onRetry: m.failed ? () => _retry(m) : null,
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
                  maxLength: 200,
                  buildCounter: (BuildContext context,
                          {required int currentLength,
                          required int? maxLength,
                          required bool isFocused}) =>
                      null, // hide the character counter
                  decoration: InputDecoration(
                    hintText: l.chatHint,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetry});

  final ChatMessage message;

  /// Non-null only for a failed bubble: tapping it resends the message with
  /// the same idempotency key, so it recovers instead of being lost.
  final VoidCallback? onRetry;

  String? _timeLabel(DateTime? at) {
    if (at == null) return null;
    final t = at.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final m = message;
    // Bound the bubble so long messages wrap instead of overflowing the sheet.
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            EdgeInsets.symmetric(horizontal: 12, vertical: m.isEmoji ? 4 : 8),
        decoration: BoxDecoration(
          color:
              m.isMe && !m.failed ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          m.isEmoji ? m.text : (m.isMe ? m.text : '${m.sender}: ${m.text}'),
          softWrap: true,
          style: TextStyle(
            color: m.isMe && !m.failed ? Colors.white : AppColors.ink,
            fontSize: m.isEmoji ? 26 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    final time = _timeLabel(m.at);
    final timeLabel = (time != null && !m.pending && !m.failed)
        ? Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
            child: Text(
              time,
              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
            ),
          )
        : null;

    final statusIcon = (m.pending || m.failed)
        ? Padding(
            padding: const EdgeInsets.only(left: 4),
            child: m.failed
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: Colors.redAccent),
                      SizedBox(width: 2),
                      Text('Tap to retry',
                          style: TextStyle(
                              fontSize: 10, color: Colors.redAccent)),
                    ],
                  )
                : const Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.inkSoft),
          )
        : null;

    if (m.isMe) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeLabel != null) timeLabel,
          bubble,
          if (statusIcon != null) statusIcon,
        ],
      );
      return Align(
        alignment: Alignment.centerRight,
        child: m.failed && onRetry != null
            ? InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onRetry,
                child: row,
              )
            : row,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SenderAvatar(sender: m.sender, avatarUrl: m.avatarUrl, color: m.color),
          const SizedBox(width: 6),
          bubble,
          if (timeLabel != null) timeLabel,
        ],
      ),
    );
  }
}

/// A compact sender avatar: the player photo when available, otherwise a
/// seat-coloured initial. The network image degrades to the initial on error,
/// so it never breaks the row.
class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender, this.avatarUrl, this.color});

  final String sender;
  final String? avatarUrl;
  final String? color;

  Color _seatColor() {
    switch (color) {
      case 'red':
        return const Color(0xFFE53935);
      case 'green':
        return const Color(0xFF2E7D32);
      case 'yellow':
        return const Color(0xFFF9A825);
      case 'blue':
        return const Color(0xFF1565C0);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = sender.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final url = avatarUrl;
    return CircleAvatar(
      radius: 12,
      backgroundColor: _seatColor(),
      foregroundImage:
          (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: Text(
        initial,
        style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
