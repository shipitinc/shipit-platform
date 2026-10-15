import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, resolveProducerExecution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show SchedulerStall;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowTransitionRejectedException;

/// The `metadata` key under which every stall raised for one work item is
/// recorded on its decision, so a second lane's stall cannot displace the
/// first and an operator can see that more than one lane stopped.
const String stalledWorkItemMetadataKey = 'schedulerStall';

/// The operator-facing conclusion of one [SchedulerStall], as it will be
/// recorded on the work item's blocking decision.
///
/// ## WHY A HUMAN DECISION AND NOT A LOG LINE
///
/// A `SchedulerStall` is the platform saying "I have stopped producing work for
/// this item and I do not think I can produce it again". Before this gate that
/// conclusion was written to `scheduler_event.payloadJson` and read by nobody,
/// while the item's state said `agent_completed` and every operator screen
/// called it "Awaiting review". **An event-log string nobody reads is not
/// surfacing.** See
/// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §6.
///
/// It reuses the SAME shape `engineeringReviewMissingArtifact` established for
/// `SchedulerTickResult.blockedArtifactMissing`: the scheduler produces a
/// fail-closed conclusion, and the composition root turns it into a blocking
/// `HumanDecision`. Nothing new is invented, and — the property that matters —
/// the decision is ALREADY reachable from the existing control-plane decision
/// screen, which renders the gate's options and submits them through the
/// existing `resolveDecision` endpoint.
///
/// ## WHY `engineeringReview`, WHICH IS FORCED RATHER THAN CHOSEN
///
/// `agentCompleted` has no edge to `waitingForHumanDecision`; the only route
/// runs through `reviewInProgress`, and THAT edge carries
/// `blockingHumanDecisionPendingOfType([engineeringReview])`
/// (`work_item_transitions.dart:317`). So this gate cannot raise an `escalation`
/// on a stalled item at all — the state machine names the decision type for it.
/// Picking a different type here would have meant adding an edge, which is a
/// state-machine change and not this lane's to make.
///
/// ## AND `rework` IS THE RETRY
///
/// `HumanDecisionRouting.targetFor(engineeringReview, rework)` is
/// `implementationReady` — the implementation lane's entry state. So answering
/// "Request changes" is literally the operator retrying the item once the cause
/// is fixed: the work runs again, a fresh producer runs, and the item reaches
/// `agent_completed` with a fresh `producerActorId`.
///
/// That also lifts the stall by EVIDENCE rather than by a flag anybody has to
/// remember to clear: `Scheduler` lifts a stall when `WorkItem.version` moves
/// past the version recorded when it fired, and every resolution here is a real
/// transition. There is no "clear the stall" button because there is nothing to
/// clear.
///
/// ## THE ONE INTERACTION WORTH NAMING
///
/// `review_repair`'s `repairUnreviewedReview` classifies this decision as
/// repairable, because a stall-gate decision has no reviewer output and that is
/// precisely the class repair targets. So the repair affordance will also offer
/// "Set aside and re-review" on it. That is a SECOND correct recovery to the
/// same item, not a conflict, and suppressing it would mean editing
/// `apps/server/lib/src/review/**`, which this lane does not own.
const HumanDecisionType stalledWorkItemDecisionType =
    HumanDecisionType.engineeringReview;

/// What this gate did with one stall. Named rather than a bool because "I did
/// nothing" has three genuinely different reasons and an operator debugging a
/// stuck item needs to tell them apart.
enum StallGateOutcome {
  /// A blocking decision is now attached to the work item.
  raised,

  /// The item already carries a pending blocking decision of this type. The
  /// engine's own `requestHumanDecision` idempotency returned it, so no second
  /// question was asked.
  alreadyPending,

  /// The item is not in a state this gate may park from, so nothing was
  /// written. Logged, never silent.
  notParkable,

  /// No completed producer result could be read, so the
  /// `agentCompleted -> reviewInProgress` edge — the only route from
  /// `agentCompleted` to the human gate — could not be taken. The item is
  /// still stalled and still needs a human; this gate refuses to fabricate the
  /// result that would let it through.
  producerEvidenceUnreadable,
}

