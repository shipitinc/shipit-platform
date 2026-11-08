sealed class RunDetailEvent {}

class RunDetailLoaded extends RunDetailEvent {}

/// The operator picked an action on a failed work item and is now entering a
/// reason. Opens the confirm strip in place; nothing is written yet.
class RunDetailActionStarted extends RunDetailEvent {
  RunDetailActionStarted(this.action);

  /// Durable `operator_action` wire value: 'retry' | 'stop' | 'deploy' |
  /// 'reclaim' | 'reland' | 'reroute'.
  final String action;
}

/// The operator backed out before saving. Discards the pending request id, so
/// a fresh deliberate confirm afterwards mints a new one — a second deliberate
/// confirm is a second deliberate spend.
class RunDetailActionCancelled extends RunDetailEvent {
  RunDetailActionCancelled();
}

/// Commits the chosen action with its reason.
///
/// [requestId] is minted by the confirm strip ONCE per confirmation and carried
/// on every retry of that same confirmation, so a double-click or a lost
/// response can never spend twice (AC-9, AC-12).
class RunDetailActionSubmitted extends RunDetailEvent {
  RunDetailActionSubmitted({
    required this.action,
    required this.reason,
    required this.requestId,
  });

  final String action;
  final String reason;
  final String requestId;
}

/// The operator opened the review-repair confirm strip. Nothing is written.
class RunDetailReviewRepairStarted extends RunDetailEvent {
  RunDetailReviewRepairStarted();
}

/// The operator backed out of the repair. Discards the pending request id, so
/// a fresh deliberate confirm afterwards mints a new one — a second deliberate
/// confirm is a second deliberate spend.
class RunDetailReviewRepairCancelled extends RunDetailEvent {
  RunDetailReviewRepairCancelled();
}

/// Commits the repair with its reason.
///
/// [reason] is forwarded verbatim. The strip gates on it being non-empty so the
/// operator is never offered a spend they have not described, but the client
/// does not second-guess what counts as a reason: the endpoint refuses a blank
/// one, and that refusal comes back as a readable sentence rather than being
/// pre-empted here.
///
/// [requestId] is minted by the confirm strip ONCE per confirmation and carried
/// on every retry of that same confirmation, so a double-click cannot queue a
/// second review (the server's replay check returns what that request already
/// did).
class RunDetailReviewRepairSubmitted extends RunDetailEvent {
  RunDetailReviewRepairSubmitted({
    required this.reason,
    required this.requestId,
  });

  final String reason;
  final String requestId;
}
