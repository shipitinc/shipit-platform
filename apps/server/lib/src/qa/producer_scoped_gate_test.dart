import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/qa/producer_scoped_gate.dart';
import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/qa/qa_drain.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ProducerResolution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
// `lib/` import, which is a known cost of co-locating tests here — the same
// cost `qa_drain_reentry_test.dart` records.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// Regression for F-246: `intake-structured-result-admitted`
/// (type `triage-classification-structure`) is declared on the shipped
/// product contract — every `qa-product-*` row — yet asserts a shape only a
/// triage execution emits. A feature item's implementer result could never
/// satisfy it, so the contract could never pass.
///
/// ## WHAT IS PINNED, AND AT WHICH LAYER
///
///  * The evaluator: `ProducerRoleScopedGate` answers `not_applicable` for a
///    producer whose role is not in scope, delegates verbatim for a triage
///    producer, and evaluates (fails closed) when no producer resolves.
///  * The drain, end to end: a feature work item under the SHIPPED manifest's
///    derived contract reaches `qaPassed` with the intake gate recorded
///    `not_applicable` — the same persisted contract that failed before —
///    while the advisory triage contract still applies the real
///    classification check to triage output.
///
/// The four F-gates (`implementation-artifact-provenance`,
/// `change-scope-confinement`, `declared-validation-outcome`,
/// `revision-identity-match`) are stubbed to pass in the drain tests: their
/// satisfiability is their own suites' claim, and this file's is narrower —
/// the triage-shaped gate must stop deciding feature items and must not stop
/// deciding triage ones.
void main() {
  group('the evaluator scopes the gate to a triage producer', () {
    test(
      'a non-triage producer answers not_applicable, and the inner evaluator '
      'never runs',
      () async {
        final inner = _SpyGate();
        final gate = ProducerRoleScopedGate(
          inner: inner,
          roleSource: _FixedRoleSource(AgentRole.implementer),
          appliesToRoles: const {AgentRole.triageDefect},
        );

        final result = await gate.evaluate(
          'WI-feature-1',
          _featureResult(),
          _intakeGate(),
        );

        expect(result.status, QAGateStatus.notApplicable);
        expect(result.gateId, 'intake-structured-result-admitted');
        expect(
          inner.invocations,
          0,
          reason:
              'the structural check must not run against a producer it does '
              'not apply to — running it is the defect (it can only fail)',
        );
        // The record says WHY it did not apply: the role that was read, and
        // the source's provenance.
        expect(result.metadata?['producerRole'], 'IMPLEMENTER');
        expect(result.metadata?['sourceProvenance'], isA<Map>());
        expect(
          result.evidence.single.content['producerRole'],
          'IMPLEMENTER',
        );
      },
    );

    test(
      'a triage producer is evaluated verbatim — a well-formed '
      'classification passes',
      () async {
        final gate = ProducerRoleScopedGate(
          inner: TriageClassificationAdmittedGate(),
          roleSource: _FixedRoleSource(AgentRole.triageDefect),
          appliesToRoles: const {AgentRole.triageDefect},
        );

        final result = await gate.evaluate(
          'defect-DEF-1',
          _triageResult(malformed: false),
          _intakeGate(),
        );

        expect(result.status, QAGateStatus.passed);
      },
    );

    test(
      'a triage producer is evaluated verbatim — a malformed classification '
      'still fails',
      () async {
        final gate = ProducerRoleScopedGate(
          inner: TriageClassificationAdmittedGate(),
          roleSource: _FixedRoleSource(AgentRole.triageDefect),
          appliesToRoles: const {AgentRole.triageDefect},
        );

        final result = await gate.evaluate(
          'defect-DEF-1',
          _triageResult(malformed: true),
          _intakeGate(),
        );

        // The producer scope grants no exemption: a triage result missing
        // the fields its contract requires fails, exactly as the unscoped
        // gate failed it.
        expect(result.status, QAGateStatus.failed);
      },
    );

    test(
      'an unresolvable producer fails closed by evaluating, never by '
      'declaring the gate inapplicable',
      () async {
        final gate = ProducerRoleScopedGate(
          inner: TriageClassificationAdmittedGate(),
          roleSource: _FixedRoleSource(null),
          appliesToRoles: const {AgentRole.triageDefect},
        );

        final result = await gate.evaluate(
          'WI-feature-1',
          _featureResult(),
          _intakeGate(),
        );

        // "Cannot tell who produced this" is not "the producer was not
        // triage": the gate evaluates, and the feature-shaped result fails
        // on its own merits — the pre-scope verdict, preserved.
        expect(result.status, QAGateStatus.failed);
      },
    );
  });

  group('the drain moves items the scoped gate unblocks', () {
    test(
      'a feature item under the SHIPPED contract reaches qaPassed with the '
      'intake gate recorded not_applicable',
      () async {
        final contract = buildProductQAContract(
          spec: _shippedManifest().contracts.qaContract,
          productId: 'shipit-platform',
          workItemCategory: WorkItemCategory.feature,
          workItemId: _itemId,
          manifestVersion: 'test',
          now: DateTime.utc(2026, 10, 26),
        );
        final harness = _Harness(
          producerResult: _featureResult(),
          registry: _registryForFeatureLanes(AgentRole.implementer),
        );
        await harness.seed(contract);

        final result = await harness.run();

        expect(result.passed, 1);
        expect(result.failed, 0);
        expect(result.faulted, 0);

        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.qaPassed);

        final intake = _gateResultFor(
          item,
          'intake-structured-result-admitted',
        );
        expect(
          intake['status'],
          'not_applicable',
          reason:
              'the same persisted contract that blocked the item must now '
              'record that the gate did not apply — not that it passed, and '
              'not that it was absent',
        );
        expect(
          (intake['metadata'] as Map)['producerRole'],
          'IMPLEMENTER',
        );
      },
    );

    test(
      'the advisory triage contract still applies the gate to triage output',
      () async {
        final contract = buildAdvisoryTriageQAContract(
          defectId: 'DEF-1',
          workItemId: _itemId,
          now: DateTime.utc(2026, 10, 26),
        );
        final harness = _Harness(
          producerResult: _triageResult(malformed: false),
          registry: _registryForTriageLanes(AgentRole.triageDefect),
        );
        await harness.seed(contract);

        final result = await harness.run();

        expect(result.passed, 1);
        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.qaPassed);

        final intake = _gateResultFor(item, 'triage-classification-admitted');
        expect(
          intake['status'],
          'passed',
          reason:
              'a triage producer must get the REAL structural check — '
              'passed here because the output is well-formed — never the '
              'not_applicable a feature producer receives',
        );
      },
    );

    test(
      'a malformed triage classification still fails its contract and '
      'reaches the human',
      () async {
        final contract = buildAdvisoryTriageQAContract(
          defectId: 'DEF-1',
          workItemId: _itemId,
          now: DateTime.utc(2026, 10, 26),
        );
        final harness = _Harness(
          producerResult: _triageResult(malformed: true),
          registry: _registryForTriageLanes(AgentRole.triageDefect),
        );
        await harness.seed(contract);

        final result = await harness.run();

        expect(result.failed, 1);
        expect(result.passed, 0);
        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(
          _gateResultFor(item, 'triage-classification-admitted')['status'],
          'failed',
        );
      },
    );
  });
}

