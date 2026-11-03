import 'package:control_plane_server/src/qa/producer_scoped_gate.dart';
import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/qa/qa_drain.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
// `lib/` import, which is a known cost of co-locating tests here — the same
// cost `qa_drain_reentry_test.dart` records.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// Regression for F-253: the QA drain evaluated a `qa-triage-*` contract
/// against the WRONG execution's `structuredResult`.
///
/// ## THE LIVE DEFECT THIS PINS
///
/// Producer resolution was contract-blind: a stamped `producerActorId` won
/// outright, and the fallback was the newest IMPLEMENTER execution. A defect
/// item in the churn loop (approve -> implement -> contract fails -> waiver
/// -> reject -> re-implement) carries a TRIAGE_DEFECT execution AND a newer
/// IMPLEMENTER execution whose completion re-stamps `producerActorId` — so
/// every `qa-triage-*` evaluation after a rework read the implementer's
/// result and failed "cites no evidence" / missing classification even
/// though the triage output was correct.
///
/// ## WHAT IS PINNED, END TO END
///
/// The drain is driven against the REAL `ProducerWorkspaceResolver` over a
/// real `InMemoryExecutionStore` holding BOTH executions, and the REAL
/// `ProductionProducerRoleSource` the scoped gate reads — so the verdict is
/// wrong if EITHER the result under evaluation or the role answer is the
/// implementer's:
///
///  * a `qa-triage-*` contract evaluates the TRIAGE execution's result:
///    `triage-classification-admitted` is `passed` — never `failed` (the
///    implementer's result judged by triage rules) and never
///    `not_applicable` (the role answer being implementer);
///  * a `qa-product-*` contract on the same execution set still evaluates
///    the IMPLEMENTER's result: the triage-shaped gate records
///    `not_applicable` for producer role IMPLEMENTER, exactly as F-246
///    requires;
///  * a `qa-triage-*` contract on an item with no TRIAGE_DEFECT execution
///    faults rather than evaluating some other role's result.
void main() {
  group(
    'a defect item carrying both a triage and an implementer execution',
    () {
      test(
        'the qa-triage contract evaluates the TRIAGE execution\'s result, '
        'not the implementer\'s — the stamped producer is the implementer',
        () async {
          final harness = _Harness();
          await harness.seedExecutions(stamp: 'exec-impl');
          await harness.seed(
            contract: buildAdvisoryTriageQAContract(
              defectId: 'DEF-253',
              workItemId: _itemId,
              now: DateTime.utc(2026, 11, 2),
            ),
          );

          final result = await harness.run();

          expect(result.passed, 1);
          expect(result.failed, 0);
          expect(result.faulted, 0);
          final item = await harness.store.readWorkItem(_itemId);
          expect(item.state, WorkItemState.qaPassed);

          final classification = _gateResultFor(
            item,
            'triage-classification-admitted',
          );
          expect(
            classification['status'],
            'passed',
            reason:
                'the structural check must have EVALUATED the triage-shaped '
                'result. Under the contract-blind resolution the producer was '
                'the implementer: the scoped gate would answer not_applicable '
                '(role IMPLEMENTER) and, unscoped, the implementer\'s result '
                'would fail the triage fields — the live F-253 verdict',
          );
        },
      );

      test(
        'the same item under a qa-product contract still evaluates the '
        'IMPLEMENTER\'s result',
        () async {
          final harness = _Harness();
          await harness.seedExecutions(stamp: 'exec-impl');
          await harness.seed(
            contract: buildProductQAContract(
              spec: const QAContractSpec(
                gates: [
                  QAGateSpec(
                    gateId: 'intake-structured-result-admitted',
                    type: 'triage-classification-structure',
                    required: true,
                    config: <String, dynamic>{},
                  ),
                  QAGateSpec(
                    gateId: 'product-stub-gate',
                    type: 'stub-product-gate',
                    required: true,
                    config: <String, dynamic>{},
                  ),
                ],
              ),
              productId: 'shipit-platform',
              workItemCategory: WorkItemCategory.feature,
              workItemId: _itemId,
              manifestVersion: 'test',
              now: DateTime.utc(2026, 11, 2),
            ),
          );

          final result = await harness.run();

          expect(result.passed, 1);
          final item = await harness.store.readWorkItem(_itemId);
          expect(item.state, WorkItemState.qaPassed);

          final intake = _gateResultFor(
            item,
            'intake-structured-result-admitted',
          );
          expect(intake['status'], 'not_applicable');
          expect(
            (intake['metadata'] as Map)['producerRole'],
            'IMPLEMENTER',
            reason:
                'a product contract judges the implementer\'s output: the '
                'resolved producer is the stamped implementer execution, and '
                'the triage-scoped gate correctly does not apply to it — the '
                'F-246 behaviour, preserved for product contracts',
          );
        },
      );

      test(
        'a qa-triage contract on an item with no TRIAGE_DEFECT execution '
        'faults rather than evaluating another role\'s result',
        () async {
          final harness = _Harness();
          // Only the implementer execution — the triage run's row is gone or
          // never existed. A stamp naming it is the honest post-rework state.
          await harness.seedExecutions(
            stamp: 'exec-impl',
            includeTriage: false,
          );
          await harness.seed(
            contract: buildAdvisoryTriageQAContract(
              defectId: 'DEF-253',
              workItemId: _itemId,
              now: DateTime.utc(2026, 11, 2),
            ),
          );

          final result = await harness.run();

          expect(result.faulted, 1);
          expect(result.passed, 0);
          final outcome = result.outcomes.single;
          expect(outcome.outcomeKind, 'fault');
          expect(
            outcome.detail,
            contains('could not be identified'),
            reason:
                'substituting the implementer\'s result for the missing triage '
                'producer is the defect in another costume — the contract '
                'cannot be evaluated, so the item faults to a human',
          );
        },
      );
    },
  );
}

