import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show InMemoryExecutionStore;
import 'package:path/path.dart' as p;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/gate_registry_over_doubles.dart';
import 'support/git_repo_fixture.dart';
import 'support/in_memory_qa_contract_store.dart';

/// THE DEMONSTRATION: F2 JUDGES THE CHANGE AGAINST WHAT THE LANE DECLARED.
///
/// ## WHAT THIS FILE MEASURES
///
/// Decision `4e1c9b52` closed a hole the shipped product contract still
/// carries: the change-scope gate (`feature-change-scope-confined`) declares
/// an EMPTY `ownedPathGlobs`, and an empty owned set is refused by design — so
/// every feature work item faults instead of being judged. The missing input
/// was the lane's own declared owned paths.
///
/// This file drives the WHOLE production path, in one process, over a real
/// git repository:
///
///   1. a real `AgentExecution` row carries the declaration in its own
///      metadata — the dispatch-time capture;
///   2. the PRODUCTION `ProductionDeclaredOwnedPathsSource` reads it back;
///   3. the PRODUCTION `ProductionChangeScopeSource` enumerates the committed
///      diff of a real repository;
///   4. the REAL `QAGateEvaluationService` supplies the declaration to the
///      change-scope gate and evaluates the SHIPPED gate declaration.
///
/// Then it states the two verdicts the decision promised:
///
///   * a lane that declared `lib/**` and committed INSIDE it → the gate
///     PASSES — the hole is closed for a lane that declared;
///   * a lane that declared `lib/**` and committed OUTSIDE it → the gate
///     FAILS, naming the offending path — the declaration is what the change
///     is judged against, not a convenience;
///   * a lane that declared NOTHING → the gate is REFUSED (a fault), not
///     passed — the fail-closed direction the decision preserved.
///
/// ## WHY THE CONTRACT IS THE SHIPPED ONE
///
/// The F2 gate's own declaration is taken verbatim from the shipped manifest
/// — including its empty `ownedPathGlobs` and its forbidden half — because a
/// demonstration over a hand-written gate would prove nothing about the
/// artefact an operator registers. The lane's declaration is the ONLY
/// difference between the two verdicts below.
///
/// The forbidden half is unchanged throughout: the lane's grant supplies the
/// OWNED set and nothing else, so a path that is forbidden stays forbidden
/// even when the lane declared everything.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ownership_demo_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('the lane declared, so the gate judges the change', () {
    test('a commit INSIDE the declared owned set PASSES the gate', () async {
      final lane = await _Lane.start(
        temp: temp,
        declaredOwnedPaths: const ['lib/**'],
        commit: ('lib/calculator.dart', 'int add(int a, int b) => a + b;\n'),
      );

      final outcome = await lane.evaluate();
      final gate = lane.f2Result(outcome);

      expect(
        gate.status,
        QAGateStatus.passed,
        reason:
            'the lane declared "lib/**" and touched only lib/, so the '
            'change is inside the grant',
      );
      expect(
        outcome.lanePathOwnership?['declaredOwnedPaths'],
        ['lib/**'],
        reason: 'the durable record must say WHICH declaration judged it',
      );
    });

    test('a commit OUTSIDE the declared owned set FAILS the gate, naming the '
        'path', () async {
      final lane = await _Lane.start(
        temp: temp,
        declaredOwnedPaths: const ['lib/**'],
        commit: ('docs/notes.md', 'a note the lane was not granted\n'),
      );

      final outcome = await lane.evaluate();
      final gate = lane.f2Result(outcome);

      expect(gate.status, QAGateStatus.failed);
      expect(
        gate.metadata?['reason'],
        contains('docs/notes.md'),
        reason: 'the verdict must name the path that was outside the grant',
      );
      expect(gate.metadata?['reason'], contains('matches no owned glob'));
      expect(
        (gate.evidence.single.content['unownedPaths'] as List).contains(
          'docs/notes.md',
        ),
        isTrue,
      );
    });

    test('a FORBIDDEN path stays forbidden even when the lane declared '
        'everything', () async {
      final lane = await _Lane.start(
        temp: temp,
        declaredOwnedPaths: const ['**'],
        commit: ('AGENTS.md', '# a forbidden file\n'),
      );

      final outcome = await lane.evaluate();
      final gate = lane.f2Result(outcome);

      expect(gate.status, QAGateStatus.failed);
      expect(gate.metadata?['reason'], contains('matches forbidden glob'));
    });
  });

  group('the lane declared nothing, so the gate refuses', () {
    test('the evaluation FAULTS instead of passing', () async {
      final lane = await _Lane.start(
        temp: temp,
        declaredOwnedPaths: const [],
        commit: ('lib/calculator.dart', 'int add(int a, int b) => a + b;\n'),
      );

      await expectLater(
        lane.evaluate(),
        throwsA(
          isA<QAGateEvaluationFault>()
              .having(
                (fault) => fault.reason,
                'reason',
                allOf(
                  contains('could not be completed'),
                  contains('declared no owned paths'),
                ),
              )
              .having(
                (fault) => fault.cause,
                'cause',
                isA<FormatException>(),
              ),
        ),
        reason:
            'a lane that was dispatched and granted nothing must fail '
            'closed, exactly as it did before the declaration existed',
      );
    });
  });
}

