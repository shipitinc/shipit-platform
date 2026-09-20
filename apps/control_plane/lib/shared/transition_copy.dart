/// Plain-language presentation for the run detail timeline.
///
/// The transition-pair keys mirror the accepted-pair table in
/// `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`
/// plus the generic non-terminal -> cancelled/terminated escapes, and use the
/// same snake_case wire values as `WorkItemState.wire`
/// (`packages/platform_contracts/lib/src/enums/workflow_state.dart`).
/// Presentation only: the durable raw pair is always retained for the
/// technical detail layer, never replaced.
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
  // A plan that goes straight into review skips the `design_required` hop.
  ('planned', 'design_in_review') => 'Design needed before building',
  ('planned', 'design_not_required') => 'No design needed, ready to build',
  ('design_required', 'design_in_review') => 'Design under review',
  ('design_in_review', 'waiting_for_human_decision') =>
    'Sent to you for approval',
  ('waiting_for_human_decision', 'design_approved') => 'Design approved',
  ('waiting_for_human_decision', 'design_rejected') => 'Design not approved',
  ('waiting_for_human_decision', 'design_in_review') =>
    'Changes asked for, design updated',
  ('design_approved', 'agent_executing') => 'Agent started work',
  ('design_rejected', 'design_in_review') =>
    'Design updated, waiting on review',
  ('design_not_required', 'agent_executing') => 'Agent started work',
  ('agent_executing', 'agent_completed') => 'Agent finished its work',
  ('agent_executing', 'agent_failed') => "Agent's work hit an error",
  ('agent_failed', 'agent_executing') => 'Retrying after an error',
  ('agent_completed', 'review_in_progress') => 'Independent review started',
  ('review_in_progress', 'waiting_for_human_decision') =>
    'Sent to you for approval',
  ('waiting_for_human_decision', 'review_approved') => 'Review approved',
  ('waiting_for_human_decision', 'review_rejected') => 'Review not approved',
  ('waiting_for_human_decision', 'agent_executing') =>
    'Changes asked for, work resumed',
  ('review_approved', 'qa_in_progress') => 'QA started',
  ('review_rejected', 'agent_executing') => 'Changes asked for, work resumed',
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
