/// Plain-language presentation for the run detail timeline.
///
/// The transition-pair keys mirror the accepted-pair table in
/// `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`
/// plus the generic non-terminal -> cancelled/terminated escapes, and use the
/// same snake_case wire values as `WorkItemState.wire`
/// (`packages/platform_contracts/platform_contracts`). Presentation only: the
/// durable raw pair is always retained for the technical detail layer, never
/// replaced.
///
/// This package cannot depend on `workflow_engine` (it is a Flutter app; the
/// engine is a pure Dart package below it), so the "every accepted pair has
/// copy" property is enforced by `test/shared/transition_copy_test.dart`, which
/// enumerates the engine's table LIVE from source rather than from a
/// hand-maintained list. A hardcoded list is what let a missing pair through
/// once already. Add an edge to the engine and that test names the missing copy.
///
/// Principle (004 §11/§14): PLAIN LANGUAGE BY DEFAULT, TECHNICAL TRUTH
/// DELIBERATELY AVAILABLE. Raw internal pairs therefore never appear as the
/// sole copy on the timeline; genuinely unknown pairs get a neutral
/// lifecycle description and the exact raw pair is exposed in technical
/// details.
library;

/// Human copy for accepted transition pairs (keys are wire values).
String? knownTransitionMessage(String from, String to) => switch ((from, to)) {
  ('draft', 'planning') => 'Work created',
  ('planning', 'planned') => 'Work planned',
  ('planning', 'cancelled') => 'Work cancelled',
  ('planned', 'design_required') => 'Design needed before building',
  ('planned', 'design_not_required') => 'No design needed, ready to build',
  // ---- The parks (feature intake, design) and their ways out ----
  //
  // A park is a state in no lane's `entryStates`: an item resting in one is
  // dispatchable by nobody, which is the point of parking it. These six arms
  // are every engine-accepted pair into, out of and between the parks; each
  // claim below comes from the engine table's own comment beside its edge
  // (`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`)
  // or from the code that takes the edge.
  //
  // Work entry walks a FEATURE request here and stops, because no consumer
  // runtime exists for feature work: the request is accepted and parked —
  // not refused, not failed (the exact words `work_entry.dart` records).
  ('planned', 'feature_intake_parked') =>
    'Feature accepted and parked — not refused, not failed',
  // The sanctioned recovery for a feature that took the old bad hop: the
  // category-blind scheduler once dispatched it as a defect and advanced it
  // to `agentExecuting`. This moves it back to the park work entry should
  // have left it in, and says "wrong lane" so the interrupted run is not
  // read as a build that finished.
  ('agent_executing', 'feature_intake_parked') =>
    'Wrong lane — feature returned to its intake park',
  // Lane E walks a design-remediation item here because triage may not
  // produce design artifacts: the item rests where no scheduler can see it
  // until a durable design contract can back its release, rather than
  // sitting at `planned` where the category-blind triage lane would take it
  // back out and redispatch it, forever.
  ('planned', 'design_parked') =>
    'Design remediation parked — cannot start yet',
  // THE RELEASE (R2.3): the work item's durable `designContractId` resolves
  // against a `DesignContractStore`, so the item leaves the park for
  // design's entry state. The copy promises the contract and the release,
  // not a design run — the design lane dispatching is the next hop's
  // business, not this one's.
  ('design_parked', 'design_required') =>
    'Design contract in place, released from parking',
  // The operator route out of the design park (R2.4): the parked item goes
  // to the human gate, where a decision is pending and `evaluate` reports
  // `blocked`, so nothing dispatches while it waits there.
  ('design_parked', 'waiting_for_human_decision') =>
    'Parked design sent to you for a decision',
  // THE way out of the feature park — the table's own comment names it as
  // the one non-cancel exit: the park is in no definition's `entryStates`,
  // so without this edge a parked feature could only be cancelled or
  // terminated. It lands at the same human gate as the design park's route.
  ('feature_intake_parked', 'waiting_for_human_decision') =>
    'Parked feature sent to you for a decision',
  ('design_required', 'design_in_review') => 'Design under review',
  ('design_required', 'agent_executing') => 'Agent started work',
  ('design_in_review', 'waiting_for_human_decision') =>
    'Sent to you for approval',
  // Work can proceed to execution straight out of design review when the
  // design revision is settled and only the build is outstanding.
  ('design_in_review', 'agent_executing') => 'Agent started work',
  ('waiting_for_human_decision', 'design_approved') => 'Design approved',
  ('waiting_for_human_decision', 'design_rejected') => 'Design not approved',
  ('waiting_for_human_decision', 'design_in_review') =>
    'Changes asked for, design updated',
  ('design_approved', 'agent_executing') => 'Agent started work',
  ('design_rejected', 'design_in_review') =>
    'Design updated, waiting on review',
  ('design_not_required', 'agent_executing') => 'Agent started work',
  // The implementation lane's own entry and exit. Two pairs, both spelled out,
  // because both would otherwise fall through to `_ => null` and render as
  // "The work moved to a new stage." — which is the one message that says
  // nothing at all, on a screen where the operator is trying to see whether the
  // build started.
  ('implementation_ready', 'agent_executing') => 'Agent started building it',
  // Inbound, from the human gate. The same "queued to start again" promise the
  // `-> design_not_required` copy above makes, because that is exactly what a
  // rework resolution does; only the lane is different.
  ('waiting_for_human_decision', 'implementation_ready') =>
    'Changes asked for, work queued to build again',
  ('agent_executing', 'agent_completed') => 'Agent finished its work',
  ('agent_executing', 'agent_failed') => "Agent's work hit an error",
  ('agent_failed', 'agent_executing') => 'Retrying after an error',
  // The operator pressed "try again" on a failed run. This is the retry
  // returning the item to a state the scheduler dispatches from, so the copy
  // is the queue, not a second "retrying" that duplicates the line above.
  ('agent_failed', 'design_not_required') => 'Trying again after an error',
  ('agent_completed', 'review_in_progress') => 'Independent review started',
  // The implementation finished and produced a commit, so the item enters the
  // build lane. Distinct from `review_in_progress` above: that one goes to a
  // REVIEWER, this one sends it to a BUILDER.
  ('agent_completed', 'implementation_ready') => 'Ready to build',
  // ---- The retry-return edges (decision 3659984d, option A) ----
  //
  // A retryable failure used to leave the item here permanently: the scheduled
  // retry could not be claimed, because the item had left its lane's entry
  // states. These four edges put it back, so the item becomes dispatchable
  // again. The copy says "trying again" rather than "failed", because that is
  // what will actually happen next, and an operator reading "failed" here has
  // been told something that is no longer true.
  ('agent_failed', 'implementation_ready') => 'Trying the build again',
  ('agent_failed', 'design_required') => 'Trying design again',
  ('agent_failed', 'design_in_review') => 'Trying design review again',
  // A reviewer that timed out is not a rejected review. Saying "review
  // restarted" keeps the distinction from `('review_rejected', ...)` below
  // visible: nothing was reviewed and nothing was judged.
  ('review_in_progress', 'agent_completed') =>
    'Review did not finish — queued to run again',
  // The implementation turned out to need a design revision, so the item goes
  // back to design rather than to review.
  ('agent_completed', 'design_in_review') => 'Design revision needed',
  ('review_in_progress', 'waiting_for_human_decision') =>
    'Sent to you for approval',
  ('waiting_for_human_decision', 'review_approved') => 'Review approved',
  ('waiting_for_human_decision', 'review_rejected') => 'Review not approved',
  // One pair, five different gates (engineering review rework, QA waiver
  // rejection, QA rework rejection, human QA rejection, escalation resume), so
  // the copy is the one thing true of all five: the human asked for the work
  // to be done again and it is queued to start again.
  ('waiting_for_human_decision', 'design_not_required') =>
    'Changes asked for, work queued to start again',
  ('waiting_for_human_decision', 'agent_executing') =>
    'Changes asked for, work resumed',
  ('waiting_for_human_decision', 'planning') => 'Sent back to be re-planned',
  ('review_approved', 'qa_in_progress') => 'QA started',
  ('review_rejected', 'design_not_required') =>
    'Review not approved, work queued to start again',
  ('review_rejected', 'design_in_review') =>
    'Changes asked for, design updated',
  ('qa_in_progress', 'qa_passed') => 'QA passed',
  ('qa_in_progress', 'qa_failed') => 'QA found something to fix',
  ('qa_passed', 'waiting_for_human_decision') => 'QA passed, sent to you',
  ('qa_failed', 'waiting_for_human_decision') => 'QA found issues, sent to you',
  ('waiting_for_human_decision', 'qa_passed') => 'QA results accepted',
  ('waiting_for_human_decision', 'completed') => 'Work finished',
  ('qa_passed', 'deploying') => 'Deploy started',
  ('deploying', 'waiting_for_human_decision') => 'Ready to deploy, sent to you',
  ('waiting_for_human_decision', 'deployed') => 'Deploy approved',
  ('waiting_for_human_decision', 'deployment_failed') => 'Deploy not approved',
  ('deploying', 'deployed') => 'Deployed',
  ('deploying', 'deployment_failed') => 'Deploy hit an error',
  ('deployment_failed', 'deploying') => 'Deploy retried',
  ('deployed', 'completed') => 'Work finished',
  (_, 'cancelled') => 'Work cancelled',
  (_, 'terminated') => 'Work stopped',
  _ => null,
};

/// Neutral, truthful default for pairs without dedicated copy. Describes a
/// lifecycle stage change without inventing semantics for the unknown pair.
const String kUnknownTransitionMessage = 'The work moved to a new stage.';

/// Exact durable raw pair, for the technical detail layer.
String rawTransitionPair(String from, String to) => '$from -> $to';

/// Default-surface message: known copy, or the neutral default.
String plainTransitionMessage(String from, String to) =>
    knownTransitionMessage(from, to) ?? kUnknownTransitionMessage;
