enum WorkItemState {
  draft('draft'),
  planning('planning'),
  planned('planned'),
  featureIntakeParked('feature_intake_parked'),
  // The DESIGN park: where a design-remediation item rests until the design
  // governance runtime is ready to release it.
  //
  // It exists instead of parking at `planned` because `planned` is NOT a
  // holding state. `triageDefectDefinition.entryStates` contains `planned`, and
  // `planned -> designNotRequired` is guarded by `actorAllowed([orchestrator])`
  // ALONE, so the category-blind triage scheduler takes a remediation item back
  // OUT of `planned` and re-dispatches it, for ever. `designParked` is in the
  // `entryStates` of NO definition, so no scheduler can see, probe or hop an
  // item resting here — the same structural property `featureIntakeParked` was
  // built for, reached without relying on winning a race against the scheduler.
  //
  // Its out-edges are `-> designRequired` (the release, guarded by
  // `designContractExists()`, which reads the durable column and confirms it
  // against a store) and `-> waitingForHumanDecision` (operator recovery,
  // "slower and deliberately so"). It has no edge to `planned`: `planned`'s sole
  // predecessor is pinned as `planning`, and an edge back would re-open the loop
  // that pin exists to close.
  //
  // `isTerminal` needs no change (that switch has a `_ => false` arm), and
  // `WorkItemWorkflowState.allowedTransitions` MUST gain a case — that switch is
  // exhaustive with no default, so omitting it is a COMPILE error rather than a
  // silent lie, and `transition_consistency_test.dart` then cross-checks the
  // mirror against the real table.
  designParked('design_parked'),
  designRequired('design_required'),
  designNotRequired('design_not_required'),
  designInReview('design_in_review'),
  designApproved('design_approved'),
  designRejected('design_rejected'),
  // The IMPLEMENTATION lane's own entry state, and the whole mechanism by
  // which implementation and triage cannot contend for one work item.
  //
  // It is a DISTINCT state rather than a new `JobDefinition` over an existing
  // one because `RunnableWorkEvaluator` rejects an item not in
  // `definition.entryStates` BEFORE it asks the policy anything
  // (`packages/scheduler/lib/src/policy/runnable_work.dart:142-144`), and
  // `EntryHopper` may only land a hop on ITS OWN definition's entry states
  // (`packages/scheduler/lib/src/policy/entry_hop.dart:288-297`). Two
  // definitions whose entry sets are disjoint therefore cannot both classify
  // one item runnable in one tick, and no hop can be the mechanism that moves
  // it between them. That is STRUCTURAL: it survives forgetting a guard,
  // because there is no guard to forget.
  //
  // It sits in the execution cluster because that is where the lane it feeds
  // lives. `isTerminal` needs no change (that switch has a `_ => false` arm),
  // and `WorkItemWorkflowState.allowedTransitions` MUST gain a case — that
  // switch is exhaustive with no default, so omitting it is a COMPILE error
  // rather than a silent lie, and `transition_consistency_test.dart` then
  // cross-checks the mirror against the real table.
  implementationReady('implementation_ready'),
  agentExecuting('agent_executing'),
  agentCompleted('agent_completed'),
  agentFailed('agent_failed'),
  reviewInProgress('review_in_progress'),
  reviewApproved('review_approved'),
  reviewRejected('review_rejected'),
  qaInProgress('qa_in_progress'),
  qaPassed('qa_passed'),
  qaFailed('qa_failed'),
  waitingForHumanDecision('waiting_for_human_decision'),
  deploying('deploying'),
  deployed('deployed'),
  deploymentFailed('deployment_failed'),
  completed('completed'),
  cancelled('cancelled'),
  terminated('terminated'),
  @Deprecated(
    'Use completed instead. done is parse-only and never a legal '
    'transition target.',
  )
  done('done');

  const WorkItemState(this.wire);

  final String wire;

  bool get isTerminal => switch (this) {
    completed || cancelled || terminated || done => true,
    _ => false,
  };

  bool get isWaitingForHumanDecision =>
      this == WorkItemState.waitingForHumanDecision;

  static WorkItemState fromWire(String value) => values.firstWhere(
    (state) => state.wire == value,
    orElse: () => throw FormatException('Unknown work item state: $value'),
  );
}

enum DesignContractStatus { draft, underReview, approved, rejected, expired }

enum QAStatus { pending, inProgress, passed, failed, waived }

enum DeploymentPhase {
  building,
  promoting,
  deploying,
  validating,
  completed,
  failed,
  rolledBack,
}
