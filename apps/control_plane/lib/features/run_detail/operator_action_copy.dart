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
import '../../shared/transition_copy.dart' show plainTransitionMessage;

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

/// The attempt position, stated in text and never as a colour-only badge
/// (§9 A10, AC-4).
///
/// ## WHY THE "of M" CLAUSE IS GATED ON A REAL COUNT
///
/// [limit] is a non-nullable `int` on a frozen wire model, so "no count was
/// configured" and "the count is zero" arrive as the SAME value, `0`. Since the
/// 2026-10-12 reversal `0` is the DEFAULT — an operator may restart as often as
/// they like — so rendering the number unconditionally produced the literal
/// string "This will be attempt 5 of 0." on the default path. That is not a
/// cosmetic wart: it asserts a zero-length budget the operator never chose, and
/// it is false on the majority of machines.
///
/// The panel already carries the honest truth for the uncounted case in
/// [retrySwitchedOffSentence] and the panel's own test pins it. So the count
/// clause is stated ONLY when a real count exists, and the sentence below stays
/// otherwise byte-identical to the bounded one so a configured budget is still
/// legible as a budget.
String attemptPositionSentence(int attempt, int limit) => limit > 0
    ? 'This will be attempt $attempt of $limit.'
    : 'This will be attempt $attempt.';

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
///
/// ## WHY A NON-POSITIVE COUNT IS NOT "ZERO TIMES"
///
/// The wire field is a non-nullable `int` and `0` means "there is no count",
/// so it is what arrives when operator retry is SWITCHED OFF on purpose
/// (`SHIPIT_OPERATOR_MAX_RETRIES=0`). Interpolating it produced the literal
/// "This work has already been tried 0 times" — a statement about a budget the
/// operator never spent, on a machine that deliberately has none. The total is
/// routed to [retrySwitchedOffSentence] instead, which is the true reading.
///
/// This guard is a correction to PRE-EXISTING copy, not a regression introduced
/// by the 2026-10-12 reversal: the interpolation is byte-identical at the base
/// commit. What changed is that `0` became the common value instead of the
/// disabled one, which is what made the wrong reading visible on the default
/// path. See `operatorActionAnnouncement` below, which is the only caller.
String retryLimitReachedSentence(int limit) {
  if (limit <= 0) return retrySwitchedOffSentence;
  return 'This work has already been tried $limit '
      '${limit == 1 ? 'time' : 'times'}. Stop it, or leave it for review.';
}

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

// ---------------------------------------------------------------------------
// THE REVIEW REPAIR AFFORDANCE
//
// A separate surface from the failed-work panel above, and deliberately worded
// in a different register: that panel offers a CHOICE between two legitimate
// outcomes, while this offers a REPAIR for a state that should not exist. The
// vocabulary never overlaps — nothing here says "try again", "start", "stop" or
// "approve", because a repair is none of those and borrowing their words is how
// a repair would come to read as a peer of approving work.
// ---------------------------------------------------------------------------

/// The micro-label above the repair offer.
const String reviewRepairLabel = 'IF NOBODY REVIEWED THIS';

/// The micro-label above a REFUSED repair.
///
/// Its own label, not [reviewRepairLabel]: the refusal sentence is very often
/// the opposite of the offer's premise — "a reviewer really did return a
/// verdict" — so printing "IF NOBODY REVIEWED THIS" above it would print the
/// offer's conditional and its own refutation in the same eight words. The
/// label says what happened instead of what was offered.
const String reviewRepairRefusedLabel = 'NOTHING CHANGED';

/// The heading. Conditional on purpose.
///
/// The screen does NOT know the decision was fabricated — only the server does,
/// by re-deriving provenance from the reviewer's own result. So the offer is
/// posed as a condition the operator may be looking at, never as a diagnosis
/// the UI has made.
const String reviewRepairHeading = 'This question may never have been reviewed';

/// What repairing it actually does, in the plainest words available.
const String reviewRepairExplanation =
    'If no reviewer ever returned a verdict, the decision this work is waiting '
    'on is a question nobody asked. Answering it would be answering that '
    'question. You can set the decision aside instead, and put the work back in '
    'the queue for a real review.';

/// The guardrail, stated on the surface itself rather than in a design document.
///
/// This is the sentence that makes the control safe to offer at all: it is not
/// asking the operator to trust the button, it is telling them what happens if
/// the button is wrong.
const String reviewRepairGuardrailSentence =
    'It checks before it does anything. If a reviewer really did review this, '
    'or you have already decided it, nothing changes and it tells you why.';

/// The affordance. Warning-tinted outline, never a filled button: a filled
/// button on this screen is the approval, and this must never read as its
/// equal.
const String reviewRepairActionLabel = 'Set aside and re-review';

