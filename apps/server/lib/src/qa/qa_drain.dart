import 'package:platform_contracts/platform_contracts.dart'
    show
        ActorType,
        HumanDecision,
        HumanDecisionOption,
        HumanDecisionType,
        TransitionTrigger,
        WorkItem,
        WorkItemState,
        WorkflowActor;
import 'package:qa_orchestration/qa_orchestration.dart'
    show
        QAGateEvaluationFault,
        QAGateEvaluationOutcome,
        QAGateEvaluationService;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        WorkflowStore,
        WorkflowTransitionRejectedException;

import 'production_qa_sources.dart' show ProducerResolver;

/// The actor the drain acts as when it TAKES an item, and when it records a
/// FAILURE.
///
/// ## WHY THERE ARE TWO ACTORS
///
/// The design fixes the distinction (`evaluator-spec.md` §4.2, step 4): the
/// transition out of `qaInProgress` is taken with `ActorType.qaExecutor` when
/// the contract passed and with `ActorType.orchestrator` when it did not.
/// Both edges admit both actors, so no guard turns on it — but the AUDIT
/// TRAIL does, and the trail is what a later reader has. A passing verdict is
/// the QA executor's own determination. A failure is the orchestrator's
/// record of a verdict the executor produced, and the orchestrator is the
/// actor that then asks a human what to do about it.
///
/// The take (`reviewApproved -> qaInProgress`) and the escalation
/// (`qaFailed -> waitingForHumanDecision`) admit only the orchestrator, so
/// both of those are the orchestrator's.
const WorkflowActor qaDrainActor = WorkflowActor(
  actorId: 'qa-drain',
  actorType: ActorType.orchestrator,
);

/// The actor a PASSING verdict is settled by.
///
/// A pass is the QA executor's own determination, so it is settled as the QA
/// executor rather than as the orchestrator that happened to run the tick.
const WorkflowActor qaExecutorActor = WorkflowActor(
  actorId: 'qa-executor',
  actorType: ActorType.qaExecutor,
);

/// The decision type a failed QA raises.
///
/// ## WHY `qaWaiver` AND NOT `qaRework`
///
/// The design admits either (`evaluator-spec.md` §4.2, step 5: "the blocking
/// `qaRework`/`qaWaiver` decision"). `qaWaiver` is the one whose `waive` arm
/// the transition table routes to `qaPassed`
/// (`work_item_transitions.dart:807-813`), and that arm is the only way a
/// failed QA can become a passed one: without a waiver decision there is
/// nothing for a human to resolve, and the item stays at `qaFailed` — where
/// `qaFailed` has exactly ONE edge out, and that edge is the one this
/// decision opens. `qaRework`'s arms reach `designInReview` and
/// `implementationReady`; neither of them is "the human accepted this
/// failure", and no other part of the platform raises either type, so
/// choosing `qaRework` here would leave the
/// `waitingForHumanDecision -> qaPassed` edge without a caller.
const HumanDecisionType qaFailureDecisionType = HumanDecisionType.qaWaiver;

/// What one QA drain pass concluded, for the composition root to report.
class QADrainResult {
  const QADrainResult({
    required this.considered,
    required this.passed,
    required this.failed,
    required this.faulted,
    required this.skipped,
    required this.outcomes,
  });

  /// Items the pass looked at.
  final int considered;

  /// Items whose contract passed and which are now at `qaPassed`.
  final int passed;

  /// Items whose contract was evaluated and did not pass. Each is left at
  /// `qaFailed` with a blocking human decision raised against it, which is
  /// what moves it to `waitingForHumanDecision`.
  final int failed;

  /// Items whose evaluation could not be completed, now at `qaFailed` with a
  /// record that says so, and with the same blocking human decision raised
  /// against it.
  final int faulted;

  /// Items the pass did not move, and why.
  final int skipped;

  /// One entry per item, in the order the pass handled them.
  final List<QADrainItemOutcome> outcomes;

  /// Whether the pass moved anything at all.
  bool get movedAnything => passed + failed + faulted > 0;

