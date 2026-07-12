import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/application/match_state_gate.dart';

/// Unit coverage for the client-side ordering + re-entrancy rules that fix the
/// duplicate / multi-tap dice bug. These are the pure decisions the
/// GameController delegates to; keeping them here means the guarantees are
/// verified without a live socket, Dio, or Riverpod.
void main() {
  group('MatchStateGate — one roll per tap', () {
    test('a single tap acquires the submission lock exactly once', () {
      final gate = MatchStateGate();
      expect(gate.isSubmitting, isFalse);
      expect(gate.beginSubmission(), isTrue);
      expect(gate.isSubmitting, isTrue);
    });

    test('rapid repeated taps send only one request until it resolves', () {
      final gate = MatchStateGate();
      expect(gate.beginSubmission(), isTrue); // 1st tap -> the one request
      expect(gate.beginSubmission(), isFalse); // 2nd tap ignored
      expect(gate.beginSubmission(), isFalse); // 3rd tap ignored
      gate.endSubmission(); // server responded
      expect(gate.beginSubmission(), isTrue); // now a legit extra turn can roll
    });

    test('a delayed snapshot arriving mid-roll cannot start another roll', () {
      final gate = MatchStateGate()..markApplied(4);
      expect(gate.beginSubmission(), isTrue); // player is rolling
      // A late poll / reconnect snapshot for the same-or-older state lands...
      expect(gate.shouldApply(4), isFalse); // ...ignored — no re-roll / reset
      expect(gate.shouldApply(3), isFalse);
      expect(gate.isSubmitting, isTrue); // the in-flight roll still owns input
    });
  });

  group('MatchStateGate — authoritative ordering', () {
    test('applies the first snapshot, then only strictly newer ones', () {
      final gate = MatchStateGate();
      expect(gate.appliedSeq, -1);
      expect(gate.shouldApply(0), isTrue);
      gate.markApplied(0);
      expect(gate.shouldApply(1), isTrue);
      gate.markApplied(1);
      expect(gate.appliedSeq, 1);
    });

    test('an older or duplicate snapshot never overwrites a newer one', () {
      final gate = MatchStateGate()..markApplied(7); // roll response applied
      expect(gate.shouldApply(7), isFalse); // duplicate Reverb refresh: dropped
      expect(gate.shouldApply(6), isFalse); // slow poll (older): dropped
      expect(gate.shouldApply(3), isFalse);
      expect(gate.appliedSeq, 7); // high-water mark unchanged
    });

    test('order follows seq, not arrival (Reverb event before API response)', () {
      final gate = MatchStateGate()..markApplied(2);
      // Roll HTTP response (seq 3) applies.
      expect(gate.shouldApply(3), isTrue);
      gate.markApplied(3);
      // A refresh that was already in flight returns the pre-roll seq 2 AFTER
      // the response — it must not roll the board back.
      expect(gate.shouldApply(2), isFalse);
      // A genuinely newer snapshot (opponent moved) still applies.
      expect(gate.shouldApply(4), isTrue);
    });

    test('polling during a pending roll cannot reset a newer local state', () {
      // Roll committed at seq 5 and is on screen.
      final gate = MatchStateGate()..markApplied(5);
      // The 2s recovery poll fires and returns the same authoritative state.
      expect(gate.shouldApply(5), isFalse); // no reset of the rolling result
    });

    test('markApplied never moves the high-water mark backwards', () {
      final gate = MatchStateGate()..markApplied(5);
      gate.markApplied(2); // stale
      expect(gate.appliedSeq, 5);
    });

    test('a null seq fails open so older payload shapes still apply', () {
      final gate = MatchStateGate()..markApplied(9);
      expect(gate.shouldApply(null), isTrue);
    });
  });
}
