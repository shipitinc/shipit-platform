sealed class RunDetailEvent {}

class RunDetailLoaded extends RunDetailEvent {}

/// The operator picked an action on a failed work item and is now entering a
/// reason. Opens the confirm strip in place; nothing is written yet.
class RunDetailActionStarted extends RunDetailEvent {
  RunDetailActionStarted(this.action);

  /// Durable `operator_action` wire value: 'retry' | 'stop'.
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
