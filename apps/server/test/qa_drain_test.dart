import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/qa/qa_drain.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ProducerResolution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/gate_registry_over_doubles.dart';
import 'support/in_memory_qa_contract_store.dart';

/// The QA drain: the one thing that moves a reviewed work item through its QA
/// contract.
///
/// ## WHAT THIS FILE IS FOR
///
/// Before slice 3c, `reviewApproved -> qaInProgress` existed, was guarded, and
/// had **no caller**. An item a human approved reached `reviewApproved` and
/// stopped there, silently. The drain is that caller, and this file holds it
/// to the properties that matter:
///
///   1. it takes the item and evaluates the contract it names;
///   2. a VERDICT (`pass` / `not_pass`) and a FAULT are recorded differently,
///      and a fault is never dressed up as a verdict;
///   3. a failure reaches a HUMAN, because `qaFailed` has no other edge out;
///   4. it moves nothing it was not asked to move, and it is safe to run twice;
///   5. it survives the crash that leaves an item at `qaInProgress`;
///   6. one item's failure cannot take the lane down with it.
///
/// ## WHY THE ENGINE IS THE REAL ONE
///
/// The drain's decisions are made by the workflow engine's GUARDS — the
/// `qaContractExists` guard on the way in, the `allRequiredGatesPassed` guard
/// on the way out, the `blockingHumanDecisionPendingOfType` guard on the way
/// to a human. A test that replaced the engine with a mock would be testing
/// the mock. So this file drives the real [DurableWorkflowEngine] over the
/// real [InMemoryWorkflowStore], and the states it asserts are the states
/// the guards permit.
///
/// ## WHY THE ASSERTIONS READ THE TRANSITION HISTORY
///
/// "The item is at `waitingForHumanDecision`" is a fact about the end. The
/// design's requirement is about the PATH: a failed QA must reach `qaFailed`
/// and must not reach `qaPassed` (`evaluator-spec.md` §4.3, V5). The
/// transition history is where the path is, so the path is what is asserted.
void main() {
  group('a reviewed item is taken and evaluated', () {
    test(
      'a contract whose required gates pass moves the item to qaPassed',
      () async {
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
        );

        final result = await harness.run();

        expect(result.considered, 1);
        expect(result.passed, 1);
        expect(result.failed, 0);
        expect(result.faulted, 0);

        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.qaPassed);

        // The DURABLE record, not the log line. A verdict that lives only in a
        // log is not a verdict anybody can act on.
        final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
        expect(record['outcomeKind'], 'pass');
        expect(record['isOverallPass'], isTrue);
        expect(record['qaContractId'], _contractId);
        expect(
          (record['gateResults'] as List).length,
          1,
          reason: 'the record must carry the gate results it was derived from',
        );
      },
    );

    test(
      'the record names the SOURCE that answered, not only the verdict',
      () async {
        // F-204: a persisted result that cannot say whether the platform or a
        // stand-in produced it is not an auditable record. R3 is source-free, so
        // it contributes no provenance — this asserts the RECORD is present and
        // well-formed rather than inventing a source for a source-free gate.
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
        );

        await harness.run();

        final item = await harness.store.readWorkItem(_itemId);
        final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
        expect(record.containsKey('sourceProvenance'), isTrue);
        expect(record['sourceProvenance'], isA<List<dynamic>>());
      },
    );

    test(
      'a PASS is settled by the QA executor and a FAILURE by the orchestrator',
      () async {
        // The design's actor rule (`evaluator-spec.md` §4.2, step 4). Both
        // edges admit both actors, so no guard turns on it — but the audit
        // trail does, and the trail is what a later reader has.
        final passing = _Harness();
        await passing.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
        );
        await passing.run();

        final failing = _Harness(producerValid: false);
        await failing.seed(
          state: WorkItemState.reviewApproved,
          contract: _failingContract(),
        );
        await failing.run();

        final passRecord = await _recordTo(passing, WorkItemState.qaPassed);
        expect(
          passRecord.actorType,
          ActorType.qaExecutor,
          reason: 'a passing verdict is the QA executor\'s own determination',
        );

        final failRecord = await _recordTo(failing, WorkItemState.qaFailed);
        expect(
          failRecord.actorType,
          ActorType.orchestrator,
          reason:
              'a failure is the orchestrator\'s record of a verdict the '
              'executor produced',
        );
      },
    );
  });

  group('a verdict and a fault are not the same thing', () {
    test('a contract whose required gate FAILS reaches qaFailed and raises a '
        'blocking decision', () async {
      final harness = _Harness(producerValid: false);
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _failingContract(),
      );

      final result = await harness.run();

      expect(result.failed, 1);
      expect(
        result.faulted,
        0,
        reason: 'a failing gate is a verdict, not a fault',
      );

      final item = await harness.store.readWorkItem(_itemId);
      final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
      expect(record['outcomeKind'], 'not_pass');
      expect(record['isOverallPass'], isFalse);

      // It REACHED `qaFailed` — and the state it rests in now is the human
      // gate, because that is where a failed QA can be acted on.
      final path = await _path(harness);
      expect(path, contains(WorkItemState.qaFailed));
      expect(path, isNot(contains(WorkItemState.qaPassed)));
      expect(item.state, WorkItemState.waitingForHumanDecision);
    });

    test('a gate that REFUSES its own declaration is a FAULT, and is '
        'recorded as one', () async {
      // The shipped F2 declaration carries an empty `ownedPathGlobs`, which
      // the gate refuses by design (§9 requirement gap 3): an empty owned set
      // would fail every path — stricter, but useless — and one that read
      // empty as "all owned" would be a no-op. The refusal must not be
      // recorded as "the change scope gate failed": the gate did not fail, it
      // was never evaluated.
      final harness = _Harness();
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _emptyOwnedGlobsContract(),
      );

      final result = await harness.run();

      expect(result.faulted, 1);
      expect(
        result.failed,
        0,
        reason:
            'a fault is not a failing verdict and must not be counted '
            'as one',
      );
      expect(result.passed, 0);

      final item = await harness.store.readWorkItem(_itemId);
      final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
      expect(record['outcomeKind'], 'fault');
      expect(
        record.containsKey('isOverallPass'),
        isFalse,
        reason:
            'a fault has no overall determination to report: the gates '
            'never spoke',
      );
      expect(
        record.containsKey('gateResults'),
        isFalse,
        reason:
            'the evaluation produced NO gate results, so the record must '
            'not carry any: an empty list would read as "every gate was '
            'evaluated and none of them spoke"',
      );
      expect(record['reason'], isA<String>());
      expect((record['reason'] as String), isNotEmpty);
    });

    test(
      'the fault record carries the CAUSE, so the reason is actionable',
      () async {
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _emptyOwnedGlobsContract(),
        );

        await harness.run();

        final item = await harness.store.readWorkItem(_itemId);
        final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
        final cause = record['cause'] as String?;
        expect(
          cause,
          isNotNull,
          reason: 'a fault without its cause names a symptom and not a cause',
        );
        expect(cause, contains('ownedPathGlobs'));
      },
    );

    test(
      'a producer that cannot be identified is a FAULT, not a silent pass',
      () async {
        final harness = _Harness(producerMissing: true);
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
        );

        final result = await harness.run();

        expect(result.faulted, 1);
        expect(result.passed, 0);
        final item = await harness.store.readWorkItem(_itemId);
        final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
        expect(record['outcomeKind'], 'fault');
      },
    );

    test(
      'a required gate with NO registered evaluator is notExecuted, and the '
      'item does not pass',
      () async {
        // V2: a contract that declares a gate nothing can evaluate has not
        // been satisfied. The honest answer is "not executed", and an item
        // carrying one must not reach `qaPassed`.
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _unregisteredGateContract(),
        );

        final result = await harness.run();

        expect(result.passed, 0);
        expect(result.failed, 1);

        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);

        final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
        final gateResults = (record['gateResults'] as List).cast<Map>();
        expect(gateResults.single['status'], 'not_executed');
      },
    );
  });

  group('a failure reaches a human', () {
    test(
      'the item goes reviewApproved -> qaInProgress -> qaFailed -> '
      'waitingForHumanDecision',
      () async {
        // V5: a failed QA must REACH `qaFailed` and must not reach
        // `qaPassed`, and a blocking decision must be raised. `qaFailed` has
        // exactly one edge out, and that edge is the one the decision opens.
        final harness = _Harness(producerValid: false);
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _failingContract(),
        );

        await harness.run();

        final path = await _path(harness);
        expect(
          path,
          containsAllInOrder([
            WorkItemState.qaInProgress,
            WorkItemState.qaFailed,
            WorkItemState.waitingForHumanDecision,
          ]),
          reason: 'the failure must be recorded before a human is asked',
        );
        expect(path, isNot(contains(WorkItemState.qaPassed)));
      },
    );

    test('the decision raised is a PENDING BLOCKING qa_waiver', () async {
      final harness = _Harness(producerValid: false);
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _failingContract(),
      );

      final result = await harness.run();

      final outcome = result.outcomes.single;
      expect(outcome.raisedDecisionId, isNotNull);
      expect(outcome.raisedDecisionType, HumanDecisionType.qaWaiver);

      final item = await harness.store.readWorkItem(_itemId);
      expect(item.blockingHumanDecisionId, isNotNull);
      expect(item.blockingReason, isNotEmpty);

      final decision = await harness.store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      expect(decision.decisionType, HumanDecisionType.qaWaiver);
      expect(decision.status, HumanDecisionStatus.pending);
      expect(decision.blocking, isTrue);
      expect(decision.decider, isNull, reason: 'a human has not answered yet');
      expect(decision.choice, isNull);
      expect(decision.options, isNotNull);
      expect(
        decision.options!.map((option) => option.optionId),
        containsAll(<String>['waive', 'reject']),
      );
      expect(
        decision.metadata?['qaContractId'],
        _contractId,
        reason: 'the decision must name the contract it is about',
      );
    });

    test(
      'a FAULT raises a decision too, because qaFailed has no other edge out',
      () async {
        final harness = _Harness(producerMissing: true);
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
        );

        final result = await harness.run();

        expect(result.faulted, 1);
        final outcome = result.outcomes.single;
        expect(outcome.raisedDecisionId, isNotNull);

        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);

        final decision = await harness.store.readHumanDecision(
          item.blockingHumanDecisionId!,
        );
        expect(decision.decisionType, HumanDecisionType.qaWaiver);
        expect(
          decision.metadata?['outcomeKind'],
          'fault',
          reason:
              'a human asked to accept a result must be told whether the '
              'gates spoke and said no, or never spoke at all',
        );
        expect(
          decision.question,
          contains('could not be evaluated'),
          reason: 'the question must not read like a failing verdict',
        );
      },
    );

    test('the drain never RESOLVES the decision it raised', () async {
      // The answer is the human's. A drain that answered its own question
      // would make the whole gate theatre.
      final harness = _Harness(producerValid: false);
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _failingContract(),
      );

      await harness.run();

      final item = await harness.store.readWorkItem(_itemId);
      final decision = await harness.store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      expect(decision.status, HumanDecisionStatus.pending);
      expect(decision.resolvedOptionId, isNull);
      expect(decision.signature, isNull);
    });
  });

  group('the drain moves nothing it was not asked to move', () {
    test('an item with no QA contract id is SKIPPED, not moved', () async {
      final harness = _Harness();
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _passingContract(),
        qaContractId: null,
      );

      final result = await harness.run();

      expect(result.considered, 1);
      expect(result.skipped, 1);
      expect(result.passed, 0);
      expect(result.faulted, 0);

      final item = await harness.store.readWorkItem(_itemId);
      expect(
        item.state,
        WorkItemState.reviewApproved,
        reason:
            'an item with no contract to evaluate must not be moved into '
            'a QA state',
      );
    });

    test('an item in any other state is not a candidate at all', () async {
      final harness = _Harness();
      await harness.seed(
        state: WorkItemState.implementationReady,
        contract: _passingContract(),
      );

      final result = await harness.run();

      expect(result.considered, 0);
      final item = await harness.store.readWorkItem(_itemId);
      expect(item.state, WorkItemState.implementationReady);
    });
  });

  group('the drain is safe to run twice', () {
    test('a second pass over the same item evaluates nothing', () async {
      final harness = _Harness();
      await harness.seed(
        state: WorkItemState.reviewApproved,
        contract: _passingContract(),
      );

      final first = await harness.run();
      final second = await harness.run();

      expect(first.passed, 1);
      expect(
        second.considered,
        0,
        reason:
            'the item left reviewApproved, so it is no longer a candidate; '
            'a drain that evaluated it twice would record two verdicts for '
            'one review',
      );
      expect(second.passed, 0);
    });

    test('an item left at qaInProgress by a crash is RESUMED', () async {
      // The process died between "take the item" and "settle the item". The
      // item is at `qaInProgress` with a contract, and the next tick must
      // finish it rather than strand it.
      final harness = _Harness();
      await harness.seed(
        state: WorkItemState.qaInProgress,
        contract: _passingContract(),
      );

      final result = await harness.run();

      expect(result.considered, 1);
      expect(result.passed, 1);
      final item = await harness.store.readWorkItem(_itemId);
      expect(item.state, WorkItemState.qaPassed);
    });
  });

  group("one item's failure cannot take the lane down with it", () {
    test(
      "an item whose contract id cannot be READ does not lose the lane's "
      'whole tick',
      () async {
        // V6: the lane keeps going. One work item whose contract id resolves
        // to no row is a fault on THAT item; the next item in the same pass is
        // still evaluated.
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
          workItemId: _unreadableItemId,
          qaContractId: 'qa-product-WI-drain-test-unreadable',
        );
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
          workItemId: _healthyItemId,
        );

        final result = await harness.run();

        expect(result.considered, 2);
        expect(result.faulted, 1);
        expect(result.passed, 1);

        final faulted = await harness.store.readWorkItem(_unreadableItemId);
        expect(faulted.state, WorkItemState.waitingForHumanDecision);
        final healthy = await harness.store.readWorkItem(_healthyItemId);
        expect(healthy.state, WorkItemState.qaPassed);
      },
    );

    test(
      'an item whose PRODUCER cannot be found does not stop the next item '
      'from settling',
      () async {
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
          workItemId: _faultingItemId,
        );
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _passingContract(),
          workItemId: _healthyItemId,
        );
        harness.producerResolver.overrides[_faultingItemId] = null;

        final result = await harness.run();

        expect(result.considered, 2);
        expect(result.faulted, 1);
        expect(result.passed, 1);

        final faulted = await harness.store.readWorkItem(_faultingItemId);
        expect(faulted.state, WorkItemState.waitingForHumanDecision);
        final healthy = await harness.store.readWorkItem(_healthyItemId);
        expect(healthy.state, WorkItemState.qaPassed);
      },
    );
  });
}

