/// The operator-facing wording for the "Restart after a problem" panel.
///
/// ## WHY EVERY STRING LIVES HERE AND NOT ON THE WIRE
///
/// The server sends facts; this maps them. That is the same boundary
/// `PlainLanguage.statusFor` keeps for states and `decisionChoiceLabel` keeps
/// for choices, and it is the reason an operator action added to this surface
/// cannot leak a new register into the product: the only way to write a word an
/// operator reads is to write it here, beside the words already there.
///
/// Strings marked EXISTING are byte-identical to something already in the
/// product. Strings marked NEW are listed verbatim in design-brief.md
/// §5.4 / §8.2 / §8.3 and were reviewed with the brief. Nothing here is
/// engineer jargon, and nothing is invented at call time (AC-20).
library;

import '../../core/plain_language.dart';
import '../../shared/decision_choice.dart';

/// Panel heading. EXISTING — `PlainLanguage.decisionType('escalation')`.
String get retryPanelHeading => PlainLanguage.decisionType('escalation');

/// Panel status line. EXISTING — `PlainStatus.needsYouItFailed.label`.
String get retryPanelStatusLine => PlainStatus.needsYouItFailed.label;

/// The micro-label above the failure explanation.
const String whyItStoppedLabel = 'WHY IT STOPPED';

/// The micro-label above the capacity and attempt position.
const String beforeYouStartLabel = 'BEFORE YOU START';

/// The confirmation strip's micro-label, mirroring `WHY DID YOU DECIDE THIS?`.
const String whyAreYouDoingThisLabel = 'WHY ARE YOU DOING THIS?';

/// Primary action. NEW (§5.5) — deliberately NOT `decisionChoiceLabel('approve',
/// decisionType: 'escalation')`, which reads "Resume": nothing here was paused,
/// "Resume" carries no cost signal, and reusing it would make "resume a failed
/// run" and "resume a paused run" indistinguishable on one screen at two very
/// different prices.
const String retryActionLabel = 'Try again';

/// Secondary action. EXISTING — `decisionChoiceLabel('cancel',
/// decisionType: 'escalation')`.
String get stopActionLabel =>
    decisionChoiceLabel('cancel', decisionType: 'escalation');

/// The cost line. NEW, same register (§8.2). Retry is not free and the panel
/// says so before the operator commits, not after.
const String retryCostSentence =
    'Trying again starts the agent from the beginning and costs model '
    'credits. It does not resume where it stopped.';

/// What the confirm strip says about a retry. NEW (§8.3) — and it is true:
/// nothing is deleted, and the previous attempt stays on record.
const String retryConsequenceSentence =
    'Starts a fresh agent run. The previous attempt is kept on record.';

/// What the confirm strip says about a stop. NEW, same register.
const String stopConsequenceSentence =
    'Stops this work for good. The record of what happened is kept.';

/// EXISTING, verbatim from the existing decision screen.
const String reasonFieldHint =
    'Add a short reason — saved with your name (required)';

/// EXISTING, verbatim from the existing decision screen.
const String cannotBeUndone = 'This cannot be undone.';

/// EXISTING, verbatim from the existing decision screen.
const String cancelLabel = 'Cancel';

/// EXISTING, verbatim from the existing decision screen.
const String savingLabel = 'Saving…';

/// AC-21. A missing reason is REPORTED AS MISSING — never an empty region and
/// never a silently substituted generic message, both of which are the quiet
/// screen defect this panel exists to close.
const String noRecordedReason = 'The system did not record why this stopped.';

/// AC-15b/AC-15d/§6.6.1. A missing configuration is an operator-configuration
/// fact, not a run failure, so it is worded as information and the screen is
/// never styled as though the work were broken.
const String retrySwitchedOffSentence =
    'Starting this again is switched off on this machine. '
    'Nothing has been changed.';

/// AC-16. The honest promise after a retry: the item is runnable, and the
/// ordinary scheduler will pick it up when a machine is free. Nothing is
/// promised about WHEN.
const String acceptedOutcomeSentence =
    'Done — it will start as soon as a machine is free.';

/// §5.4. The same accepted outcome when the budget is full right now: the work
/// is queued, which is what "queued" means on this platform, not a failure.
const String queuedOutcomeSentence =
    'Queued — it will start when a machine is free.';

/// §6.3. A non-terminal job already holds this item.
const String alreadyRunningSentence = 'This work is already running.';

/// §6.3. A replay of an already-accepted stop.
const String alreadyStoppedSentence = 'Already stopped.';

/// §6.3. The item is not parked in a failure state.
const String notApplicableSentence = 'This work is not waiting on you.';

/// §6.3. A blank reason is refused before anything is written.
const String blankReasonSentence = 'Add a short reason before you continue.';

/// §7.3. The store faulted; nothing was written and the operator is told so
/// rather than left watching a panel that did not change.
const String failedSentence = 'We could not do that. Nothing changed.';