const _itemId = 'defect-DEF-253';

Map<String, dynamic> _gateResultFor(WorkItem item, String gateId) {
  final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
  return (record['gateResults'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((result) => result['gateId'] == gateId);
}

/// A gate that always passes, standing in for evaluators whose own verdicts
/// are not under test here (`triage-evidence-grounding`, the product stub).
class _PassGate implements GateEvaluator {
  _PassGate(this.gateType);

  @override
  final String gateType;

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final now = DateTime.now();
    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: QAGateStatus.passed,
      evidence: const [],
      evaluatedAt: now,
      passedAt: now,
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

/// One drain's worth of wiring, over the REAL producer resolution rule.
///
/// Unlike the other drain suites — which fake the producer to isolate a
/// drain behaviour — this file's claim IS the resolution, so it runs the
/// production `ProducerWorkspaceResolver` and the production role source
/// the scoped gate reads.
class _Harness {
  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();
  final _InMemoryQAContractStore contractStore = _InMemoryQAContractStore();

  late final DurableWorkflowEngine engine = DurableWorkflowEngine(store: store);
  late final ProducerWorkspaceResolver resolver = ProducerWorkspaceResolver(
    executionStore: executionStore,
    workflowStore: store,
  );

  Future<void> seedExecutions({
    required String stamp,
    bool includeTriage = true,
  }) async {
    final t0 = DateTime.utc(2026, 11, 1);
    if (includeTriage) {
      await _execution(
        id: 'exec-triage',
        role: AgentRole.triageDefect,
        startedAt: t0,
        structuredResult: const {
          'classification': 'implementation_defect',
          'status': 'reported',
          'confidence': 0.9,
          'suspectedCategory': 'documentation',
          'evidenceUsed': ['EVD-DEF-253-1', 'EVD-DEF-253-2'],
        },
      );
    }
    // The rework implementer: NEWER, and the stamp names it — the exact
    // rows the contract-blind resolution read as the producer.
    await _execution(
      id: 'exec-impl',
      role: AgentRole.implementer,
      startedAt: t0.add(const Duration(hours: 1)),
      structuredResult: const {'summary': 'reworked the defect fix'},
    );
    await store.saveWorkItem(
      WorkItem(
        workItemId: _itemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A defect work item after rework',
        state: WorkItemState.reviewApproved,
        metadata: {'producerActorId': stamp},
        createdAt: t0,
        updatedAt: t0,
      ),
    );
  }

  Future<void> _execution({
    required String id,
    required AgentRole role,
    required DateTime startedAt,
    required Map<String, dynamic> structuredResult,
  }) async {
    await executionStore.saveExecution(
      AgentExecution(
        executionId: id,
        workItemId: _itemId,
        requestId: id,
        runtimeTypeId: 'fake',
        role: role,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws-1'),
        startedAt: startedAt,
        version: 1,
      ),
    );
    await executionStore.saveResult(
      id,
      AgentResult(
        resultId: 'res-$id',
        sessionId: 'ses-$id',
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
        structuredResult: structuredResult,
        completedAt: startedAt,
      ),
    );
  }

  Future<void> seed({required QAContract contract}) async {
    final item = await store.readWorkItem(_itemId);
    await store.saveWorkItem(
      item.copyWith(
        qaContractId: contract.contractId,
        version: item.version + 1,
      ),
      expectedVersion: item.version,
    );
    contractStore.hold(contract);
  }

  Future<QADrainResult> run() {
    final registry = GateRegistry()
      ..register(
        // The production shape: the REAL role source over the REAL
        // resolver, so a resolution that disagreed with the drain would
        // record not_applicable here — the two reads cannot drift apart
        // under test any more than they can in production.
        ProducerRoleScopedGate(
          inner: TriageClassificationAdmittedGate(),
          roleSource: ProductionProducerRoleSource(resolver: resolver),
          appliesToRoles: const {AgentRole.triageDefect},
        ),
      )
      ..register(_PassGate('triage-evidence-grounding'))
      ..register(_PassGate('stub-product-gate'));
    return runQADrain(
      workflowEngine: engine,
      workflowStore: store,
      evaluationService: QAGateEvaluationService(
        orchestration: QAOrchestration(registry: registry),
        contractStore: contractStore,
      ),
      producerResolver: resolver,
    );
  }
}
