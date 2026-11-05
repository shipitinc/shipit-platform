import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart'
    show ActorType, TransitionTrigger, WorkItem, WorkItemState, WorkflowActor;
import 'package:scheduler/scheduler.dart' show JobStore;
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        WorkflowStore,
        WorkflowTransitionRejectedException;

import 'deploy_advance.dart'
    show deploymentArtifactFor, raiseDeploymentApproval;

/// The actor the sweep transitions and raises as.
///
/// `qaPassed -> deploying` and `deploying -> waitingForHumanDecision` both
/// admit the orchestrator alone. The id names the machine path, exactly as
/// `qa-drain` and `operator-deploy` name theirs: the transition record is
/// the audit, and it must say WHICH caller took the edge.
const WorkflowActor deploySweepActor = WorkflowActor(
  actorId: 'deploy-sweep',
  actorType: ActorType.orchestrator,
);

/// The `raisedBy` stamped on the decisions and artifacts the sweep mints.
///
/// The durable row names the raiser so a later reader can tell the machine
/// advance from the operator's (`work_item_action.advanceToDeploy`) without
/// inferring it from the decision type — both raise `deploymentApproval`.
const String deploySweepRaisedBy = 'deploy_gate_sweep';

/// What one deploy-gate sweep concluded, for the composition root to report.
class DeploySweepResult {
  const DeploySweepResult({
    required this.considered,
    required this.advanced,
    required this.gateRaised,
    required this.deferred,
    required this.faulted,
    required this.outcomes,
  });

  /// Items the pass looked at: `qaPassed`, plus gateless `deploying`.
  final int considered;

  /// `qaPassed` items the pass advanced through `deploying` to
  /// `waiting_for_human_decision`, each with a pending
  /// `deploymentApproval` decision.
  final int advanced;

  /// Gateless `deploying` items — interrupted advances — whose missing
  /// `deploymentApproval` decision the pass raised.
  final int gateRaised;

  /// Items the pass deliberately left where they were: live work still
  /// holds them, or there is no completed producer result to build an
  /// honest artifact from. Each is re-evaluated next tick.
  final int deferred;

  /// Items the pass could not finish for an unexpected reason, reported per
  /// item and retried next tick.
  final int faulted;

  /// One entry per item, in the order the pass handled them.
  final List<DeploySweepItemOutcome> outcomes;

  /// Whether the pass moved anything at all.
  bool get movedAnything => advanced + gateRaised > 0;

  /// Items the pass left waiting for a human.
  int get awaitingHuman =>
      outcomes.where((outcome) => outcome.raisedDecisionId != null).length;
}

/// What the sweep did with one work item.
class DeploySweepItemOutcome {
  const DeploySweepItemOutcome({
    required this.workItemId,
    required this.outcomeKind,
    required this.toState,
    required this.detail,
    this.raisedDecisionId,
  });

  final String workItemId;

  /// `advanced`, `gate_raised`, `deferred` or `fault`.
  ///
  /// `advanced` and `gate_raised` are the same arrival by two paths: the
  /// item is at `waiting_for_human_decision` with a `deploymentApproval`
  /// pending. `deferred` means nothing was moved, deliberately; `fault`
  /// means the pass could not finish — including the transition that
  /// committed while its gate raise was refused.
  final String outcomeKind;

  /// The state the item was left in, or `null` when it was not moved.
  final WorkItemState? toState;

  /// One sentence, safe to log.
  final String detail;

  /// The id of the blocking `deploymentApproval` decision now holding the
  /// item, when one does.
  final String? raisedDecisionId;
}