/// Turns one [SchedulerStall] into a blocking human decision, idempotently.
///
/// ## THE PARKING PATH, AND WHY IT REUSES THE PRODUCER RESOLUTION
///
/// `agentCompleted` has no direct edge to `waitingForHumanDecision`; the only
/// route runs through `reviewInProgress`, and that edge is guarded by
/// `agentResultValid()`. So this gate has to supply a completed producer result
/// — the very same one `_reviewEntryTransitionContext` supplies, and it calls
/// [resolveProducerExecution] rather than re-deriving it.
///
/// That sharing is not tidiness, it is the fix. This is the SECOND caller of
/// that rule, and before the fix the equivalent line in
/// `apps/server/lib/src/review/engineering_review_gate.dart` read
/// `latestExecutionForWorkItem` too. Two call sites that each re-derive "what
/// produced this item" is how they come to disagree; one function is how they
/// cannot. (That sibling line is in a path this lane does not own and is
/// reported, not fixed — see the correction report.)
///
/// ## IDEMPOTENCE, AND WHY IT IS NOT OPTIONAL
///
/// `Scheduler` re-reports a stall on EVERY tick for as long as it holds the
/// item, and the tick period is 30s. Without idempotence this would mint a new
/// decision every 30 seconds. `DurableWorkflowEngine.requestHumanDecision`
/// already returns the existing pending decision for an item parked at the
/// gate, so the guard here is the state check that routes us there rather than
/// minting.
Future<StallGateOutcome> raiseStallDecision({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required SchedulerStall stall,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final workItemId = stall.workItemId;
  final item = await workflowEngine.loadWorkItem(workItemId);

  if (item.state == WorkItemState.waitingForHumanDecision) {
    logger?.call('stall.already-parked', {
      'workItemId': workItemId,
      'jobType': stall.jobType.wire,
    });
    return StallGateOutcome.alreadyPending;
  }

  if (item.state == WorkItemState.reviewInProgress) {
    // Already through the only gate edge. Raise and let the engine's own
    // idempotency answer if one is already pending.
  } else if (item.state == WorkItemState.agentCompleted) {
    final producer = await resolveProducerExecution(
      store: executionStore,
      workItemId: workItemId,
      producerActorId: item.metadata?['producerActorId'],
    );
    final producerResult = producer.result;
    if (producerResult == null) {
      // Forcing it would fabricate the very evidence `agentResultValid()`
      // exists to check. The item stays stalled and still needs a human; this
      // is a visible block, not a quiet one.
      logger?.call('stall.producer-evidence-unreadable', {
        'workItemId': workItemId,
        'jobType': stall.jobType.wire,
        'producer': producer.note,
        'action':
            'no work item decision was raised. The stall stands and the item '
            'still needs a person; nothing was fabricated to unblock it',
      });
      return StallGateOutcome.producerEvidenceUnreadable;
    }
    try {
      await workflowEngine.transition(
        workItemId: workItemId,
        to: WorkItemState.reviewInProgress,
        trigger: TransitionTrigger.agentResult,
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        context: {
          'agentAvailable': true,
          'capabilitiesMatch': true,
          'agentResult': producerResult,
        },
      );
    } on WorkflowTransitionRejectedException catch (e) {
      logger?.call('stall.park-refused', {
        'workItemId': workItemId,
        'error': e.toString(),
      });
      return StallGateOutcome.notParkable;
    }
  } else {
    logger?.call('stall.not-parkable', {
      'workItemId': workItemId,
      'state': item.state.wire,
      'jobType': stall.jobType.wire,
      'action':
          'this lane has stopped launching work for this item, but the item is '
          'not at a state this gate may park from. Nothing was written',
    });
    return StallGateOutcome.notParkable;
  }

  try {
    await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: stalledWorkItemDecisionType,
      question: stallQuestion(stall),
      options: const [
        HumanDecisionOption(
          optionId: 'rework',
          label: 'Start this work again',
          description:
              'The cause is fixed. Send it back to be built and reviewed again.',
        ),
        HumanDecisionOption(
          optionId: 'cancel',
          label: 'Stop this work',
          description: 'Stop working on this. The record is kept.',
        ),
      ],
      recommendation: 'REWORK',
      blocking: true,
      metadata: stallMetadata(stall),
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      // `actorIsNotSelf()` reads the producer identity off the context and FAILS
      // CLOSED when it is absent — same reason `engineeringReviewMissingArtifact`
      // passes it. An empty string is still a present key, which is what the
      // guard's "producer identity required" arm needs to distinguish "no
      // producer recorded" from "context not supplied at all".
      extraContext: {
        'producerActorId': item.metadata?['producerActorId'] as String? ?? '',
      },
    );
  } on WorkflowTransitionRejectedException catch (e) {
    logger?.call('stall.decision-refused', {
      'workItemId': workItemId,
      'error': e.toString(),
    });
    return StallGateOutcome.notParkable;
  }

  logger?.call('stall.parked', {
    'workItemId': workItemId,
    'jobType': stall.jobType.wire,
    'deferrals': stall.deferrals,
  });
  return StallGateOutcome.raised;
}

