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

/// Metadata key: the drain's per-attempt discriminator.
///
/// ## WHY IT EXISTS — F-245
///
/// The drain's transition idempotency keys used to be scoped to the work item
/// forever: `qa-drain:<id>:enter`, `qa-drain:<id>:settle`,
/// `qa-drain:<id>:fault`. That is correct exactly once. `reviewApproved` is a
/// state an item can legitimately RE-ENTER — a rejected waiver, a rework, a
/// re-implementation and a fresh approval all route it back through the
/// drain's entry state — and on the second traversal
/// `findTransitionByIdempotencyKey` answered the TAKE with the prior accepted
/// `enter` record, so `_enterQaInProgress` returned the item unchanged, still
/// at `reviewApproved`. Everything after — the fault record, the settlement
/// and the decision raise — was then evaluated from `reviewApproved`, a state
/// with edges only to `qaInProgress`, and refused: the item sat
/// `review_approved` while the drain logged `qa.drain.decision_refused`
/// (`reviewApproved -> waitingForHumanDecision`) every tick, forever.
///
/// The counter scopes the keys to the ATTEMPT: attempt 1's take is
/// `qa-drain:<id>:enter:a1`, attempt 2's is `qa-drain:<id>:enter:a2`, so a
/// re-entered item is really taken again while a retried attempt still
/// replays. The take transition stamps the number on the work item in the
/// same write as the state change, so an item the drain is holding always
/// carries which attempt it is on, and a crash-resumed `qaInProgress` item
/// re-derives the same keys.
///
/// It is ONE monotone counter and it only ever goes up: a value that cannot
/// be parsed is a defect in whatever wrote it, not a number to fall back on,
/// because falling back re-consumes a key an earlier attempt already holds —
/// the very defect this field exists to close. See [readQaAttempt].
const String qaAttemptMetadataKey = 'qaAttempt';

/// The QA attempt [item] is carrying, or `null` when it has never been taken
/// by this drain.
///
/// ## THE ONE RULE
///
/// Mirrors `DurableWorkflowEngine.readTriageAttempt`: the forms accepted are
/// every shape the marker legitimately takes through JSON — an `int`, a
/// whole-valued `double`, a numeric `String` — and anything else is a
/// [FormatException], never a fallback. A fallback would silently reuse a key
/// a previous attempt already consumed, which is the defect class this marker
/// exists to close.
int? readQaAttempt(WorkItem item) {
  final marker =
      (item.metadata ?? const <String, dynamic>{})[qaAttemptMetadataKey];
  if (marker == null) return null;
  return switch (marker) {
    final int value => value,
    final double value when value.isFinite && value == value.roundToDouble() =>
      value.toInt(),
    final String value when int.tryParse(value) != null => int.parse(value),
    _ => throw FormatException(
      'Unreadable $qaAttemptMetadataKey on work item ${item.workItemId}: '
      'expected an int, a whole-valued double or a numeric String, got '
      '${marker.runtimeType} ($marker). Falling back to attempt 1 would '
      'reuse idempotency keys an earlier QA attempt already consumed.',
    ),
  };
}

