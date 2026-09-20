sealed class NeedsYouEvent {}

class NeedsYouLoaded extends NeedsYouEvent {}

/// The operator picked an action on a card and is now entering a reason.
///
/// Held in bloc state rather than widget state so the card's confirm strip
/// survives a rebuild of the list.
class NeedsYouActionStarted extends NeedsYouEvent {
  NeedsYouActionStarted({required this.decisionId, required this.choice});

  final String decisionId;

  /// Durable `HumanDecisionChoice` wire value.
  final String choice;
}

/// The operator backed out of an action before saving.
class NeedsYouActionCancelled extends NeedsYouEvent {
  NeedsYouActionCancelled({required this.decisionId});

  final String decisionId;
}

/// Commits the chosen action with its reason.
class NeedsYouActionSubmitted extends NeedsYouEvent {
  NeedsYouActionSubmitted({
    required this.decisionId,
    required this.choice,
    required this.rationale,
  });

  final String decisionId;
  final String choice;
  final String rationale;
}

/// Asks for the next page of the "Already decided" ledger. Raised when the
/// operator scrolls the ledger into view.
class NeedsYouHistoryRequested extends NeedsYouEvent {}