  /// Items the pass left waiting for a human.
  int get awaitingHuman =>
      outcomes.where((outcome) => outcome.raisedDecisionId != null).length;
}

/// What the drain did with one work item.
class QADrainItemOutcome {
  const QADrainItemOutcome({
    required this.workItemId,
    required this.qaContractId,
    required this.outcomeKind,
    required this.toState,
    required this.detail,
    this.raisedDecisionId,
    this.raisedDecisionType,
  });

  final String workItemId;
  final String? qaContractId;

  /// `pass`, `not_pass`, `fault` or `skipped`.
  ///
  /// The three that are not `skipped` are the same distinction the durable
  /// record carries: a **verdict** (`pass` / `not_pass`) says what the gates
  /// found, and a **fault** says the evaluation did not happen.
  final String outcomeKind;

  /// The state the item was left in, or `null` when it was not moved.
  final WorkItemState? toState;

  /// One sentence, safe to log.
  final String detail;

  /// The id of the blocking human decision the drain raised, when it raised
  /// one.
  ///
  /// A failure with no decision is a STRAND: `qaFailed` has exactly one edge
  /// out, and that edge requires a pending decision of an allowed type. So
  /// this is null only when the raise itself was refused, which the drain
  /// reports as a fault of its own.
  final String? raisedDecisionId;

  /// The type of the raised decision, when one was raised.
  final HumanDecisionType? raisedDecisionType;
}