/// The confirm strip's heading. "Repairing", never "You chose" — the same
/// reason as the label above.
const String reviewRepairStripHeading = 'Repairing this decision';

/// Names the consequence, on the surface, before anything is committed.
///
/// It also states the two things that do NOT happen, because those are the two
/// an operator is most likely to fear and most likely to be wrong about: the
/// old decision is not deleted, and the reason is recorded.
const String reviewRepairConsequenceSentence =
    'This voids the decision and re-queues the review. The old decision is '
    'kept on record, and your reason is saved with your name.';

/// The confirm button. It says what pressing it DOES, not what it is.
const String reviewRepairConfirmLabel =
    'Void the decision and re-queue the review';

/// The headline after a repair that landed.
const String reviewRepairedHeadline = 'Repaired — the decision was set aside';

/// The three facts that must be readable AT A GLANCE afterwards.
///
/// A repair that leaves the screen looking like the work moved forward is a
/// false state in miniature, so each of the three is stated separately rather
/// than folded into one reassuring sentence: the decision was retired and not
/// approved, the review is re-queued and not finished, and the prior decision
/// survives as evidence rather than being deleted.
const String reviewRepairedDecisionFact = 'Set aside, not approved';
const String reviewRepairedReviewFact = 'Back in the queue, not finished';
const String reviewRepairedRecordFact =
    'The previous decision is kept on record as evidence';

/// Their micro-labels, so the three facts read as a record and not as a list
/// of reassurances.
const String reviewRepairedDecisionLabel = 'THE DECISION';
const String reviewRepairedReviewLabel = 'THE REVIEW';
const String reviewRepairedRecordLabel = 'THE RECORD';

/// The live-region sentence for a repair that landed.
const String reviewRepairedSentence =
    'Done. The decision was set aside and the review is back in the queue.';

/// What the screen says about one resolved repair attempt.
///
/// ## WHY EVERY REFUSAL READS AS THE SERVER'S OWN SENTENCE
///
/// [detail] is the server's `detail`, carried whole. It is the only sentence
/// that carries what the server re-derived from the reviewer's own result, and
/// an operator told "something went wrong" instead of "a reviewer really did
/// return a verdict" has learned nothing and will try again.
///
/// So there is deliberately NO per-outcome table here. Anything that is not
/// `accepted` is a refusal, and every refusal — the three the affordance is most
/// likely to hit (`reviewerProducedVerdict`, `alreadyDecided`, `notApplicable`)
/// and every value the endpoint adds later — reads the server's sentence.
/// A table would have been a place for a new outcome to land on a generic
/// string, which is the failure this is shaped to make impossible.
///
/// The empty fallback is [failedSentence], and it exists only because the UI
/// must never leave an empty region (AC-21). `detail` is non-nullable on the
/// wire, so that branch is unreachable through the real client; it is here so a
/// future caller cannot turn "nothing to say" into a blank space.
String repairOutcomeSentence(String outcome, {String? detail}) {
  if (outcome == 'accepted') return reviewRepairedSentence;
  final server = detail?.trim();
  return server == null || server.isEmpty ? failedSentence : server;
}

/// A live-region label for the confirm button.
///
/// The button names its consequence, so the screen-reader label does too, and
/// it says plainly that the button is not yet live — "Add a reason first" is
/// the truth while the reason field is empty, and offering the consequence as
/// if it were available would be a lie about the state of the control.
String repairConfirmSemanticsLabel({required bool ready}) => ready
    ? reviewRepairConfirmLabel
    : 'Add a reason first. $reviewRepairConsequenceSentence';

/// The whole offer as one node for a screen reader.
///
/// Carried over from `_GateCard` and `FailedWorkItemActionPanel` for the same
/// reason: without `explicitChildNodes` the button's tap action merges upward
/// and the block reads as one tappable region with nothing to say what it does.
const String reviewRepairSemanticsLabel =
    'If nobody reviewed this question, you can set the decision aside and '
    're-queue the review. It is a repair, not an approval.';

// ---------------------------------------------------------------------------
// THE DEPLOY ADVANCE AND THE STRANDED RECLAIM
//
// Same boundary as everything above: the server sends wire values
// ('deploy' | 'reclaim'), this maps them to words. Neither action reads as a
// peer of "try again" or "stop" — one asks for a decision, the other hands a
// stranded item back to the failure surface.
// ---------------------------------------------------------------------------

/// Panel heading for a QA-passed item. Says what is true, not what will happen.
const String deployPanelHeading = 'It passed its checks';

/// What moving forward actually does — asks the operator to decide, first.
const String deployPanelExplanation =
    'Nothing is deployed yet, and nothing is deployed without you. Moving '
    'this forward puts a deployment decision on your plate to approve or '
    'turn down.';

