/// Ordering + re-entrancy guard for the online (server-authoritative) match flow.
///
/// The backend stamps every persisted match snapshot with a strictly increasing
/// per-match `seq` (see `GameEngineService`: each applied event bumps it under a
/// `unique(match_id, seq)` constraint). The client can therefore treat `seq` as
/// a monotonic version and refuse to apply any snapshot that is not newer than
/// the one already on screen.
///
/// This matters because two independent transports deliver snapshots — the HTTP
/// roll/move response and the periodic `GET /state` recovery poll that is also
/// fired on every Reverb event — and their responses can arrive out of order.
/// Without an ordering guard, a slow poll that started just before a roll can
/// land *after* the roll response and revert the board to the pre-roll state,
/// re-enabling the die and making the player tap again (the duplicate/multi-tap
/// dice bug).
///
/// It is deliberately a plain, side-effect-free value object so the
/// reconciliation rules can be unit-tested without Flutter, Riverpod, Dio, or a
/// live socket. See `test/game/match_state_gate_test.dart`.
class MatchStateGate {
  int _appliedSeq = -1;
  bool _submitting = false;

  /// The `seq` of the newest authoritative snapshot applied so far (`-1` before
  /// the first sync).
  int get appliedSeq => _appliedSeq;

  /// Whether a roll request is currently in flight.
  bool get isSubmitting => _submitting;

  /// Attempt to begin a roll submission. Returns `true` exactly once per
  /// in-flight roll: the first valid tap acquires the lock; any further taps
  /// while the roll is pending get `false` and must be ignored. Always pair a
  /// `true` result with [endSubmission] in a `finally`.
  bool beginSubmission() {
    if (_submitting) return false;
    _submitting = true;
    return true;
  }

  /// Release the roll lock once the request has fully resolved (success, error,
  /// or timeout) so the player can roll again when it is legitimately their
  /// turn.
  void endSubmission() => _submitting = false;

  /// Whether an incoming snapshot carrying [incomingSeq] should be applied. A
  /// snapshot that is not strictly newer than the last applied one is a stale,
  /// duplicate, or out-of-order delivery and must be dropped so it can never
  /// overwrite newer state, reset a valid rolling animation, restore an older
  /// turn, or wrongly re-enable the dice. A `null` seq (no ordering info) fails
  /// open and is applied.
  bool shouldApply(int? incomingSeq) {
    if (incomingSeq == null) return true;
    return incomingSeq > _appliedSeq;
  }

  /// Record that a snapshot carrying [incomingSeq] has been applied, advancing
  /// the high-water mark. Never moves backwards.
  void markApplied(int? incomingSeq) {
    if (incomingSeq != null && incomingSeq > _appliedSeq) {
      _appliedSeq = incomingSeq;
    }
  }
}