/// The one sentence an operator reads. Carries the item's state and how many
/// deferrals were spent, because "it stopped" without either is not actionable.
String stallQuestion(SchedulerStall stall) =>
    'This work cannot make progress and has been stopped automatically. It is '
    'at ${stall.state.wire}, and it burned ${stall.deferrals} attempts before '
    'the system stopped launching it. ${stall.reason}';

/// The structured facts, kept beside the prose so a surface can render them
/// without parsing English and a future reader can tell exactly what the
/// scheduler concluded.
Map<String, dynamic> stallMetadata(SchedulerStall stall) => {
  stalledWorkItemMetadataKey: {
    'workItemId': stall.workItemId,
    'state': stall.state.wire,
    'jobType': stall.jobType.wire,
    'deferrals': stall.deferrals,
    'reason': stall.reason,
  },
};

/// Raised [StallGateOutcome.alreadyPending] for every stall already carried.
///
/// Idempotent by contract: the scheduler re-reports a stall every tick for as
/// long as it holds, so a caller MUST be able to run this every tick without
/// minting a second question for the same item. One throw from one item is
/// contained here rather than being allowed to take the rest of the tick's
/// stalls — and the whole tick — with it.
Future<StallGateResult> raiseStallDecisions({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required List<SchedulerStall> stalls,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final outcomes = <StallGateOutcome>[];
  final failures = <String>[];

  // Item-id order, so two lanes reporting the same item produce the SAME
  // sequence of writes on every tick. Order-dependent behaviour across ticks is
  // how an "idempotent" handler produces a different decision each time.
  final ordered = [...stalls]
    ..sort(
      (a, b) => a.workItemId.compareTo(b.workItemId),
    );

  for (final stall in ordered) {
    try {
      outcomes.add(
        await raiseStallDecision(
          workflowEngine: workflowEngine,
          executionStore: executionStore,
          stall: stall,
          logger: logger,
        ),
      );
    } on Object catch (e, st) {
      failures.add(stall.workItemId);
      logger?.call('stall.decision-failed', {
        'workItemId': stall.workItemId,
        'jobType': stall.jobType.wire,
        'error': e.toString(),
        'stack': st.toString(),
        'action':
            'nothing was written for this item; it stays stalled and still '
            'needs a person. Retried on the next tick',
      });
    }
  }

  return StallGateResult(
    considered: ordered.length,
    raised: outcomes.where((o) => o == StallGateOutcome.raised).length,
    alreadyPending: outcomes
        .where((o) => o == StallGateOutcome.alreadyPending)
        .length,
    notParkable: outcomes
        .where((o) => o == StallGateOutcome.notParkable)
        .length,
    producerEvidenceUnreadable: outcomes
        .where((o) => o == StallGateOutcome.producerEvidenceUnreadable)
        .length,
    failedWorkItemIds: List.unmodifiable(failures),
  );
}

/// What one drain of a tick's [SchedulerStall]s did. Complete and
/// non-overlapping: `considered == raised + alreadyPending + notParkable +
/// producerEvidenceUnreadable + failedWorkItemIds.length`.
class StallGateResult {
  const StallGateResult({
    required this.considered,
    required this.raised,
    required this.alreadyPending,
    required this.notParkable,
    required this.producerEvidenceUnreadable,
    required this.failedWorkItemIds,
  });

  /// A drain of nothing.
  static const StallGateResult empty = StallGateResult(
    considered: 0,
    raised: 0,
    alreadyPending: 0,
    notParkable: 0,
    producerEvidenceUnreadable: 0,
    failedWorkItemIds: [],
  );

  final int considered;
  final int raised;
  final int alreadyPending;
  final int notParkable;
  final int producerEvidenceUnreadable;

  /// Ids whose handling THREW. Their outcome is dropped, not refused: the item
  /// stays stalled and will be re-offered on the next tick.
  final List<String> failedWorkItemIds;

  bool get isEmpty => considered == 0;

  @override
  String toString() =>
      'StallGateResult(considered: $considered, raised: $raised, '
      'alreadyPending: $alreadyPending, notParkable: $notParkable, '
      'unreadableProducer: $producerEvidenceUnreadable, '
      'failed: ${failedWorkItemIds.length})';
}