/// What one QA drain pass concluded, for the composition root to report.
class QADrainResult {
  const QADrainResult({
    required this.considered,
    required this.passed,
    required this.failed,
    required this.faulted,
    required this.skipped,
    required this.outcomes,
    this.escalated = 0,
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

  /// Items found at `qaFailed` with no way out that the pass moved to the
  /// human gate.
  ///
  /// A `qaFailed` item needs a pending blocking decision to leave its state;
  /// one without it is a strand — possible when the process died between the
  /// settlement commit and the decision raise, or when tooling placed the
  /// item there. This is deliberately separate from [failed]: these items
  /// were not evaluated this pass; their already-recorded failure was
  /// completed with the decision it needed.
  final int escalated;

  /// One entry per item, in the order the pass handled them.
  final List<QADrainItemOutcome> outcomes;

  /// Whether the pass moved anything at all.
  bool get movedAnything => passed + failed + faulted + escalated > 0;

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

  /// `pass`, `not_pass`, `fault`, `escalated` or `skipped`.
  ///
  /// Three of them are the same distinction the durable record carries: a
  /// **verdict** (`pass` / `not_pass`) says what the gates found, and a
  /// **fault** says the evaluation did not happen. `escalated` is neither: it
  /// marks an item found at `qaFailed` — the failure was already recorded —
  /// whose missing blocking decision this pass supplied.
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
///
/// ## WHY `qaFailed` IS A CANDIDATE — THE STRAND THE DRAIN CAN LEAVE
///
/// The settlement and the decision raise are two separate writes. A process
/// that dies between them leaves the item at `qaFailed` with the failure
/// recorded but no pending decision — and `qaFailed` has exactly one edge
/// out, which requires one. That item is not evaluated again (the evaluation
/// already ran; its record stands); it is ESCALATED: the drain supplies the
/// missing decision and moves it to the human gate, deliberately rather than
/// silently. An item found at `qaFailed` WITH a pending decision of an
/// admitted type is moved through the same edge against that decision —
/// nothing is re-minted.
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
  // takes. `qaFailed` is the OTHER strand this drain can leave: the failure
  // was recorded but the process died before the blocking decision was
  // raised. It is not re-evaluated — the record stands; it is completed with
  // the decision it is missing.
  final candidates = items
      .where(
        (item) =>
            item.state == WorkItemState.reviewApproved ||
            item.state == WorkItemState.qaInProgress ||
            item.state == WorkItemState.qaFailed,
      )
      .toList();

  final outcomes = <QADrainItemOutcome>[];
  var passed = 0;
  var failed = 0;
  var faulted = 0;
  var skipped = 0;
  var escalated = 0;

  for (final candidate in candidates) {
    // An item already recorded as failed needs the human it never got, not a
    // second evaluation. Handled BEFORE the contract check: a stranded item
    // must not be stranded further for want of a column it no longer needs.
    if (candidate.state == WorkItemState.qaFailed) {
      final outcome = await _completeRecordedFailure(
        workflowEngine: workflowEngine,
        workflowStore: workflowStore,
        item: candidate,
        log: log,
      );
      if (outcome.raisedDecisionId != null ||
          outcome.toState == WorkItemState.waitingForHumanDecision) {
        escalated++;
      } else {
        skipped++;
      }
      outcomes.add(outcome);
      continue;
    }

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

    // The attempt this pass is on. An item at `reviewApproved` is STARTING a
    // new attempt — possibly a second one, after a rework loop brought it
    // back — so the number is the carried marker plus one. An item at
    // `qaInProgress` is RESUMING the attempt its take stamped; `?? 1` covers
    // the pre-counter item taken under the old unscoped keys, whose new keys
    // are still fresh because the suffix was not part of them.
    //
    // A marker that is present but unreadable is a defect in whatever wrote
    // it: it is reported and the item is skipped, deliberately — the same
    // `FormatException` rule `readTriageAttempt` applies, contained to the
    // one item rather than thrown through the whole pass.
    final int attempt;
    try {
      attempt = candidate.state == WorkItemState.qaInProgress
          ? (readQaAttempt(candidate) ?? 1)
          : (readQaAttempt(candidate) ?? 0) + 1;
    } on FormatException catch (error) {
      skipped++;
      outcomes.add(
        QADrainItemOutcome(
          workItemId: candidate.workItemId,
          qaContractId: contractId,
          outcomeKind: 'skipped',
          toState: null,
          detail:
              'the work item carries an unreadable qaAttempt marker '
              '($error), so its QA attempt cannot be keyed safely; it was '
              'not moved',
        ),
      );
      log?.call('qa.drain.item.skipped', {
        'workItemId': candidate.workItemId,
        'qaContractId': contractId,
        'reason': '$error',
      });
      continue;
    }

    // 1. TAKE THE ITEM.
    //
    // The state change is the claim: once the item is at `qaInProgress` the
    // next tick will not pick it up as a new candidate, so two ticks cannot
    // evaluate the same item twice. The idempotency key — scoped to THIS
    // attempt — makes the claim itself safe to repeat.
    final WorkItem inProgress;
    try {
      inProgress = await _enterQaInProgress(
        workflowEngine: workflowEngine,
        item: candidate,
        contractId: contractId,
        attempt: attempt,
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
        attempt: attempt,
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
        attempt: attempt,
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
        // transition is not a record. The attempt stamp is merged alongside
        // it so an item resumed at `qaInProgress` under the pre-counter keys
        // still ends up carrying which attempt settled it.
        metadataMerge: {
          'qaEvaluation': outcome.toDurableRecord(),
          qaAttemptMetadataKey: attempt,
        },
        reason: outcome.isOverallPass
            ? 'every required gate in the QA contract passed'
            : 'the QA contract was evaluated and its required gates did not '
                  'all pass',
        idempotencyKey: 'qa-drain:${inProgress.workItemId}:settle:a$attempt',
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
    escalated: escalated,
    outcomes: outcomes,
  );
}

/// Completes the escalation of an item already recorded at `qaFailed`.
///
/// ## WHAT THIS IS FOR
///
/// `qaFailed` has exactly one edge out, and it requires a pending blocking
/// decision of type `qaWaiver` or `qaRework`. A `qaFailed` item with no
/// pending decision of either type is therefore a strand — reachable when
/// the process died between the settlement commit and the decision raise —
/// and this arm is what keeps the strand from being silent: the drain
/// supplies the decision the state needs, in one of two ways.
///
/// If a pending blocking decision of an admitted type already exists on the
/// item — the only way that can happen is tooling or a partial outside
/// write, since the engine persists and gates a decision atomically — the
/// edge is taken against THAT decision rather than minting a second one.
/// Otherwise the ordinary `_raiseQaFailureDecision` raises the `qaWaiver`
/// and enters the gate in the same call, exactly as it does for a fresh
/// failure.
///
/// The evaluation is NOT re-run: the item's `qaEvaluation` record already
/// carries what the gates said. Re-evaluating a settled item would record a
/// second verdict for the same one.
Future<QADrainItemOutcome> _completeRecordedFailure({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required WorkItem item,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final contractId = item.qaContractId;

  final List<HumanDecision> decisions;
  try {
    decisions = await workflowStore.readHumanDecisionsForWorkItem(
      item.workItemId,
    );
  } catch (error, stack) {
    log?.call('qa.drain.decision_lookup_failed', {
      'workItemId': item.workItemId,
      'qaContractId': contractId,
      'error': '$error',
      'stack': stack.toString(),
      'action':
          'the item is left at qa_failed and the next tick retries; an '
          'unreadable decision list is not a reason to mint a second one',
    });
    return QADrainItemOutcome(
      workItemId: item.workItemId,
      qaContractId: contractId,
      outcomeKind: 'skipped',
      toState: null,
      detail:
          'the work item is at qa_failed, but its human decisions could not '
          'be read ($error), so whether it already awaits a decision could '
          'not be established; it was not moved',
    );
  }

  HumanDecision? pending;
  for (final decision in decisions) {
    if (!decision.status.isResolved &&
        decision.blocking != false &&
        (decision.decisionType == HumanDecisionType.qaWaiver ||
            decision.decisionType == HumanDecisionType.qaRework)) {
      pending = decision;
      break;
    }
  }

  if (pending != null) {
    // The gate edge's guard reads `context['humanDecision']` and requires a
    // pending blocking decision of an admitted type — the existing one
    // satisfies it, so the item is moved onto the decision it already has.
    try {
      await workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        actor: qaDrainActor,
        decisionId: pending.decisionId,
        context: {
          'humanDecision': pending,
          'blockingReason': pending.question ?? 'Awaiting human decision',
        },
        reason:
            'the recorded QA failure already had a pending blocking '
            'decision; the item is moved to the human gate that decision '
            'opens',
      );
    } on WorkflowTransitionRejectedException catch (error) {
      log?.call('qa.drain.decision_refused', {
        'workItemId': item.workItemId,
        'qaContractId': contractId,
        'outcomeKind': 'escalated',
        'reason': error.record.reason ?? error.record.outcome.wire,
        'action':
            'the item is left at qa_failed with a pending decision it could '
            'not be gated onto; the next tick tries again',
      });
      return QADrainItemOutcome(
        workItemId: item.workItemId,
        qaContractId: contractId,
        outcomeKind: 'skipped',
        toState: null,
        detail:
            'the work item is at qa_failed with a pending '
            '${pending.decisionType.wire} decision, but the human-gate edge '
            'refused it (${error.record.reason ?? error.record.outcome.wire}); '
            'it was not moved',
      );
    }
    log?.call('qa.drain.item.escalated', {
      'workItemId': item.workItemId,
      'qaContractId': contractId,
      'decisionId': pending.decisionId,
      'reused': true,
    });
    return QADrainItemOutcome(
      workItemId: item.workItemId,
      qaContractId: contractId,
      outcomeKind: 'escalated',
      toState: WorkItemState.waitingForHumanDecision,
      detail:
          'the recorded QA failure already had a pending '
          '${pending.decisionType.wire} decision; the item was moved to the '
          'human gate it opens',
      raisedDecisionId: pending.decisionId,
      raisedDecisionType: pending.decisionType,
    );
  }

  final recordedKind = (item.metadata?['qaEvaluation'] as Map?)?['outcomeKind'];
  final decision = await _raiseQaFailureDecision(
    workflowEngine: workflowEngine,
    workItemId: item.workItemId,
    contractId: contractId,
    outcomeKind: recordedKind is String && recordedKind.isNotEmpty
        ? recordedKind
        : 'unknown',
    question:
        'The QA contract ${contractId ?? 'recorded for this work item'} was '
        'evaluated and the work item was left at qa_failed with no blocking '
        'decision raised against it — a state it cannot leave without one. '
        'The decision a failed QA needs is raised now.',
    log: log,
  );
  if (decision == null) {
    return QADrainItemOutcome(
      workItemId: item.workItemId,
      qaContractId: contractId,
      outcomeKind: 'skipped',
      toState: null,
      detail:
          'the work item is at qa_failed with no pending blocking decision, '
          'and the blocking human decision could not be raised; it was not '
          'moved',
    );
  }
  log?.call('qa.drain.item.escalated', {
    'workItemId': item.workItemId,
    'qaContractId': contractId,
    'decisionId': decision.decisionId,
    'reused': false,
  });
  return QADrainItemOutcome(
    workItemId: item.workItemId,
    qaContractId: contractId,
    outcomeKind: 'escalated',
    toState: WorkItemState.waitingForHumanDecision,
    detail:
        'the work item was found at qa_failed with no pending blocking '
        'decision; a blocking ${decision.decisionType.wire} decision was '
        'raised and the item is waiting for a human',
    raisedDecisionId: decision.decisionId,
    raisedDecisionType: decision.decisionType,
  );
}

/// Moves the item into `qaInProgress`, or returns it if it is already there.
///
/// The idempotency key — scoped to the QA attempt, never to the item —
/// makes a repeated claim WITHIN one attempt a no-op rather than a
/// rejection: the engine returns the work item unchanged when a prior
/// transition with the same key was accepted. An item that comes back to
/// `reviewApproved` after a rework loop is on a NEW attempt and gets a new
/// key, so it is genuinely taken again instead of replaying the previous
/// traversal's take — which is the defect F-245 recorded.
Future<WorkItem> _enterQaInProgress({
  required DurableWorkflowEngine workflowEngine,
  required WorkItem item,
  required String contractId,
  required int attempt,
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
    // The attempt number travels with the claim itself, so an item this
    // drain is holding always carries which attempt it is on and a
    // crash-resumed pass re-derives the same keys.
    metadataMerge: {qaAttemptMetadataKey: attempt},
    reason: 'the QA lane took this work item for evaluation',
    idempotencyKey: 'qa-drain:${item.workItemId}:enter:a$attempt',
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
  required String? contractId,
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
  required int attempt,
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
        // Same stamp as the settlement path: an item that traversed the
        // drain carries which attempt did it, wherever the take was made.
        qaAttemptMetadataKey: attempt,
      },
      idempotencyKey: 'qa-drain:$workItemId:fault:a$attempt',
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