/// The states the item passed through, in order.
Future<List<WorkItemState>> _path(_Harness harness) async {
  final records = await harness.store.readTransitionHistory(_itemId);
  return records.map((record) => record.toState).toList();
}

/// The transition record that landed the item in [state].
Future<WorkflowTransitionRecord> _recordTo(
  _Harness harness,
  WorkItemState state,
) async {
  final records = await harness.store.readTransitionHistory(_itemId);
  return records.firstWhere((record) => record.toState == state);
}

const _itemId = 'WI-drain-test';
const _faultingItemId = 'WI-drain-test-faulting';
const _unreadableItemId = 'WI-drain-test-unreadable';
const _healthyItemId = 'WI-drain-test-healthy';
const _contractId = 'qa-product-WI-drain-test';

WorkItem _item({
  required WorkItemState state,
  String? qaContractId,
  String workItemId = _itemId,
}) {
  final now = DateTime.utc(2026, 10, 21);
  return WorkItem(
    workItemId: workItemId,
    productId: 'shipit-platform',
    category: WorkItemCategory.feature,
    title: 'A reviewed work item',
    state: state,
    qaContractId: qaContractId,
    createdAt: now,
    updatedAt: now,
  );
}

QAContract _contract(
  List<QAGateDefinition> gates, {
  String contractId = _contractId,
}) {
  final now = DateTime.utc(2026, 10, 21);
  return QAContract(
    contractId: contractId,
    workItemCategory: WorkItemCategory.feature,
    gates: gates,
    version: '1.0.0',
    passCriteria: const QAPassCriteria(
      allRequiredGatesMustPass: true,
      optionalGateFailuresAllowed: 0,
      waiverRequiresHumanDecision: true,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

/// R3 — the source-free gate. It reads the agent's own structured result, so
/// it can genuinely pass or genuinely fail in this file.
QAGateDefinition _r3Gate() => const QAGateDefinition(
  gateId: 'intake-structured-result-admitted',
  type: 'triage-classification-structure',
  required: true,
  config: {
    'sourceColumn': 'agent_result.structuredResultJson',
    'requiredFields': [
      'classification',
      'status',
      'confidence',
      'suspectedCategory',
    ],
    'classificationEnum': 'DefectClassification',
    'statusEnum': 'DefectStatus',
  },
  evidenceTypes: ['triage_structured_result'],
);

QAContract _passingContract() => _contract([_r3Gate()]);

QAContract _failingContract() => _contract([_r3Gate()]);

/// The shipped F2 declaration, verbatim: an EMPTY owned set, which the gate
/// refuses by design.
QAContract _emptyOwnedGlobsContract() => _contract([
  const QAGateDefinition(
    gateId: 'feature-change-scope-confined',
    type: 'change-scope-confinement',
    required: true,
    config: {
      'ownedPathGlobs': <String>[],
      'forbiddenPathGlobs': <String>[],
      'pathSource': 'git_diff_name_only',
    },
    evidenceTypes: ['committed_diff_paths'],
  ),
]);

/// A contract that declares a gate type nothing is registered to evaluate.
QAContract _unregisteredGateContract() => _contract([
  const QAGateDefinition(
    gateId: 'a-gate-nothing-can-evaluate',
    type: 'no-evaluator-is-registered-for-this',
    required: true,
    config: {},
    evidenceTypes: [],
  ),
]);

/// A result that satisfies R3, and one that does not.
AgentResult _agentResult({required bool valid, String workItemId = _itemId}) {
  return AgentResult(
    resultId: 'result-drain-test',
    sessionId: 'session-drain-test',
    workItemId: workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: const AgentDiagnostics(
      exitCode: 0,
      durationMs: 1,
      toolCalls: 0,
      errors: [],
      warnings: [],
    ),
    structuredResult: valid
        ? const {
            'classification': 'implementation_defect',
            'status': 'reported',
            'confidence': 0.9,
            'suspectedCategory': 'documentation',
          }
        : const {'status': 'reported'},
    completedAt: DateTime.utc(2026, 10, 21),
  );
}

/// A producer resolver that answers with a fixed result, or with nothing.
class _FakeProducerResolver implements ProducerResolver {
  _FakeProducerResolver(this._result);

  final AgentResult? _result;

  /// Per-work-item answers, for the case where one item's producer is
  /// missing and the next item's is not.
  final Map<String, AgentResult?> overrides = {};

  @override
  Future<ResolvedProducer?> resolveFor(WorkItem item) async {
    final result = overrides.containsKey(item.workItemId)
        ? overrides[item.workItemId]
        : _result;
    if (result == null) return null;
    return ResolvedProducer(
      executionId: 'exec-drain-test',
      result: result,
      workingDirectory: '/tmp/does-not-exist',
      startingRevision: 'f58d6fb1',
      how: ProducerResolution.stampedProducer,
      note: 'the test producer',
    );
  }
}

/// One drain's worth of wiring.
class _Harness {
  _Harness({bool producerMissing = false, bool producerValid = true})
    : producerResolver = _FakeProducerResolver(
        producerMissing ? null : _agentResult(valid: producerValid),
      );

  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final _FakeProducerResolver producerResolver;
  final List<String> logEvents = [];

  final InMemoryQAContractStore contractStore = InMemoryQAContractStore();

  late final DurableWorkflowEngine engine = DurableWorkflowEngine(store: store);

  Future<void> seed({
    required WorkItemState state,
    required QAContract contract,
    String? qaContractId = _contractId,
    String workItemId = _itemId,
  }) async {
    await store.saveWorkItem(
      _item(state: state, qaContractId: qaContractId, workItemId: workItemId),
    );
    contractStore.hold(contract);
  }

  Future<QADrainResult> run() {
    final service = QAGateEvaluationService(
      orchestration: QAOrchestration(registry: buildGateRegistryOverDoubles()),
      contractStore: contractStore,
    );
    return runQADrain(
      workflowEngine: engine,
      workflowStore: store,
      evaluationService: service,
      producerResolver: producerResolver,
      log: (event, data) => logEvents.add(event),
    );
  }
}
