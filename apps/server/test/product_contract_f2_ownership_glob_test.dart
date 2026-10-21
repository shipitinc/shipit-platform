import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/qa/qa_drain.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ProducerResolution;
import 'package:path/path.dart' as p;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/gate_registry_over_doubles.dart';
import 'support/in_memory_qa_contract_store.dart';

/// The MEASUREMENT of the F2 ownership-glob hole, against the SHIPPED
/// manifest.
///
/// ## WHAT IS MEASURED, AND WHY IT IS MEASURED HERE
///
/// The shipped `shipit-platform` manifest declares the gate
/// `feature-change-scope-confined` with `"ownedPathGlobs": []`. The F2
/// evaluator refuses that declaration by design (§9 requirement gap 3): a gate
/// whose owned set is empty would fail every path — stricter, but useless —
/// and one that read empty as "all owned" would be a no-op; neither is
/// acceptable.
///
/// The refusal is a `FormatException` raised while the gate reads its own
/// config, which means the whole evaluation faults and NO gate results are
/// recorded. So a product-contract work item cannot reach `qaPassed` today,
/// and the platform says so by recording a fault.
///
/// This file proves that end to end, deterministically, with no database and
/// no live QA stack:
///
///   1. the shipped manifest really does declare an empty owned set — so the
///      hole is in the artefact an operator registers, not in a test fixture;
///   2. evaluating the contract DERIVED from that manifest raises the refusal
///      — so the hole is reachable through the real derivation, not only
///      through a hand-written gate;
///   3. the drain turns that refusal into a recorded FAULT on the work item —
///      so the platform's durable record distinguishes "the gates said no"
///      from "the gates never ran".
///
/// ## WHY THE SOURCES ARE DOUBLES HERE
///
/// The F2 refusal happens in the evaluator's config parse, BEFORE any source
/// is consulted — the gate never reaches the worktree. So the source bindings
/// cannot affect the outcome this file measures, and a test that asserted the
/// refusal over doubles is asserting the same thing the production adapter
/// would produce. Using doubles keeps the measurement hermetic; using the
/// production adapters would add a worktree and a database to prove a
/// behaviour that is decided four lines earlier.
///
/// ## WHAT THIS FILE DOES NOT CLAIM
///
/// It does not claim the hole is FIXED, and it does not populate the globs.
/// The globs are a product decision — which paths the feature lane owns —
/// and inventing them here would be the implementation deciding a product
/// question. The file measures the hole and pins the refusal, so that whoever
/// closes it closes a MEASURED defect.
void main() {
  final manifest = _shippedManifest();
  final contract = buildProductQAContract(
    spec: manifest.contracts.qaContract,
    productId: manifest.productId,
    workItemCategory: WorkItemCategory.feature,
    workItemId: 'WI-f2-measurement',
    manifestVersion: manifest.version,
    now: DateTime.utc(2026, 10, 21),
  );

  group('the shipped declaration carries the hole', () {
    test('the F2 gate declares an EMPTY owned set', () {
      final gate = contract.gates.firstWhere(
        (g) => g.gateId == 'feature-change-scope-confined',
      );
      expect(gate.type, 'change-scope-confinement');
      expect(
        gate.config['ownedPathGlobs'],
        isEmpty,
        reason:
            'the shipped manifest no longer declares an empty owned set, so the '
            'refusal below no longer happens and this measurement is stale. '
            'Re-measure: the hole may have been closed.',
      );
    });

    test('every OTHER declared gate type is registered, so F2 is the only '
        'unreachable gate', () {
      // The point of the measurement is attribution. If some other gate type
      // were also unregistered, "the contract faults" would not mean "the F2
      // declaration is the hole" — it would mean "several things are wrong".
      final registry = buildGateRegistryOverDoubles();
      final unregistered = contract.gates
          .where((gate) => registry.get(gate.type) == null)
          .map((gate) => '${gate.gateId} (${gate.type})')
          .toList();
      expect(
        unregistered,
        isEmpty,
        reason:
            'these declared gate types have no evaluator, so a contract that '
            'faults could not be attributed to the F2 declaration alone: '
            '$unregistered',
      );
    });
  });

  group('the evaluation of the shipped contract faults, and says why', () {
    test('the refusal is a FormatException naming the gate and the empty '
        'owned set', () async {
      final service = QAGateEvaluationService(
        orchestration: QAOrchestration(
          registry: buildGateRegistryOverDoubles(),
        ),
        contractStore: InMemoryQAContractStore(contract),
      );

      await expectLater(
        service.evaluateForWorkItem(
          workItemId: 'WI-f2-measurement',
          qaContractId: contract.contractId,
          agentResult: _agentResult(),
        ),
        throwsA(
          isA<QAGateEvaluationFault>().having(
            (fault) => fault.cause,
            'cause',
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('feature-change-scope-confined'),
                contains('ownedPathGlobs'),
              ),
            ),
          ),
        ),
      );
    });

    test('the fault aborts the WHOLE evaluation, so no other gate result '
        'exists', () async {
      // The R3 gate is FIRST in the shipped declaration and would have
      // produced a result. The fault is raised by the F2 gate, and the
      // orchestration does not collect partial results — so a contract that
      // faults carries no results at all. This is what makes the fault
      // distinguishable from a failing contract at the record level.
      final service = QAGateEvaluationService(
        orchestration: QAOrchestration(
          registry: buildGateRegistryOverDoubles(),
        ),
        contractStore: InMemoryQAContractStore(contract),
      );

      try {
        await service.evaluateForWorkItem(
          workItemId: 'WI-f2-measurement',
          qaContractId: contract.contractId,
          agentResult: _agentResult(),
        );
        fail('the evaluation was expected to fault');
      } on QAGateEvaluationFault catch (fault) {
        expect(fault.reason, contains('could not be completed'));
        expect(fault.cause, isA<FormatException>());
      }
    });
  });

  group('the drain records the hole as a FAULT on the work item', () {
    test('the item REACHES qaFailed with outcomeKind fault, and the cause '
        'names the empty owned set', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      const workItemId = 'WI-f2-measurement';
      await store.saveWorkItem(
        WorkItem(
          workItemId: workItemId,
          productId: 'shipit-platform',
          category: WorkItemCategory.feature,
          title: 'A work item governed by the shipped product contract',
          state: WorkItemState.reviewApproved,
          qaContractId: contract.contractId,
          createdAt: DateTime.utc(2026, 10, 21),
          updatedAt: DateTime.utc(2026, 10, 21),
        ),
      );

      final result = await runQADrain(
        workflowEngine: engine,
        workflowStore: store,
        evaluationService: QAGateEvaluationService(
          orchestration: QAOrchestration(
            registry: buildGateRegistryOverDoubles(),
          ),
          contractStore: InMemoryQAContractStore(contract),
        ),
        producerResolver: _FixedProducerResolver(_agentResult()),
      );

      expect(result.faulted, 1);
      expect(result.passed, 0);
      expect(result.failed, 0);

      // It REACHED `qaFailed` — the fault is recorded there — and the state it
      // rests in is the human gate, because `qaFailed` has no other edge out
      // and the drain raises the decision that opens it.
      final path = (await store.readTransitionHistory(
        workItemId,
      )).map((record) => record.toState).toList();
      expect(path, contains(WorkItemState.qaFailed));
      expect(path, isNot(contains(WorkItemState.qaPassed)));

      final item = await store.readWorkItem(workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);

      final record = item.metadata?['qaEvaluation'] as Map<String, dynamic>;
      expect(record['outcomeKind'], 'fault');
      expect(record['cause'], isA<String>());
      expect(record['cause'], contains('ownedPathGlobs'));
    });
  });
}

ProductManifest _shippedManifest() {
  final manifestFile = File(
    p.join(
      _findRepoRoot(),
      'apps/server/manifests/shipit-platform.product-manifest.json',
    ),
  );
  return ProductManifest.fromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'packages')).existsSync() &&
        Directory(p.join(dir.path, 'apps')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

AgentResult _agentResult() {
  return AgentResult(
    resultId: 'result-f2-measurement',
    sessionId: 'session-f2-measurement',
    workItemId: 'WI-f2-measurement',
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
      'classification': 'implementation_defect',
      'status': 'reported',
      'confidence': 0.9,
      'suspectedCategory': 'documentation',
    },
    completedAt: DateTime.utc(2026, 10, 21),
  );
}

/// A producer that always answers with the same result.
class _FixedProducerResolver implements ProducerResolver {
  _FixedProducerResolver(this._result);

  final AgentResult _result;

  @override
  Future<ResolvedProducer?> resolveFor(WorkItem item) async {
    return ResolvedProducer(
      executionId: 'exec-f2-measurement',
      result: _result,
      workingDirectory: '/tmp/does-not-exist',
      startingRevision: 'f58d6fb1',
      how: ProducerResolution.stampedProducer,
      note: 'the measurement producer',
    );
  }
}