/// ONE LANE: a repository, the execution that produced the change, and the
/// evaluation of the shipped change-scope gate against it.
class _Lane {
  _Lane({
    required this.repo,
    required this.store,
    required this.workflowStore,
    required this.contract,
    required this.workItemId,
    required this.service,
  });

  final GitRepoFixture repo;
  final InMemoryExecutionStore store;
  final InMemoryWorkflowStore workflowStore;
  final QAContract contract;
  final String workItemId;
  final QAGateEvaluationService service;

  /// Builds a lane: a real repository, one real commit, one real execution
  /// row carrying the dispatch-time declaration, and the evaluation service
  /// wired to the PRODUCTION sources.
  static Future<_Lane> start({
    required Directory temp,
    required List<String> declaredOwnedPaths,
    required (String, String) commit,
  }) async {
    final repo = GitRepoFixture.create('${temp.path}/${_nextId()}');
    final startingRevision = repo.startingRevision;
    repo.commitFile(commit.$1, commit.$2);

    final store = InMemoryExecutionStore();
    final workflowStore = InMemoryWorkflowStore();

    const workItemId = 'WI-ownership-demonstration';
    const executionId = 'exec-ownership-demonstration';

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A lane that declared its owned paths',
        state: WorkItemState.reviewApproved,
        qaContractId: 'contract-ownership-demonstration',
        // The stamp the coordinator writes when the item reaches
        // `agentCompleted`: it names the execution that produced the change,
        // and it is what every QA source resolves the producer through.
        metadata: const {'producerActorId': executionId},
        createdAt: DateTime.utc(2026, 10, 21),
        updatedAt: DateTime.utc(2026, 10, 21),
      ),
    );

    await store.saveExecution(
      AgentExecution(
        executionId: executionId,
        workItemId: workItemId,
        requestId: 'req-ownership-demonstration',
        runtimeTypeId: 'fake-runtime',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(
          workspaceId: 'ws-ownership-demonstration',
          path: repo.root.path,
          startingRevision: startingRevision,
        ),
        startedAt: DateTime.utc(2026, 10, 21),
        completedAt: DateTime.utc(2026, 10, 21),
        // THE DISPATCH-TIME CAPTURE — exactly what the coordinator writes
        // into the execution row when the lane is dispatched.
        metadata: declaredOwnedPathsMetadata(declaredOwnedPaths),
      ),
    );

    final resolver = ProducerWorkspaceResolver(
      executionStore: store,
      workflowStore: workflowStore,
    );

    final contract = _shippedChangeScopeGate();

    final service = QAGateEvaluationService(
      orchestration: QAOrchestration(
        registry: buildGateRegistryOverDoubles(
          changeScopeSource: ProductionChangeScopeSource(resolver: resolver),
        ),
      ),
      contractStore: InMemoryQAContractStore(contract),
      declaredOwnedPathsSource: ProductionDeclaredOwnedPathsSource(
        resolver: resolver,
        executionStore: store,
      ),
    );

    return _Lane(
      repo: repo,
      store: store,
      workflowStore: workflowStore,
      contract: contract,
      workItemId: workItemId,
      service: service,
    );
  }

  Future<QAGateEvaluationOutcome> evaluate() => service.evaluateForWorkItem(
    workItemId: workItemId,
    qaContractId: contract.contractId,
    agentResult: _agentResult(workItemId),
  );

  /// The change-scope gate's own result.
  QAGateResult f2Result(QAGateEvaluationOutcome outcome) =>
      outcome.results.firstWhere(
        (result) => result.gateId == 'feature-change-scope-confined',
      );
}

int _idCounter = 0;

String _nextId() => 'lane_${++_idCounter}';

/// The SHIPPED change-scope gate declaration, verbatim from the shipped
/// manifest — including the empty owned set the lane's grant replaces and the
/// forbidden half nothing replaces.
QAContract _shippedChangeScopeGate() {
  final manifestFile = File(
    p.join(
      _findRepoRoot(),
      'apps/server/manifests/shipit-platform.product-manifest.json',
    ),
  );
  final manifest = ProductManifest.fromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final contract = buildProductQAContract(
    spec: manifest.contracts.qaContract,
    productId: manifest.productId,
    workItemCategory: WorkItemCategory.feature,
    workItemId: 'WI-ownership-demonstration',
    manifestVersion: manifest.version,
    now: DateTime.utc(2026, 10, 21),
  );
  final gate = contract.gates.firstWhere(
    (g) => g.gateId == 'feature-change-scope-confined',
  );
  return QAContract(
    contractId: 'contract-ownership-demonstration',
    workItemCategory: contract.workItemCategory,
    gates: [gate],
    version: contract.version,
    createdAt: contract.createdAt,
    updatedAt: contract.updatedAt,
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

AgentResult _agentResult(String workItemId) {
  return AgentResult(
    resultId: 'result-ownership-demonstration',
    sessionId: 'session-ownership-demonstration',
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
    structuredResult: const {
      'classification': 'implementation_defect',
      'status': 'reported',
      'confidence': 0.9,
      'suspectedCategory': 'documentation',
    },
    completedAt: DateTime.utc(2026, 10, 21),
  );
}
