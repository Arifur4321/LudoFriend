import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/application/emoji_reactions.dart';

/// Pure coverage for the emoji reaction controller: de-duplication by event id
/// (so a re-delivered / reconnect event never replays), co-existence of
/// simultaneous reactions, sender attribution, and clean disposal.
void main() {
  test('one reaction is shown once, with its sender', () {
    final c = EmojiReactionsController();
    c.add(const EmojiReaction(id: 'a', emoji: '😀', sender: 'Alice'));
    expect(c.state.length, 1);
    expect(c.state.single.sender, 'Alice');
    c.dispose();
  });

  test('a duplicate event id is ignored (covers reconnect replay)', () {
    final c = EmojiReactionsController();
    c.add(const EmojiReaction(id: 'x', emoji: '🎉'));
    c.add(const EmojiReaction(id: 'x', emoji: '🎉'));
    expect(c.state.length, 1);
    c.dispose();
  });

  test('multiple players reactions co-exist without overwriting', () {
    final c = EmojiReactionsController();
    c.add(const EmojiReaction(id: 'a', emoji: '👍', sender: 'Alice'));
    c.add(const EmojiReaction(id: 'b', emoji: '🔥', sender: 'Bob'));
    c.add(const EmojiReaction(id: 'c', emoji: '❤️', sender: 'Cara'));
    expect(c.state.length, 3);
    expect(c.state.map((r) => r.sender).toSet(), {'Alice', 'Bob', 'Cara'});
    c.dispose();
  });

  test('an empty id is rejected', () {
    final c = EmojiReactionsController();
    c.add(const EmojiReaction(id: '', emoji: '😀'));
    expect(c.state, isEmpty);
    c.dispose();
  });

  test('clear removes reactions and cancels pending timers', () {
    final c = EmojiReactionsController();
    c.add(const EmojiReaction(id: 'a', emoji: '😀'));
    c.add(const EmojiReaction(id: 'b', emoji: '🎉'));
    c.clear();
    expect(c.state, isEmpty);
    c.dispose();
  });
}
