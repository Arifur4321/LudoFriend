import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single in-match chat entry.
class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    this.isMe = false,
    this.isEmoji = false,
  });

  final String sender;
  final String text;
  final bool isMe;
  final bool isEmoji;
}

/// In-match chat log. Offline games echo locally; online games are fed from the
/// match WebSocket channel (`chat.message`) so the log is one authoritative
/// stream.
class GameChatController extends StateNotifier<List<ChatMessage>> {
  GameChatController() : super(const []);

  void addLocal(String text, {bool isEmoji = false, String sender = 'You'}) {
    state = [
      ...state,
      ChatMessage(sender: sender, text: text, isMe: true, isEmoji: isEmoji),
    ];
  }

  void addRemote(String sender, String text, {bool isEmoji = false}) {
    state = [
      ...state,
      ChatMessage(sender: sender, text: text, isEmoji: isEmoji),
    ];
  }

  void clear() => state = const [];
}

final gameChatProvider =
    StateNotifierProvider<GameChatController, List<ChatMessage>>(
  (ref) => GameChatController(),
);

/// The active online match id (null for offline games). When set, chat/emoji
/// route through the server and the board acts online.
final currentMatchIdProvider = StateProvider<String?>((ref) => null);

/// Set when a remote emoji reaction arrives; the game screen floats it over the
/// board, then resets this to null.
final incomingEmojiProvider = StateProvider<String?>((ref) => null);

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
