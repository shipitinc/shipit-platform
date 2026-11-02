import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/qa/qa_drain.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ProducerResolution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
// `lib/` import, which is a known cost of co-locating tests here — the same
// cost `implementation_readiness_probe_test.dart` records.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// Regression for F-245: an item that re-enters `reviewApproved` after a full
/// QA traversal must be TAKEN again, not silently replayed through the
/// consumed `enter` idempotency key.
///
/// ## THE DEFECT THIS PINS
///
/// The drain's transition idempotency keys used to be scoped to the work item
/// forever (`qa-drain:<id>:enter|settle|fault`). An item that traversed the
/// lane once — taken, evaluated, settled, asked — could legitimately come
/// back to `reviewApproved` (a rejected waiver, a rework, a re-review and a
/// fresh approval). On return, the take's idempotency replay answered with
/// the prior ACCEPTED record and returned the item UNCHANGED, still at
/// `reviewApproved`. The fault record (`reviewApproved -> qaFailed`), the
/// settlement and `requestHumanDecision`
/// (`reviewApproved -> waitingForHumanDecision`) were then evaluated from a
/// state with edges only to `qaInProgress` — refused, every tick, forever:
/// `qa.drain.decision_refused` ~60/15min on the same items.
///
/// The keys are now scoped to the QA attempt (`qaAttempt` on the work item),
/// so a re-entered item is genuinely taken again while a retried attempt
/// still replays. These tests pin BOTH halves: the re-entry that must move,
/// and the `qaFailed` strand — settle committed, decision never raised —
/// that must reach the human rather than sit silent.
void main() {
  group('an item returned to reviewApproved is taken again', () {
    test(
      'a second traversal enters qaInProgress, settles, and reaches the '
      'human — no refusal is logged',
      () async {
        final harness = _Harness(producerValid: false);
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _contract(),
        );

        // Traversal 1: the whole lane — take, evaluate, settle, ask. This is
        // what consumes `qa-drain:<id>:enter:a1` durably.
        final first = await harness.run();
        expect(first.failed, 1);
        var item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(item.metadata?[qaAttemptMetadataKey], 1);

        // THE RETURN. A rejected waiver sends the work back to be produced
        // again, a fresh implementer run and a fresh human approval bring it
        // to `reviewApproved` once more. All of that is collapsed here to
        // the two facts the drain actually sees: the state, and the consumed
        // `enter` key — which is what produced the live loop.
        item = item.copyWith(
          state: WorkItemState.reviewApproved,
          blockingHumanDecisionId: null,
          blockingReason: null,
          version: item.version + 1,
        );
        await harness.store.saveWorkItem(
          item,
          expectedVersion: item.version - 1,
        );

        final second = await harness.run();

        expect(
          harness.logEvents,
          isNot(contains('qa.drain.decision_refused')),
          reason:
              'the live defect: every tick raised a decision from '
              'reviewApproved and was refused; the take must happen first',
        );
        expect(
          harness.logEvents,
          isNot(contains('qa.drain.item.settlement_refused')),
        );
        expect(second.considered, 1);
        expect(second.failed, 1);

        item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(
          item.metadata?[qaAttemptMetadataKey],
          2,
          reason: 'the second traversal is a NEW attempt, keyed a2',
        );

        // The PATH is the proof: a second traversal means a second
        // qaInProgress -> qaFailed -> waitingForHumanDecision sequence, not a
        // replay of the first.
        final toStates = (await harness.store.readTransitionHistory(
          _itemId,
        )).map((record) => record.toState).toList();
        expect(
          toStates.where((state) => state == WorkItemState.qaInProgress).length,
          2,
          reason: 'the item was genuinely TAKEN twice, not replayed',
        );
        expect(
          toStates
              .where((state) => state == WorkItemState.waitingForHumanDecision)
              .length,
          2,
        );
      },
    );

    test(
      'the second take mints an attempt-scoped idempotency key',
      () async {
        final harness = _Harness(producerValid: false);
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _contract(),
        );

        await harness.run();
        var item = await harness.store.readWorkItem(_itemId);
        item = item.copyWith(
          state: WorkItemState.reviewApproved,
          blockingHumanDecisionId: null,
          blockingReason: null,
          version: item.version + 1,
        );
        await harness.store.saveWorkItem(
          item,
          expectedVersion: item.version - 1,
        );

        await harness.run();

        final keys = (await harness.store.readTransitionHistory(
          _itemId,
        )).map((record) => record.idempotencyKey).whereType<String>().toSet();
        expect(keys, contains('qa-drain:$_itemId:enter:a1'));
        expect(keys, contains('qa-drain:$_itemId:enter:a2'));
        expect(keys, contains('qa-drain:$_itemId:settle:a1'));
        expect(keys, contains('qa-drain:$_itemId:settle:a2'));
      },
    );

    test(
      'a resume at qaInProgress continues the attempt the take stamped',
      () async {
        // The process died between the take and the settlement. The item is
        // at `qaInProgress` carrying `qaAttempt: 3`, and the settle must reuse
        // attempt 3's key — the attempt belongs to the take, not the tick.
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.qaInProgress,
          contract: _contract(),
          metadata: const {qaAttemptMetadataKey: 3},
        );

        final result = await harness.run();

        expect(result.passed, 1);
        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.qaPassed);

        final keys = (await harness.store.readTransitionHistory(
          _itemId,
        )).map((record) => record.idempotencyKey).whereType<String>().toSet();
        expect(keys, contains('qa-drain:$_itemId:settle:a3'));
        expect(
          keys.any((key) => key.startsWith('qa-drain:$_itemId:enter')),
          isFalse,
          reason: 'a resume must not mint a second take',
        );
      },
    );
  });

  group('an item stranded at qaFailed reaches the human', () {
    test(
      'a recorded failure with no pending decision gets the decision it was '
      'missing',
      () async {
        // The settlement committed and the process died before the decision
        // raise — the drain's own reachable strand. `qaFailed` has exactly
        // one edge out and it requires a pending blocking decision, so the
        // item cannot move until somebody asks.
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.qaFailed,
          contract: _contract(),
          metadata: const {
            'qaEvaluation': {'outcomeKind': 'not_pass'},
          },
        );

        final result = await harness.run();

        expect(result.considered, 1);
        expect(result.escalated, 1);
        expect(result.failed, 0);
        expect(
          harness.logEvents,
          isNot(contains('qa.drain.decision_refused')),
        );

        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(item.blockingHumanDecisionId, isNotNull);

        final decision = await harness.store.readHumanDecision(
          item.blockingHumanDecisionId!,
        );
        expect(decision.decisionType, HumanDecisionType.qaWaiver);
        expect(decision.status.isResolved, isFalse);
        expect(
          decision.metadata?['outcomeKind'],
          'not_pass',
          reason:
              'the decision must carry the RECORDED kind of the failure it '
              'is about — not_pass was on the item already',
        );

        // It is NOT evaluated a second time: the record stands. There is no
        // enter/settle/fault transition on this pass at all.
        final toStates = (await harness.store.readTransitionHistory(
          _itemId,
        )).map((record) => record.toState).toList();
        expect(
          toStates,
          isNot(contains(WorkItemState.qaInProgress)),
          reason: 'a recorded failure is escalated, not re-evaluated',
        );
      },
    );

    test(
      'a pending blocking decision already on the item is used — no second '
      'question is minted',
      () async {
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.qaFailed,
          contract: _contract(),
          metadata: const {
            'qaEvaluation': {'outcomeKind': 'fault'},
          },
        );
        final existing = HumanDecision(
          decisionId: 'dec-prewired',
          workItemId: _itemId,
          decisionType: HumanDecisionType.qaWaiver,
          status: HumanDecisionStatus.pending,
          question: 'waive or reject?',
          blocking: true,
          requestedAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        );
        await harness.store.saveHumanDecision(existing);

        final result = await harness.run();

        expect(result.escalated, 1);
        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(
          item.blockingHumanDecisionId,
          'dec-prewired',
          reason:
              'the gate edge admits the pending decision it already has; '
              'minting another would leave a second unanswered question '
              'hanging on the same item',
        );
        expect(
          (await harness.store.readHumanDecisionsForWorkItem(_itemId)).length,
          1,
          reason: 'no duplicate decision was created',
        );
      },
    );
  });

  group('the attempt marker is honest or the item is skipped', () {
    test(
      'an unreadable qaAttempt marker is a reported skip, never a fallback '
      'that re-consumes an old key',
      () async {
        final harness = _Harness();
        await harness.seed(
          state: WorkItemState.reviewApproved,
          contract: _contract(),
          metadata: const {qaAttemptMetadataKey: 'not-a-number'},
        );

        final result = await harness.run();

        expect(result.skipped, 1);
        expect(result.considered, 1);
        expect(harness.logEvents, contains('qa.drain.item.skipped'));

        final item = await harness.store.readWorkItem(_itemId);
        expect(
          item.state,
          WorkItemState.reviewApproved,
          reason:
              'an item whose attempt cannot be keyed safely is not moved — '
              'the defect is reported, not hidden under a guessed number',
        );
      },
    );
  });
}