/// The deploy-gate sweep: the thing that moves a `qa_passed` item to the
/// human it was waiting for all along.
///
/// ## THE DEFECT THIS CLOSES
///
/// `pendingDecisions` — the Needs You surface — lists only items whose
/// `blockingHumanDecisionId` names an open decision. A `qa_passed` item
/// carries NO pending decision: the QA contract passed, nothing refused,
/// and the `deploymentApproval` gate that would make it visible existed
/// only as a manual operator action (`advanceToDeploy`). So every item that
/// passed QA parked at `qa_passed` invisibly until a human opened its run
/// detail and pressed deploy — a human gate that was never raised, on an
/// item that could not say so.
///
/// ## WHAT IT DOES
///
/// For every `qaPassed` item the store holds, the sweep fires the same
/// honest sequence the operator action does — shared in
/// `deploy_advance.dart` so the two cannot drift:
///
///  1. `qaPassed -> deploying`, guarded by `artifactBuilt()` on a
///     [DeploymentArtifact] built from the producer's own durable
///     `AgentResult` — never a fabricated one; and
///  2. `requestHumanDecision(deploymentApproval)` -> `deploying ->
///     waitingForHumanDecision`, which is the write that lands the item in
///     Needs You.
///
/// ## THE TWO-DURABLE-STEP RULE, AND THE STRAND IT CAN LEAVE
///
/// The transition and the raise are two writes. A crash between them leaves
/// the item at `deploying` with no blocking decision — a gateless strand
/// with no pending decision to surface and no edge a human can act on. So
/// `deploying` with a null `blockingHumanDecisionId` is a candidate too:
/// the sweep FINISHES the raise rather than re-transitioning, exactly as
/// `advanceToDeploy` finishes the same strand for a replayed operator
/// intent. Whoever advanced the item — this sweep or a human — the missing
/// gate is the same one owed.
///
/// ## WHAT IT DOES NOT DO
///
///  * It does not deploy anything. The advance lands the item at the human
///   gate; the answer is the human's, and the sweep never resolves the
///   decision it raises.
///  * It does not invent an artifact. An item with no completed producer
///   result — nothing honest to deploy — stays `qa_passed`, deferred rather
///   than failed, and is re-evaluated next tick.
///  * It does not stack an advance on live work. A `qa_passed` item a
///   non-terminal job still holds is deferred to the next pass — the same
///   `alreadyRunning` rule `advanceToDeploy` applies.
///  * It has no budget. The pass is a sweep: every candidate is handled,
///   every pass, and idempotency is what makes that safe rather than a cap.
Future<DeploySweepResult> runDeployGateSweep({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required JobStore jobStore,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final List<WorkItem> items;
  try {
    items = await workflowStore.readAllWorkItems();
  } catch (error, stack) {
    log?.call('deploy.sweep.read_failed', {
      'error': '$error',
      'stack': stack.toString(),
      'action':
          'the deploy-gate sweep read no work items, so nothing was '
          'advanced; the next tick retries and the other lanes are '
          'unaffected',
    });
    return const DeploySweepResult(
      considered: 0,
      advanced: 0,
      gateRaised: 0,
      deferred: 0,
      faulted: 0,
      outcomes: [],
    );
  }

  final candidates = items
      .where(
        (item) =>
            item.state == WorkItemState.qaPassed ||
            (item.state == WorkItemState.deploying &&
                item.blockingHumanDecisionId == null),
      )
      .toList();

  final outcomes = <DeploySweepItemOutcome>[];
  var advanced = 0;
  var gateRaised = 0;
  var deferred = 0;
  var faulted = 0;

  for (final item in candidates) {
    // One item's failure is its own. The pass is unbounded, so a fault on
    // item N is recorded and item N+1 is still handled — the same property
    // the QA drain's per-item containment keeps.
    try {
      if (item.state == WorkItemState.deploying) {
        final outcome = await _finishInterruptedAdvance(
          workflowEngine: workflowEngine,
          workflowStore: workflowStore,
          item: item,
          log: log,
        );
        outcomes.add(outcome);
        if (outcome.toState == WorkItemState.waitingForHumanDecision) {
          gateRaised++;
        } else {
          faulted++;
        }
        continue;
      }

      final outcome = await _advanceQaPassed(
        workflowEngine: workflowEngine,
        workflowStore: workflowStore,
        executionStore: executionStore,
        workerStore: workerStore,
        jobStore: jobStore,
        item: item,
        log: log,
      );
      outcomes.add(outcome);
      switch (outcome.outcomeKind) {
        case 'advanced':
          advanced++;
        case 'deferred':
          deferred++;
        default:
          faulted++;
      }
    } catch (error, stack) {
      faulted++;
      outcomes.add(
        DeploySweepItemOutcome(
          workItemId: item.workItemId,
          outcomeKind: 'fault',
          toState: null,
          detail:
              'the pass could not finish this item ($error); it was left '
              'where it was and the next tick retries',
        ),
      );
      log?.call('deploy.sweep.item.faulted', {
        'workItemId': item.workItemId,
        'error': '$error',
        'stack': stack.toString(),
      });
    }
  }

  return DeploySweepResult(
    considered: candidates.length,
    advanced: advanced,
    gateRaised: gateRaised,
    deferred: deferred,
    faulted: faulted,
    outcomes: outcomes,
  );
}

/// Finishes an advance that committed its transition and died before the
/// raise: `deploying` with no blocking decision gets the gate it is owed.
///
/// The item is NOT re-transitioned — the durable `deploying` write already
/// stands — and no artifact is needed: `artifactBuilt()` guarded the edge
/// into `deploying`, not the raise out of it.
Future<DeploySweepItemOutcome> _finishInterruptedAdvance({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required WorkItem item,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final parked = await raiseDeploymentApproval(
    workflowEngine: workflowEngine,
    workflowStore: workflowStore,
    item: item,
    actor: deploySweepActor,
    raisedBy: deploySweepRaisedBy,
    log: log,
  );
  if (parked.state == WorkItemState.waitingForHumanDecision) {
    log?.call('deploy.sweep.item.gate_raised', {
      'workItemId': item.workItemId,
      'decisionId': parked.blockingHumanDecisionId,
    });
    return DeploySweepItemOutcome(
      workItemId: item.workItemId,
      outcomeKind: 'gate_raised',
      toState: parked.state,
      detail:
          'the item was found at deploying with no blocking decision — an '
          'advance that committed its transition and never raised the '
          'gate; the missing deployment_approval decision was raised and '
          'the item is waiting for a human',
      raisedDecisionId: parked.blockingHumanDecisionId,
    );
  }
  return DeploySweepItemOutcome(
    workItemId: item.workItemId,
    outcomeKind: 'fault',
    toState: parked.state,
    detail:
        'the item is at deploying with no blocking decision and the '
        'deployment_approval raise was refused; it stays gateless until '
        'the next tick retries',
  );
}

/// Advances one `qa_passed` item to the human gate: transition, then raise.
Future<DeploySweepItemOutcome> _advanceQaPassed({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required JobStore jobStore,
  required WorkItem item,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  // (1) A live attempt is never stacked on — the same rule
  // `advanceToDeploy` applies (`alreadyRunning`). Deferred, not refused:
  // the job may finish this tick and the next pass re-evaluates honestly.
  final jobs = await jobStore.listJobsForWorkItem(item.workItemId);
  if (jobs.any((j) => j.state.isActive)) {
    return DeploySweepItemOutcome(
      workItemId: item.workItemId,
      outcomeKind: 'deferred',
      toState: null,
      detail:
          'a non-terminal job still holds this work item, so the deploy '
          'advance was not stacked on top of live work; the next tick '
          're-evaluates',
    );
  }

  // (2) THE ARTIFACT. No durable producer result means there is nothing
  // honest to deploy — the item stays qa_passed, deferred rather than
  // failed: its producer may simply not have landed yet.
  final artifact = await deploymentArtifactFor(
    executionStore: executionStore,
    workerStore: workerStore,
    item: item,
    // Deterministic in this residence of the item — see the idempotency
    // key below for why the version scopes it.
    advanceId: 'sweep-v${item.version}',
    builtBy: deploySweepActor.actorId,
    raisedBy: deploySweepRaisedBy,
    log: log,
  );
  if (artifact == null) {
    return DeploySweepItemOutcome(
      workItemId: item.workItemId,
      outcomeKind: 'deferred',
      toState: null,
      detail:
          'no completed producer result could be resolved into a '
          'deployment artifact, so there is nothing honest to deploy; the '
          'item stays qa_passed and the next tick re-evaluates',
    );
  }

  // (3) THE ONE DURABLE WRITE. The artifact satisfies `artifactBuilt()`
  // inside this call's context; it is evaluated and discarded, exactly as
  // the operator path's is.
  final WorkItem deploying;
  try {
    deploying = await workflowEngine.transition(
      workItemId: item.workItemId,
      to: WorkItemState.deploying,
      trigger: TransitionTrigger.systemEvent,
      actor: deploySweepActor,
      context: {'deploymentArtifact': artifact, 'deploySweep': true},
      // Scoped to the item's durable REVISION. A retried pass over the
      // same `qa_passed` residence replays the same key and is a no-op;
      // an item that somehow re-enters `qa_passed` carries a strictly
      // higher version, mints a new key, and is genuinely advanced again
      // rather than handed back a stale accepted record.
      idempotencyKey:
          'deploy-sweep:${item.workItemId}:advance:v${item.version}',
      reason:
          'the QA contract passed; the deploy advance was raised '
          'automatically so the approval gate reaches a human',
    );
  } on WorkflowTransitionRejectedException catch (error) {
    log?.call('deploy.sweep.item.advance_refused', {
      'workItemId': item.workItemId,
      'reason': error.record.reason ?? error.record.outcome.wire,
    });
    return DeploySweepItemOutcome(
      workItemId: item.workItemId,
      outcomeKind: 'deferred',
      toState: null,
      detail:
          'the qa_passed -> deploying edge refused the advance '
          '(${error.record.reason ?? error.record.outcome.wire}); the item '
          'was not moved',
    );
  }

  // (4) THE GATE. If the raise is refused here the item is left at
  // `deploying` gateless — the strand this sweep's other arm exists to
  // finish on the next pass.
  final parked = await raiseDeploymentApproval(
    workflowEngine: workflowEngine,
    workflowStore: workflowStore,
    item: deploying,
    actor: deploySweepActor,
    artifactId: artifact.artifactId,
    raisedBy: deploySweepRaisedBy,
    log: log,
  );
  if (parked.state == WorkItemState.waitingForHumanDecision) {
    log?.call('deploy.sweep.item.advanced', {
      'workItemId': item.workItemId,
      'artifactId': artifact.artifactId,
      'decisionId': parked.blockingHumanDecisionId,
    });
    return DeploySweepItemOutcome(
      workItemId: item.workItemId,
      outcomeKind: 'advanced',
      toState: parked.state,
      detail:
          'the item was advanced qa_passed -> deploying and a blocking '
          'deployment_approval decision was raised; it is waiting for a '
          'human',
      raisedDecisionId: parked.blockingHumanDecisionId,
    );
  }
  return DeploySweepItemOutcome(
    workItemId: item.workItemId,
    outcomeKind: 'fault',
    toState: parked.state,
    detail:
        'the qa_passed -> deploying transition committed but the '
        'deployment_approval raise was refused; the item is gateless at '
        'deploying and the next tick finishes the raise',
  );
}
