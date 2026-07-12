import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/application/game_chat_state.dart';

/// Pure coverage for the chat store's de-duplication, ordering, and optimistic
/// reconciliation — the guarantees that make chat show each message exactly
/// once and in order across optimistic UI + API + Reverb + reconnect.
void main() {
  void applyMsg(GameChatController c, int id,
      {String? clientId, String text = 'hi', bool isMe = false}) {
    c.applyServer(
      id: id,
      clientId: clientId,
      sender: 'Alice',
      text: text,
      isMe: isMe,
    );
  }

  test('a single server message is shown once', () {
    final c = GameChatController();
    applyMsg(c, 1);
    expect(c.state.length, 1);
    expect(c.state.single.id, 1);
  });

  test('a duplicate Reverb event (same id) is ignored', () {
    final c = GameChatController();
    applyMsg(c, 1);
    applyMsg(c, 1); // re-delivered / reconnect echo
    expect(c.state.length, 1);
  });

  test('optimistic bubble + server echo reconcile into one message', () {
    final c = GameChatController();
    final clientId = c.addOptimistic('gg');
    expect(c.state.length, 1);
    expect(c.state.single.pending, isTrue);
    expect(c.state.single.id, isNull);

    // Server echo carrying the same clientId replaces the optimistic bubble.
    applyMsg(c, 42, clientId: clientId, text: 'gg', isMe: true);
    expect(c.state.length, 1);
    expect(c.state.single.id, 42);
    expect(c.state.single.pending, isFalse);
  });

  test('out-of-order messages are ordered by server id', () {
    final c = GameChatController();
    applyMsg(c, 3, text: 'c');
    applyMsg(c, 1, text: 'a');
    applyMsg(c, 2, text: 'b');
    expect(c.state.map((m) => m.text).toList(), ['a', 'b', 'c']);
  });

  test('history merges without duplicating anything already live', () {
    final c = GameChatController();
    applyMsg(c, 5, text: 'five');
    c.loadHistory([
      ChatMessage(id: 5, sender: 'Alice', text: 'five', sortKey: 5),
      ChatMessage(id: 6, sender: 'Bob', text: 'six', sortKey: 6),
    ]);
    expect(c.state.length, 2);
    expect(c.state.map((m) => m.id).toList(), [5, 6]);
  });

  test('a failed send is marked recoverable, not duplicated', () {
    final c = GameChatController();
    final clientId = c.addOptimistic('oops');
    c.markFailed(clientId);
    expect(c.state.single.failed, isTrue);
    expect(c.state.single.pending, isFalse);
    // A later successful retry echo still reconciles the same bubble.
    applyMsg(c, 7, clientId: clientId, text: 'oops', isMe: true);
    expect(c.state.length, 1);
    expect(c.state.single.id, 7);
  });

  test('unicode content is preserved verbatim', () {
    final c = GameChatController();
    const u = 'নমস্কার 你好 こんにちは 🎉❤️';
    applyMsg(c, 1, text: u);
    expect(c.state.single.text, u);
  });

  test('clear resets state and the de-dup set', () {
    final c = GameChatController();
    applyMsg(c, 1);
    c.clear();
    expect(c.state, isEmpty);
    // The same id can be applied again after a clear (new match).
    applyMsg(c, 1);
    expect(c.state.length, 1);
  });
}
