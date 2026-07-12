import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single in-match chat entry.
///
/// Online messages carry the server-authoritative [id] — the stable ordering
/// and de-duplication key. An optimistic bubble the local player just posted
/// carries only [clientId] until the server echo reconciles it, so the sender
/// sees their message immediately and then exactly once.
class ChatMessage {
  const ChatMessage({
    this.id,
    this.clientId,
    required this.sender,
    this.avatarUrl,
    this.color,
    required this.text,
    this.isMe = false,
    this.isEmoji = false,
    this.pending = false,
    this.failed = false,
    required this.sortKey,
  });

  final int? id;
  final String? clientId;
  final String sender;
  final String? avatarUrl;
  final String? color;
  final String text;
  final bool isMe;
  final bool isEmoji;
  final bool pending;
  final bool failed;

  /// Ordering key: the server id for confirmed messages; a large synthetic key
  /// for still-pending optimistic bubbles so they sort to the bottom (newest).
  final int sortKey;

  ChatMessage copyWith({int? id, bool? pending, bool? failed, int? sortKey}) =>
      ChatMessage(
        id: id ?? this.id,
        clientId: clientId,
        sender: sender,
        avatarUrl: avatarUrl,
        color: color,
        text: text,
        isMe: isMe,
        isEmoji: isEmoji,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        sortKey: sortKey ?? this.sortKey,
      );
}

/// In-match chat log. Offline games echo locally; online games are fed from the
/// match WebSocket channel (`chat.message`) plus a one-shot history fetch on
/// entry.
///
/// Messages are de-duplicated by server [id] and kept in stable order, so any
/// combination of optimistic UI, API response, Reverb echo, a duplicated event,
/// or a reconnect can never show a message more than once or out of order.
class GameChatController extends StateNotifier<List<ChatMessage>> {
  GameChatController() : super(const []);

  final Set<int> _serverIds = <int>{};
  int _tempSeq = 0;

  /// Base for synthetic pending keys — far above any real server id so pending
  /// bubbles always sort after confirmed messages.
  static const int _pendingBase = 1 << 52;

  int _nextPendingKey() => _pendingBase + (_tempSeq++);

  /// Offline (pass & play / vs bot): a local echo with no server round-trip.
  void addLocal(String text, {bool isEmoji = false, String sender = 'You'}) {
    state = [
      ...state,
      ChatMessage(
        sender: sender,
        text: text,
        isMe: true,
        isEmoji: isEmoji,
        sortKey: _nextPendingKey(),
      ),
    ];
  }

  /// Optimistically show a message the local player just sent, returning the
  /// [clientId] the caller must pass to the API so the server echo reconciles
  /// it instead of appending a duplicate. The bubble renders as pending until
  /// then.
  String addOptimistic(String text, {String sender = 'You'}) {
    final key = _nextPendingKey();
    final clientId = 'c${DateTime.now().microsecondsSinceEpoch}_$key';
    state = [
      ...state,
      ChatMessage(
        clientId: clientId,
        sender: sender,
        text: text,
        isMe: true,
        pending: true,
        sortKey: key,
      ),
    ];
    return clientId;
  }

  /// Mark the optimistic bubble for [clientId] as failed (recoverable).
  void markFailed(String clientId) {
    state = [
      for (final m in state)
        (m.id == null && m.clientId == clientId)
            ? m.copyWith(pending: false, failed: true)
            : m,
    ];
  }

  /// Apply an authoritative server message (Reverb echo or history). Ignores a
  /// message whose id was already applied; reconciles a matching optimistic
  /// bubble in place; otherwise inserts in id order.
  void applyServer({
    required int id,
    String? clientId,
    required String sender,
    String? avatarUrl,
    String? color,
    required String text,
    required bool isMe,
    bool isEmoji = false,
  }) {
    if (_serverIds.contains(id)) return;
    _serverIds.add(id);

    final server = ChatMessage(
      id: id,
      clientId: clientId,
      sender: sender,
      avatarUrl: avatarUrl,
      color: color,
      text: text,
      isMe: isMe,
      isEmoji: isEmoji,
      sortKey: id,
    );

    final list = [...state];
    final idx = (clientId == null)
        ? -1
        : list.indexWhere((m) => m.id == null && m.clientId == clientId);
    if (idx >= 0) {
      list[idx] = server;
    } else {
      list.add(server);
    }
    list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    state = list;
  }

  /// Merge a page of history (server messages), de-duplicated by id.
  void loadHistory(Iterable<ChatMessage> history) {
    final list = [...state];
    var changed = false;
    for (final m in history) {
      final id = m.id;
      if (id == null || _serverIds.contains(id)) continue;
      _serverIds.add(id);
      list.add(m);
      changed = true;
    }
    if (!changed) return;
    list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    state = list;
  }

  void clear() {
    _serverIds.clear();
    state = const [];
  }
}

final gameChatProvider =
    StateNotifierProvider<GameChatController, List<ChatMessage>>(
  (ref) => GameChatController(),
);

/// The active online match id (null for offline games). When set, chat/emoji
/// route through the server and the board acts online.
final currentMatchIdProvider = StateProvider<String?>((ref) => null);

/// Safe, tap-to-send phrases (also the only messages guests may send).
const List<String> kQuickPhrases = [
  'Hi! 👋',
  'Good luck!',
  'Nice move!',
  'Oh no! 😅',
  'Well played 👏',
  'Hurry up ⏳',
  'Rematch?',
];

const List<String> kQuickEmojis = [
  '😀',
  '😂',
  '😮',
  '😎',
  '😭',
  '👍',
  '🎉',
  '🔥',
  '❤️',
  '😡',
];