/// The QA drain: the one thing that moves a reviewed work item through its QA
/// contract.
///
/// ## WHAT IT IS FOR
///
/// An item that a human approved reaches `reviewApproved` and stopped there.
/// The edge out of it — `reviewApproved -> qaInProgress` — existed, was
/// guarded, and had **no caller**: nothing in the platform took an item
/// through it, so the ten reviews waiting for a human decision in QA were
/// waiting for a decision that would be followed by silence. This function is
/// that caller.
///
/// ## WHAT IT DOES NOT DO
///
/// * It does not decide the item's fate. It evaluates the contract, and the
///   contract's own verdicts decide the state.
/// * It does not answer for the human. A failure raises a blocking decision
///   and stops; what the human answers is the human's, and the drain never
///   resolves a decision it raised.
/// * It does not retry. Every item it cannot move is reported and left where
///   it was.
///
/// ## WHY A FAILURE RAISES A DECISION
///
/// The design requires it (`evaluator-spec.md` §4.2, step 5) and the
/// transition table requires it too: `qaFailed` has exactly ONE edge out —
/// `qaFailed -> waitingForHumanDecision` — and that edge's guard demands a
/// pending blocking decision of type `qaWaiver` or `qaRework`. An item left
/// at `qaFailed` with no decision is therefore not "waiting for review": it
/// is unmovable, and the platform has no way to say so to anybody. The drain
/// raises the decision, and the human decides.
///
/// The decision is raised for a FAULT as well as for a failing verdict. A
/// fault means the gates never spoke, which is a stronger reason to ask a
/// person than a failing gate is — but the truth of it is in the question and
/// in the durable record, not in the state name.
///
/// ## WHY A FAULT IS `qaFailed` AND NOT A SILENCE
///
/// An evaluation that could not be completed is not a passing contract and it
/// is not a failing one. Recording it as either would be a lie: a fault means
/// the platform could not look. But leaving the item at `qaInProgress`
/// forever would be a strand — the item would sit in a state no one reads,
/// and the reason would be nowhere but in a log line.
///
/// So the fault is recorded as `qaFailed` with a reason that says the
/// evaluation could not be completed, and the durable record's `outcomeKind`
/// is `fault` rather than `not_pass`. The state is the same; the record is
/// not, and the record is what a later reader has.
Future<QADrainResult> runQADrain({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required QAGateEvaluationService evaluationService,
  required ProducerResolver producerResolver,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final List<WorkItem> items;
  try {
    items = await workflowStore.readAllWorkItems();
  } catch (error, stack) {
    log?.call('qa.drain.read_failed', {
      'error': '$error',
      'stack': stack.toString(),
      'action':
          'the QA drain read no work items, so nothing was evaluated; the next '
          'tick retries and the other lanes are unaffected',
    });
    return const QADrainResult(
      considered: 0,
      passed: 0,
      failed: 0,
      faulted: 0,
      skipped: 0,
      outcomes: [],
    );
  }

  // `reviewApproved` is the entry: a reviewed item the human approved.
  // `qaInProgress` is the RESUME: an item this drain started and did not
  // finish — the process died between the two transitions — is picked up
  // again rather than stranded. Nothing else moves an item into
  // `qaInProgress`; the only edge into that state is the one this drain
  // takes.
  final candidates = items
      .where(
        (item) =>
            item.state == WorkItemState.reviewApproved ||
            item.state == WorkItemState.qaInProgress,
      )
      .toList();

  final outcomes = <QADrainItemOutcome>[];
  var passed = 0;
  var failed = 0;
  var faulted = 0;
  var skipped = 0;

  for (final candidate in candidates) {
    final contractId = candidate.qaContractId;
    if (contractId == null || contractId.trim().isEmpty) {
      skipped++;
      outcomes.add(
        QADrainItemOutcome(
          workItemId: candidate.workItemId,
          qaContractId: candidate.qaContractId,
          outcomeKind: 'skipped',
          toState: null,
          detail:
              'the work item records no QA contract id, so there is no '
              'contract to evaluate and nothing was moved',
        ),
      );
      continue;
    }

    // 1. TAKE THE ITEM.
    //
    // The state change is the claim: once the item is at `qaInProgress` the
    // next tick will not pick it up as a new candidate, so two ticks cannot
    // evaluate the same item twice. The idempotency key makes the claim
    // itself safe to repeat.
    final WorkItem inProgress;
    try {
      inProgress = await _enterQaInProgress(
        workflowEngine: workflowEngine,
        item: candidate,
        contractId: contractId,
      );
    } on WorkflowTransitionRejectedException catch (error) {
      skipped++;
      outcomes.add(
        QADrainItemOutcome(
          workItemId: candidate.workItemId,
          qaContractId: contractId,
          outcomeKind: 'skipped',
          toState: null,
          detail:
              'the work item could not be taken for QA evaluation '
              '(${error.record.reason ?? error.record.outcome.wire}); '
              'it was not moved',
        ),
      );
      log?.call('qa.drain.item.skipped', {
        'workItemId': candidate.workItemId,
        'qaContractId': contractId,
        'reason': error.record.reason ?? error.record.outcome.wire,
      });
      continue;
    }

    // 2. THE PRODUCER'S RESULT.
    //
    // The gates judge the agent's own output — the structured result, the
    // changed files — so the evaluation needs the result the producing
    // execution left. Resolving it through the platform's own rule
    // (`resolveProducerExecution`) rather than "the newest result" is what
    // keeps the QA lane from reviewing a reviewer's result.
    final producer = await producerResolver.resolveFor(inProgress);
    final result = producer?.result;
    if (result == null) {
      faulted++;
      final detail =
          'the execution that produced this work item could not be identified '
          'or left no result, so there was nothing to evaluate';
      await _recordFault(
        workflowEngine: workflowEngine,
        workItemId: inProgress.workItemId,
        contractId: contractId,
        reason: detail,
        cause: producer?.note,
        log: log,
      );
      final decision = await _raiseQaFailureDecision(
        workflowEngine: workflowEngine,
        workItemId: inProgress.workItemId,
        contractId: contractId,
        outcomeKind: 'fault',
        question:
            'The QA contract $contractId could not be evaluated: $detail No '
            'gate result exists for it, so nothing has verified this work '
            'item.',
        log: log,
      );
      outcomes.add(
        QADrainItemOutcome(
          workItemId: inProgress.workItemId,
          qaContractId: contractId,
          outcomeKind: 'fault',
          toState: decision == null
              ? WorkItemState.qaFailed
              : WorkItemState.waitingForHumanDecision,
          detail: decision == null
              ? '$detail; the blocking human decision could not be raised, so '
                    'the item is left at qa_failed, where it cannot move'
              : '$detail; a blocking ${decision.decisionType.wire} decision '
                    'was raised and the item is waiting for a human',
          raisedDecisionId: decision?.decisionId,
          raisedDecisionType: decision?.decisionType,
        ),
      );
      continue;
    }

    // 3. THE EVALUATION.
    //
    // The service owns the contract read, the orchestration, and the fault
    // that a refusal of a gate's own declaration becomes. The shipped F2
    // declaration carries an empty `ownedPathGlobs` and is refused by design;
    // that refusal arrives here as a FAULT, not as a failing gate.
    final QAGateEvaluationOutcome outcome;
    try {
      outcome = await evaluationService.evaluateForWorkItem(
        workItemId: inProgress.workItemId,
        qaContractId: contractId,
        agentResult: result,
      );
    } on QAGateEvaluationFault catch (fault) {
      faulted++;
      await _recordFault(
        workflowEngine: workflowEngine,
        workItemId: inProgress.workItemId,
        contractId: contractId,
        reason: fault.reason,
        cause: fault.cause?.toString(),
        log: log,
      );
      final decision = await _raiseQaFailureDecision(
        workflowEngine: workflowEngine,
        workItemId: inProgress.workItemId,
        contractId: contractId,
        outcomeKind: 'fault',
        question:
            'The QA contract $contractId could not be evaluated: ${fault.reason} '
            'No gate result exists for it, so nothing has verified this work '
            'item.',
        log: log,
      );
      outcomes.add(
        QADrainItemOutcome(
          workItemId: inProgress.workItemId,
          qaContractId: contractId,
          outcomeKind: 'fault',
          toState: decision == null
              ? WorkItemState.qaFailed
              : WorkItemState.waitingForHumanDecision,
          detail: decision == null
              ? '${fault.reason}; the blocking human decision could not be '
                    'raised, so the item is left at qa_failed, where it cannot '
                    'move'
              : '${fault.reason}; a blocking ${decision.decisionType.wire} '
                    'decision was raised and the item is waiting for a human',
          raisedDecisionId: decision?.decisionId,
          raisedDecisionType: decision?.decisionType,
        ),
      );
      log?.call('qa.drain.item.faulted', {
        'workItemId': inProgress.workItemId,
        'qaContractId': contractId,
        'reason': fault.reason,
        'cause': fault.cause?.toString(),
        'raisedDecisionId': decision?.decisionId,
      });
      continue;
    }

    // 4. THE SETTLEMENT.
    //
    // `isOverallPass` is the orchestration's own determination, and the
    // `qaPassed` edge's guard applies the same required-gate rule, so the
    // two agree by construction rather than by parallel maintenance.
    //
    // The actor is the design's: a pass is settled as the QA executor, a
    // failure as the orchestrator (`evaluator-spec.md` §4.2, step 4).
    final target = outcome.isOverallPass
        ? WorkItemState.qaPassed
        : WorkItemState.qaFailed;
    final settlementActor = outcome.isOverallPass
        ? qaExecutorActor
        : qaDrainActor;
    try {
      await workflowEngine.transition(
        workItemId: inProgress.workItemId,
        to: target,
        trigger: TransitionTrigger.systemEvent,
        actor: settlementActor,
        // The guard's working material: the live objects, not their JSON.
        context: outcome.toTransitionContext(),
        // The durable record. The transition context is read, evaluated and
        // discarded; a record that lives only in the arguments of a
        // transition is not a record.
        metadataMerge: {'qaEvaluation': outcome.toDurableRecord()},
        reason: outcome.isOverallPass
            ? 'every required gate in the QA contract passed'
            : 'the QA contract was evaluated and its required gates did not '
                  'all pass',
        idempotencyKey: 'qa-drain:${inProgress.workItemId}:settle',
      );
    } on WorkflowTransitionRejectedException catch (error) {
      // The evaluation happened, but the item could not be settled. That is a
      // fault: the platform looked, and could not record where the item
      // ended up. The item stays at `qaInProgress` and the next tick resumes
      // it.
      faulted++;
      outcomes.add(
        QADrainItemOutcome(
          workItemId: inProgress.workItemId,
          qaContractId: contractId,
          outcomeKind: 'fault',
          toState: null,
          detail:
              'the QA evaluation completed but the item could not be settled '
              '(${error.record.reason ?? error.record.outcome.wire})',
        ),
      );
      log?.call('qa.drain.item.settlement_refused', {
        'workItemId': inProgress.workItemId,
        'qaContractId': contractId,
        'target': target.wire,
        'reason': error.record.reason ?? error.record.outcome.wire,
        'action':
            'the item is left at qa_in_progress and the next tick evaluates it '
            'again',
      });
      continue;
    }

    if (outcome.isOverallPass) {
      passed++;
      outcomes.add(
        QADrainItemOutcome(
          workItemId: inProgress.workItemId,
          qaContractId: contractId,
          outcomeKind: 'pass',
          toState: target,
          detail: 'every required gate in the QA contract passed',
        ),
      );
    } else {
      failed++;
      // 5. THE HUMAN.
      //
      // The item is at `qaFailed`, and `qaFailed` has one edge out, which
      // requires a pending blocking decision. So a failure that raises no
      // decision is an item nothing can move again. The question carries the
      // truth of the arm it came from: a failing verdict says the gates
      // spoke and said no; a fault says the gates never spoke at all.
      final decision = await _raiseQaFailureDecision(
        workflowEngine: workflowEngine,
        workItemId: inProgress.workItemId,
        contractId: contractId,
        outcomeKind: 'not_pass',
        question:
            'The QA contract $contractId was evaluated and its required gates '
            'did not all pass. The required gates that did not pass: '
            '${outcome.requiresFormalDetermination.join(', ')}.',
        log: log,
      );
      outcomes.add(
        QADrainItemOutcome(
          workItemId: inProgress.workItemId,
          qaContractId: contractId,
          outcomeKind: 'not_pass',
          toState: decision == null
              ? WorkItemState.qaFailed
              : WorkItemState.waitingForHumanDecision,
          detail: decision == null
              ? 'the QA contract was evaluated and its required gates did not '
                    'all pass; the blocking human decision could not be '
                    'raised, so the item is left at qa_failed, where it cannot '
                    'move'
              : 'the QA contract was evaluated and its required gates did not '
                    'all pass; a blocking ${decision.decisionType.wire} '
                    'decision was raised and the item is waiting for a human',
          raisedDecisionId: decision?.decisionId,
          raisedDecisionType: decision?.decisionType,
        ),
      );
    }
    log?.call('qa.drain.item.settled', {
      'workItemId': inProgress.workItemId,
      'qaContractId': contractId,
      'outcomeKind': outcome.isOverallPass ? 'pass' : 'not_pass',
      'toState': target.wire,
      'requiresFormalDetermination': outcome.requiresFormalDetermination,
    });
  }

  return QADrainResult(
    considered: candidates.length,
    passed: passed,
    failed: failed,
    faulted: faulted,
    skipped: skipped,
    outcomes: outcomes,
  );
}

/// Moves the item into `qaInProgress`, or returns it if it is already there.
///
/// The idempotency key makes a repeated claim a no-op rather than a
/// rejection: the engine returns the work item unchanged when a prior
/// transition with the same key was accepted.
Future<WorkItem> _enterQaInProgress({
  required DurableWorkflowEngine workflowEngine,
  required WorkItem item,
  required String contractId,
}) async {
  if (item.state == WorkItemState.qaInProgress) return item;
  return workflowEngine.transition(
    workItemId: item.workItemId,
    to: WorkItemState.qaInProgress,
    trigger: TransitionTrigger.systemEvent,
    actor: qaDrainActor,
    // The guard reads this key and only checks that it is present. The
    // contract it names is the one the evaluation reads next.
    context: {'qaContractId': contractId},
    reason: 'the QA lane took this work item for evaluation',
    idempotencyKey: 'qa-drain:${item.workItemId}:enter',
  );
}

/// Raises the blocking human decision a failed QA needs.
///
/// ## WHY IT IS RAISED HERE AND NOT LEFT TO SOMEBODY ELSE
///
/// `qaFailed` has exactly one edge out — `qaFailed ->
/// waitingForHumanDecision` — and that edge's guard requires a pending
/// blocking decision of type `qaWaiver` or `qaRework`. Nothing else in the
/// platform raises either type today, so if the drain does not raise one, the
/// item is at a state from which nothing can move it: a strand that looks
/// like a verdict and is not one.
///
/// The engine persists the decision BEFORE it takes the gate edge
/// (`durable_workflow_engine.dart:626`), so the guard that demands the
/// decision sees a decision that already exists. A repeated call finds the
/// pending decision the engine already has and returns it, so a retried
/// drain does not raise a second one.
///
/// The drain never RESOLVES the decision it raises. The answer is the
/// human's, and the platform's part is to ask the question honestly.
Future<HumanDecision?> _raiseQaFailureDecision({
  required DurableWorkflowEngine workflowEngine,
  required String workItemId,
  required String contractId,
  required String outcomeKind,
  required String question,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  try {
    final decision = await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: qaFailureDecisionType,
      question: question,
      options: const [
        HumanDecisionOption(
          optionId: 'waive',
          label: 'Accept this result and let the work item pass QA',
          description:
              'You are accepting a QA contract that did not pass. The QA '
              'record on the work item keeps saying so.',
        ),
        HumanDecisionOption(
          optionId: 'reject',
          label: 'Send it back to be implemented again',
          description:
              'The work item returns to implementation, and its QA contract is '
              'evaluated again when it comes back.',
        ),
      ],
      // The platform's own recommendation is to fix the work, not to accept
      // a failure: a recommendation is advice, and the advice here is that a
      // failed contract is a reason to do more work.
      recommendation: 'REJECT',
      blocking: true,
      metadata: {
        'qaContractId': contractId,
        'outcomeKind': outcomeKind,
        'raisedBy': 'qa-drain',
      },
      // The escalation edge admits the orchestrator only.
      actor: qaDrainActor,
    );
    log?.call('qa.drain.decision_raised', {
      'workItemId': workItemId,
      'qaContractId': contractId,
      'outcomeKind': outcomeKind,
      'decisionId': decision.decisionId,
      'decisionType': decision.decisionType.wire,
    });
    return decision;
  } on WorkflowTransitionRejectedException catch (error) {
    // The decision could not be raised. The item stays at `qaFailed`, where
    // it cannot move, and the reason is here — reported, not swallowed.
    log?.call('qa.drain.decision_refused', {
      'workItemId': workItemId,
      'qaContractId': contractId,
      'outcomeKind': outcomeKind,
      'reason': error.record.reason ?? error.record.outcome.wire,
      'action':
          'the item is left at qa_failed with no decision raised, and '
          'qa_failed has no other edge out: it cannot move again until '
          'somebody raises the decision by hand',
    });
    return null;
  }
}

/// Records a fault as `qaFailed`, with a record that says the evaluation could
/// not be completed.
Future<void> _recordFault({
  required DurableWorkflowEngine workflowEngine,
  required String workItemId,
  required String contractId,
  required String reason,
  String? cause,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  try {
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.qaFailed,
      trigger: TransitionTrigger.systemEvent,
      actor: qaDrainActor,
      reason: reason,
      metadataMerge: {
        'qaEvaluation': {
          'outcomeKind': 'fault',
          'qaContractId': contractId,
          'evaluatedAt': DateTime.now().toUtc().toIso8601String(),
          'reason': reason,
          if (cause != null) 'cause': cause,
        },
      },
      idempotencyKey: 'qa-drain:$workItemId:fault',
    );
  } on WorkflowTransitionRejectedException catch (error) {
    log?.call('qa.drain.fault_not_recorded', {
      'workItemId': workItemId,
      'qaContractId': contractId,
      'reason': error.record.reason ?? error.record.outcome.wire,
      'action':
          'the fault could not be recorded on the work item; the item keeps '
          'whatever state it had and the reason is in this line',
    });
  }
}