const _itemId = 'WI-drain-reentry-test';
const _contractId = 'qa-product-$_itemId';

WorkItem _item({
  required WorkItemState state,
  String? qaContractId,
  Map<String, dynamic>? metadata,
}) {
  final now = DateTime.utc(2026, 11, 1);
  return WorkItem(
    workItemId: _itemId,
    productId: 'shipit-platform',
    category: WorkItemCategory.feature,
    title: 'A reviewed work item',
    description: 'A work item the QA drain is regression-tested against.',
    state: state,
    qaContractId: qaContractId,
    metadata: metadata,
    createdAt: now,
    updatedAt: now,
  );
}

/// The R3 gate: source-free, so it passes or fails on the agent result alone.
QAContract _contract() {
  final now = DateTime.utc(2026, 11, 1);
  return QAContract(
    contractId: _contractId,
    workItemCategory: WorkItemCategory.feature,
    gates: const [
      QAGateDefinition(
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
      ),
    ],
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

AgentResult _agentResult({required bool valid}) {
  return AgentResult(
    resultId: 'result-drain-reentry-test',
    sessionId: 'session-drain-reentry-test',
    workItemId: _itemId,
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
    completedAt: DateTime.utc(2026, 11, 1),
  );
}

class _FakeProducerResolver implements ProducerResolver {
  _FakeProducerResolver(this._result);

  final AgentResult? _result;

  @override
  Future<ResolvedProducer?> resolveFor(WorkItem item) async {
    final result = _result;
    if (result == null) return null;
    return ResolvedProducer(
      executionId: 'exec-drain-reentry-test',
      result: result,
      workingDirectory: '/tmp/does-not-exist',
      startingRevision: 'f58d6fb1',
      how: ProducerResolution.stampedProducer,
      note: 'the test producer',
    );
  }
}

/// The smallest honest [QAContractStore]: a map keyed by contract id.
class _InMemoryQAContractStore implements QAContractStore {
  final Map<String, QAContract> _contracts = {};

  void hold(QAContract contract) => _contracts[contract.contractId] = contract;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    _contracts[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    _contracts[contract.contractId] = contract;
    return contract;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async =>
      _contracts[contractId];

  @override
  Future<bool> hasQAContract(String contractId) async =>
      _contracts.containsKey(contractId);

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async => _contracts.values.toList();

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => _contracts.values
      .where((contract) => contract.workItemCategory == category)
      .toList();
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

  final _InMemoryQAContractStore contractStore = _InMemoryQAContractStore();

  late final DurableWorkflowEngine engine = DurableWorkflowEngine(store: store);

  Future<void> seed({
    required WorkItemState state,
    required QAContract contract,
    String? qaContractId = _contractId,
    Map<String, dynamic>? metadata,
  }) async {
    await store.saveWorkItem(
      _item(state: state, qaContractId: qaContractId, metadata: metadata),
    );
    contractStore.hold(contract);
  }

  Future<QADrainResult> run() {
    // Only the source-free R3 evaluator is registered: every contract this
    // file declares resolves to it, and every other type stays unregistered —
    // the same not_executed answer an unwired gate gets.
    final service = QAGateEvaluationService(
      orchestration: QAOrchestration(
        registry: GateRegistry()..register(TriageClassificationAdmittedGate()),
      ),
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