const _itemId = 'WI-feature-246';

Map<String, dynamic> _gateResultFor(WorkItem item, String gateId) {
  final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
  return (record['gateResults'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((result) => result['gateId'] == gateId);
}

/// The gate the shipped manifest declares, as a [QAGateDefinition] — the same
/// derivation `buildProductQAContract` performs.
QAGateDefinition _intakeGate() => const QAGateDefinition(
  gateId: 'intake-structured-result-admitted',
  type: 'triage-classification-structure',
  required: true,
  evidenceTypes: ['triage_structured_result'],
  config: <String, dynamic>{
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
);

/// An implementer's terminal result: a real shape, and none of the fields a
/// triage classification carries.
AgentResult _featureResult() => AgentResult(
  resultId: 'result-feature-246',
  sessionId: 'session-feature-246',
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
  structuredResult: const {
    'summary': 'implemented the requested change',
    'filesChanged': ['apps/server/lib/src/qa/qa_drain.dart'],
  },
  completedAt: DateTime.utc(2026, 10, 26),
);

/// A triage execution's terminal result, well-formed or missing the fields
/// the classification check requires.
AgentResult _triageResult({required bool malformed}) => AgentResult(
  resultId: 'result-triage-246',
  sessionId: 'session-triage-246',
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
  structuredResult: malformed
      ? const {'summary': 'no classification emitted'}
      : const {
          'classification': 'implementation_defect',
          'status': 'reported',
          'confidence': 0.9,
          'suspectedCategory': 'documentation',
          'evidenceUsed': <String>[],
        },
  completedAt: DateTime.utc(2026, 10, 26),
);

/// The shipped manifest, read the same way the other manifest pins read it —
/// so this test asserts against the artefact an operator registers, not a
/// transcription of it.
ProductManifest _shippedManifest() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(
          '${dir.path}${Platform.pathSeparator}packages',
        ).existsSync() &&
        Directory('${dir.path}${Platform.pathSeparator}apps').existsSync()) {
      return ProductManifest.fromJson(
        jsonDecode(
              File(
                '${dir.path}${Platform.pathSeparator}apps'
                '${Platform.pathSeparator}server'
                '${Platform.pathSeparator}manifests'
                '${Platform.pathSeparator}'
                'shipit-platform.product-manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

/// The registry a feature drain test uses: the scoped triage gate, plus
/// pass-stubs for the four feature-lane types so the intake gate is the only
/// verdict under test.
GateRegistry _registryForFeatureLanes(AgentRole producerRole) {
  final registry = GateRegistry()
    ..register(
      ProducerRoleScopedGate(
        inner: TriageClassificationAdmittedGate(),
        roleSource: _FixedRoleSource(producerRole),
        appliesToRoles: const {AgentRole.triageDefect},
      ),
    );
  for (final type in const [
    'implementation-artifact-provenance',
    'change-scope-confinement',
    'declared-validation-outcome',
    'revision-identity-match',
  ]) {
    registry.register(_PassGate(type));
  }
  return registry;
}

/// The registry a triage drain test uses: the scoped triage gate plus a
/// pass-stub for `triage-evidence-grounding` (whose own verdict is its own
/// suite's claim). `triage-clarification-routing` stays unregistered — its
/// optional `notExecuted` is the shape a real unwired gate produces.
GateRegistry _registryForTriageLanes(AgentRole producerRole) {
  return GateRegistry()
    ..register(
      ProducerRoleScopedGate(
        inner: TriageClassificationAdmittedGate(),
        roleSource: _FixedRoleSource(producerRole),
        appliesToRoles: const {AgentRole.triageDefect},
      ),
    )
    ..register(_PassGate('triage-evidence-grounding'));
}

/// A [ProducerRoleSource] that always answers the same role.
class _FixedRoleSource implements ProducerRoleSource {
  _FixedRoleSource(this._role);

  final AgentRole? _role;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('fixed_role_source');

  @override
  Future<AgentRole?> producerRoleFor(String workItemId) async => _role;
}

/// A [GateEvaluator] that counts invocations and would fail if run — used to
/// prove the scoped gate does not even ask its inner evaluator to look at a
/// producer the gate does not apply to.
class _SpyGate implements GateEvaluator {
  int invocations = 0;

  @override
  String get gateType => 'triage-classification-structure';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    invocations++;
    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: QAGateStatus.failed,
      evidence: const [],
      evaluatedAt: DateTime.now(),
    );
  }
}

/// A gate that always passes, standing in for evaluators whose own verdicts
/// are not under test here.
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

/// The producer the drain asks about: a fixed execution id and result.
class _FixedProducerResolver implements ProducerResolver {
  _FixedProducerResolver(this._result);

  final AgentResult _result;

  @override
  Future<ResolvedProducer?> resolveFor(WorkItem item) async {
    return ResolvedProducer(
      executionId: 'exec-producer-scoped-test',
      result: _result,
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
  _Harness({required this.producerResult, required this.registry});

  final AgentResult producerResult;
  final GateRegistry registry;

  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final _InMemoryQAContractStore contractStore = _InMemoryQAContractStore();

  late final DurableWorkflowEngine engine = DurableWorkflowEngine(store: store);

  Future<void> seed(QAContract contract) async {
    await store.saveWorkItem(
      WorkItem(
        workItemId: _itemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A work item under its QA contract',
        state: WorkItemState.reviewApproved,
        qaContractId: contract.contractId,
        createdAt: DateTime.utc(2026, 10, 26),
        updatedAt: DateTime.utc(2026, 10, 26),
      ),
    );
    contractStore.hold(contract);
  }

  Future<QADrainResult> run() {
    return runQADrain(
      workflowEngine: engine,
      workflowStore: store,
      evaluationService: QAGateEvaluationService(
        orchestration: QAOrchestration(registry: registry),
        contractStore: contractStore,
      ),
      producerResolver: _FixedProducerResolver(producerResult),
    );
  }
}