/// `This will be attempt N of M.` — the attempt position, stated in text and
/// never as a colour-only badge (§9 A10, AC-4).
String attemptPositionSentence(int attempt, int limit) =>
    'This will be attempt $attempt of $limit.';

/// §5.4 — the capacity snapshot in the shape the Overview already uses
/// (`N of M machines busy`, `home_page.dart`). Always an observation, never a
/// promise: `snapshotOnly` is true on the wire and the copy reads that way.
String capacitySnapshotSentence(int inFlight, int cap) =>
    '$inFlight of $cap agent slots busy.';

/// The same snapshot without a full stop, for mid-sentence use after an
/// accepted retry.
String capacitySnapshotPhrase(int inFlight, int cap) =>
    '$inFlight of $cap agent slots busy';

/// §6.3 — the bound is spent. The offered number comes from the wire, so this
/// can never drift from the value the server actually enforced.
String retryLimitReachedSentence(int limit) =>
    'This work has already been tried $limit '
    '${limit == 1 ? 'time' : 'times'}. Stop it, or leave it for review.';

/// OQ-1 — who restarted this, from the append-only audit ledger the retry
/// writes. Reuses `PlainLanguage.timeOfDay` and the existing `DefinitionList`.
String priorActionSentence(String requestedBy, String when, String reason) =>
    'Started again by $requestedBy on $when — $reason';

/// The WHY-IT-STOPPED classifier (design-brief.md §5.6).
///
/// A CLOSED SET over durable signals this repository itself emits. It never
/// guesses a cause: anything it does not recognise gets a truthful neutral
/// sentence, which is the correct failure direction — less specific, never
/// wrong — and the raw record stays verbatim one disclosure away (AC-21, AC-22,
/// N8).
///
/// [jobFailureCode] is the `JobFailureCode` name; [reason] and
/// [jobFailureReason] are the raw durable text.
String failureExplanation({
  required String? reason,
  required String? jobFailureCode,
  required String? jobFailureReason,
}) {
  final recorded = [
    if (reason != null && reason.trim().isNotEmpty) reason.trim(),
    if (jobFailureReason != null && jobFailureReason.trim().isNotEmpty)
      jobFailureReason.trim(),
  ].join(' ').toLowerCase();

  if (jobFailureCode == 'executionInterrupted' ||
      recorded.contains('zombie execution reclaimed')) {
    return 'The machine running this work stopped answering, so it was stopped '
        'and handed back to you.';
  }
  if (recorded.contains('orphaned')) {
    return 'The machine running this work went away before finishing.';
  }
  if (recorded.isNotEmpty) {
    return 'The work stopped with an error. The technical details below say '
        'what the system recorded.';
  }
  return noRecordedReason;
}

/// The headline above the explanation. EXISTING —
/// `PlainLanguage.haltExplanation('agent_failed')`.
String get failureHeadline => PlainLanguage.haltExplanation('agent_failed');

/// The words a screen reader gets for the whole panel as one unit (§9 A1).
///
/// The same reason `_GateCard` gives, carried over verbatim in spirit:
/// without `explicitChildNodes` the buttons' tap actions merge upward into
/// this node and the whole panel becomes one tappable region with no cursor
/// change to advertise it.
const String retryPanelSemanticsLabel =
    'This work needs you: it failed. You can try again or stop it.';

/// §9 A2 — the confirm button carries its own state, so the label flips with
/// what pressing it would actually do.
String confirmButtonSemanticsLabel({
  required String actionLabel,
  required bool ready,
}) => ready
    ? '$actionLabel. ${actionLabel == retryActionLabel ? retryConsequenceSentence : stopConsequenceSentence}'
    : 'Add a reason first';

/// The announcement for one resolved operator action (AC-25, A3/A11).
///
/// [capacityFull] distinguishes the two truthful shapes of a successful retry:
/// the budget has room, or the work is queued behind a full budget. Both are
/// §5.4 copy; neither promises a start time.
String operatorActionAnnouncement(
  String outcome, {
  bool capacityFull = false,
  int attemptLimit = 0,
  bool retryLimitResolved = true,
}) => switch (outcome) {
  'accepted' => capacityFull ? queuedOutcomeSentence : acceptedOutcomeSentence,
  'alreadyRunning' => alreadyRunningSentence,
  'alreadyStopped' => alreadyStoppedSentence,
  'notApplicable' => notApplicableSentence,
  // The two refusals that share an outcome, told apart by whether a bound was
  // configured at all. `notApplicable` above covers "not a failed item".
  'notConfigured' =>
    retryLimitResolved
        ? retryLimitReachedSentence(attemptLimit)
        : retrySwitchedOffSentence,
  'invalidRequest' => blankReasonSentence,
  _ => failedSentence,
};