/// The deploy action button. "Move forward", never "Deploy" — the action does
/// not deploy anything; it raises the question that does.
const String deployActionLabel = 'Move it forward';

/// What the confirm strip says about the advance. True by construction: the
/// item parks on a deployment_approval decision.
const String deployConsequenceSentence =
    'Parks the work on a deployment decision for you to answer. Nothing is '
    'deployed yet.';

/// Panel heading for a stranded run — the record claims execution, nothing is.
const String reclaimPanelHeading = 'It says it is running — nothing is';

/// What a stranded reclaim does, in plain words.
const String reclaimPanelExplanation =
    'The record claims an agent is working, but there is no live execution '
    'and no queued job behind it. Handing it back marks it as stopped, where '
    'you can try it again.';

/// The reclaim action button.
const String reclaimActionLabel = 'Hand it back';

/// What the confirm strip says about a reclaim.
const String reclaimConsequenceSentence =
    'Marks the work as stopped so it can be tried again. The record of what '
    'happened is kept.';

/// The accepted announcement for a deploy advance — parks, not deploys.
const String deployAcceptedSentence =
    'Done — it is waiting on your deployment decision now.';

/// The accepted announcement for a reclaim — lands at the failure surface.
const String reclaimAcceptedSentence =
    'Done — it is marked as stopped. You can try it again now.';

/// The announcement for one resolved operator action, per action.
///
/// Deploy and reclaim get their own accepted sentences because
/// [acceptedOutcomeSentence] — "it will start as soon as a machine is free" —
/// is false for both: a deploy parks on a human, a reclaim only re-parks.
/// Every refusal reuses the existing vocabulary verbatim.
String operatorActionAnnouncementFor(
  String action,
  String outcome, {
  bool capacityFull = false,
  int attemptLimit = 0,
  bool retryLimitResolved = true,
}) {
  if (outcome == 'accepted') {
    if (action == 'deploy') return deployAcceptedSentence;
    if (action == 'reclaim') return reclaimAcceptedSentence;
  }
  return operatorActionAnnouncement(
    outcome,
    capacityFull: capacityFull,
    attemptLimit: attemptLimit,
    retryLimitResolved: retryLimitResolved,
  );
}

// ---------------------------------------------------------------------------
// A REFUSED TRANSITION IS NOT A MOVE
// ---------------------------------------------------------------------------

/// The prefix on a refused attempt, so it can never be read as the move it
/// imitates.
///
/// A prefix rather than a different sentence per pair: the refused set is open
/// — any edge the policy can refuse, for any reason — and a per-pair table would
/// need an entry per pair per reason and would fall through to the MOVE copy for
/// every one it lacked. The thing that is common to all of them is that the item
/// did not move, so that is what the sentence says.
const String refusedTransitionPrefix = 'Not applied — ';

/// A refused attempt, worded from the move it failed to make.
///
/// `plainTransitionMessage(from, to)` is reused deliberately, and inverted: it
/// is the operator's own vocabulary for what was being attempted, so "Not
/// applied — Independent review started" says both halves in one line and stays
/// inside the register the rest of the timeline already uses.
String refusedTransitionMessage(String from, String to) =>
    '$refusedTransitionPrefix${plainTransitionMessage(from, to)}';

/// The message for one transition row.
///
/// ## WHY A REFUSED ROW IS RENDERED AT ALL
///
/// The alternative is to drop `outcome != 'accepted'` rows entirely, and it was
/// rejected on purpose. A refused attempt is the durable evidence that the
/// platform KEPT TRYING and was refused, which is the single most diagnostic
/// fact on the screen: on QA one work item carried 236 of them, and that count
/// is what identified a spin loop nobody had noticed. Dropping the rows would
/// replace a false state ("236 transitions happened") with a different false
/// state ("nothing happened"), and it would hide the only trace the operator
/// has. The programme's own rule applies — a conclusion nobody can see is not a
/// conclusion the platform reached.
///
/// What changes is the WORDING, so the operator can tell "review started" from
/// "something tried to start a review and was refused", which is the
/// distinction the previous rendering erased.
///
/// ## WHY A MISSING OUTCOME IS TREATED AS REFUSED
///
/// `outcome` is nullable on the wire because the source may not be able to
/// report one. Treating null as "accepted" would reintroduce the original
/// defect the moment a client met a row without the field. An attempt whose
/// outcome is unknown is not evidence that the item moved, so it is worded as an
/// attempt.
String timelineMessageFor({
  required String from,
  required String to,
  required String? outcome,
}) => outcome == 'accepted'
    ? plainTransitionMessage(from, to)
    : refusedTransitionMessage(from, to);
