import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/implementation/implementation_path_ownership.dart';
import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, InMemoryExecutionStore;
import 'package:path/path.dart' as p;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:scheduler/scheduler.dart' show SchedulerWorkload;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/gate_registry_over_doubles.dart';
import 'support/git_repo_fixture.dart';
import 'support/in_memory_qa_contract_store.dart';

/// THE GRANT HAS A PRODUCER, AND THIS FILE DRIVES IT.
///
/// ## WHAT THIS FILE MEASURES
///
/// Ledger F-215: *"no production writer supplies a grant, so F2 still refuses
/// every production evaluation."* The read half of the grant existed — the
/// dispatch-time capture, the durable execution record, the QA source, the
/// gate — and every one of them read a value that nothing ever wrote. So the
/// gate refused every production evaluation, and it refused them correctly:
/// an empty owned set is refused by design.
///
/// This file closes the gap by driving the WRITER, and then driving everything
/// downstream of it in one process:
///
///   1. the PRODUCTION `ControlPlaneService.requestDesignApproval` — the
///      design/plan submission, carrying the scoping lane's declaration;
///   2. the PRODUCTION `ControlPlaneService.resolveHumanDecision` — the
///      human-governed acceptance, which promotes the declaration onto the work
///      item;
///   3. the PRODUCTION `implementationRequestWithPathOwnership` — the dispatch
///      reader the composition root calls;
///   4. the PRODUCTION capture helper, the PRODUCTION
///      `ProductionDeclaredOwnedPathsSource`, and the REAL shipped
///      change-scope gate, over a REAL git repository.
///
/// ## WHY THE GRANT IS NOT HAND-BUILT HERE
///
/// This is the trap F-216 records: a test that builds the grant's metadata by
/// hand proves only that the READER reads what the test wrote. Every grant
/// below is produced by the production writer from a DECLARATION made by a
/// named scoping lane, and the test asserts the whole chain — declaration,
/// acceptance, grant, dispatch, capture, gate verdict.
///
/// The one thing this file does NOT fake is the gate declaration: it is read
/// verbatim from the shipped manifest, empty `ownedPathGlobs` and forbidden
/// half included, because a verdict over a hand-written gate would prove
/// nothing about the artefact an operator registers.
///
/// ## WHY THE EMPTY CASE IS ASSERTED FIRST-CLASS
///
/// A lane that declared nothing must still be REFUSED. If the writer could
/// turn an absent declaration into a grant, this file's first test would pass
/// and the gate would stop confining anything.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('design_scope_grant_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('the production writer records the grant', () {
    test(
      'the design/plan submission carries the scoping lane declaration',
      () async {
        final host = await _Host.start(temp: temp);

        final decision = await host.service.requestDesignApproval(
          workItemId: host.workItemId,
          declaredOwnedPaths: const ['lib/**'],
          question: 'Is this plan scoped to the paths it will touch?',
          declaredBy: 'design-lane',
        );

        expect(
          declaredOwnedPathsFromMetadata(decision.metadata),
          ['lib/**'],
          reason:
              'the DECISION must carry the declaration, because the decision is '
              'the human-governed record of what the scoping lane proposed',
        );
        expect(
          decision.metadata?['designScopeDeclaration'],
          isA<Map>(),
          reason: 'the declaration must carry its provenance',
        );
      },
    );

    test(
      'the acceptance promotes the declaration onto the work item',
      () async {
        final host = await _Host.start(temp: temp);

        final decision = await host.service.requestDesignApproval(
          workItemId: host.workItemId,
          declaredOwnedPaths: const ['lib/**'],
          question: 'Is this plan scoped to the paths it will touch?',
          declaredBy: 'design-lane',
        );
        final item = await host.accept(decision.decisionId);

        expect(
          item.state,
          WorkItemState.designApproved,
          reason: 'the plan was accepted, so the item moves on',
        );
        expect(
          declaredOwnedPathsFromMetadata(item.metadata),
          ['lib/**'],
          reason:
              'the GRANT is a durable fact of the work item, written by the '
              'production writer at the acceptance',
        );
      },
    );

    test(
      'the grant carries its provenance and does not erase the plan',
      () async {
        final host = await _Host.start(temp: temp);

        final decision = await host.service.requestDesignApproval(
          workItemId: host.workItemId,
          declaredOwnedPaths: const ['lib/**'],
          question: 'Is this plan scoped to the paths it will touch?',
          declaredBy: 'design-lane',
        );
        final item = await host.accept(decision.decisionId);

        final provenance = item.metadata?['designScopeGrant'];
        expect(provenance, isA<Map>());
        expect((provenance as Map)['declaredBy'], 'design-lane');
        expect(provenance['decisionId'], decision.decisionId);
        expect(provenance['decisionType'], 'design_approval');
        expect(provenance['grantedAt'], isA<String>());

        expect(
          item.metadata?['acceptanceCriteria'],
          'the plan survives the promotion',
          reason:
              'the work item metadata carries the plan, the producer identity '
              'and the triage marker; a promotion that replaced the map would '
              'erase the plan the implementation lane is about to be given',
        );
        expect(
          item.metadata?['producerActorId'],
          _executionId,
          reason: 'the producer identity must survive the promotion too',
        );
      },
    );

    test('a REJECTED plan records no grant', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const ['lib/**'],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.resolve(
        decision.decisionId,
        HumanDecisionChoice.reject,
      );

      expect(item.state, WorkItemState.designRejected);
      expect(
        declaredOwnedPathsFromMetadata(item.metadata),
        isEmpty,
        reason:
            'a rejected plan is not an acceptance, so no grant is recorded — '
            'the gate must keep refusing this lane',
      );
    });

    test('an accepted plan that declared NOTHING records no grant', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const [],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      expect(item.state, WorkItemState.designApproved);
      expect(
        declaredOwnedPathsFromMetadata(item.metadata),
        isEmpty,
        reason:
            'an empty declaration is the ABSENCE of a grant, not a grant of '
            'nothing: the item stays refused, which is the fail-closed '
            'direction decision 7d2a81f0 preserved',
      );
      expect(
        item.metadata?['designScopeGrant'],
        isNull,
        reason: 'nothing was granted, so there is no grant to have provenance',
      );
    });

    test(
      'the design-time scope REPLACES a scope an earlier step recorded',
      () async {
        // An item that arrived carrying a scope from an earlier step — the
        // intake form, whose requester does not know the path layout — must not
        // keep it after the design/plan acceptance. Otherwise the effective
        // grant would still originate at intake, and decision 7d2a81f0 would not
        // have been implemented at all.
        final host = await _Host.start(temp: temp, earlierScope: const ['**']);

        final decision = await host.service.requestDesignApproval(
          workItemId: host.workItemId,
          declaredOwnedPaths: const ['lib/**'],
          question: 'Is this plan scoped to the paths it will touch?',
          declaredBy: 'design-lane',
        );
        final item = await host.accept(decision.decisionId);

        expect(
          declaredOwnedPathsFromMetadata(item.metadata),
          ['lib/**'],
          reason: 'the design/plan acceptance is where the scope is authored',
        );
      },
    );

    test('an empty design-time scope CLEARS an earlier scope', () async {
      final host = await _Host.start(temp: temp, earlierScope: const ['**']);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const [],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      expect(
        declaredOwnedPathsFromMetadata(item.metadata),
        isEmpty,
        reason:
            'a designer who scoped nothing leaves the item with nothing. A '
            'scope that an earlier step guessed is not the grant, and leaving '
            'it would make the gate a tautology for whoever guessed widest',
      );
    });
  });

  group('the grant reaches the dispatch request', () {
    test('the production dispatch reader finds the grant', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const ['lib/**'],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      final request = await implementationRequestWithPathOwnership(
        _job(),
        _workload(),
        item,
        null,
      );

      expect(
        request.declaredOwnedPaths,
        ['lib/**'],
        reason:
            'this is the dispatch-time boundary the composition root calls: '
            'the work item carries the grant and the request carries it to '
            'the worker',
      );
    });

    test('an ungranted lane dispatches with NO grant', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const [],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      final request = await implementationRequestWithPathOwnership(
        _job(),
        _workload(),
        item,
        null,
      );

      expect(
        request.declaredOwnedPaths,
        isEmpty,
        reason:
            'the platform does not invent a grant at dispatch: an ungranted '
            'lane stays ungranted, and the gate refuses it',
      );
    });
  });

  group('the gate judges the change against the grant', () {
    test('a change INSIDE the grant PASSES the shipped gate', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const ['lib/**'],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      final request = await implementationRequestWithPathOwnership(
        _job(),
        _workload(),
        item,
        null,
      );

      final outcome = await host.evaluate(
        request.declaredOwnedPaths,
        commit: ('lib/calculator.dart', 'int add(int a, int b) => a + b;\n'),
      );
      final gate = outcome.results.firstWhere(
        (result) => result.gateId == 'feature-change-scope-confined',
      );

      expect(
        gate.status,
        QAGateStatus.passed,
        reason:
            'the scoping lane declared "lib/**" through the production writer, '
            'the change is inside it, and the shipped gate passes it',
      );
      expect(outcome.lanePathOwnership?['declaredOwnedPaths'], ['lib/**']);
    });

    test('a change OUTSIDE the grant FAILS the shipped gate', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const ['lib/**'],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      final request = await implementationRequestWithPathOwnership(
        _job(),
        _workload(),
        item,
        null,
      );

      final outcome = await host.evaluate(
        request.declaredOwnedPaths,
        commit: ('docs/notes.md', 'a note the lane was not granted\n'),
      );
      final gate = outcome.results.firstWhere(
        (result) => result.gateId == 'feature-change-scope-confined',
      );

      expect(gate.status, QAGateStatus.failed);
      expect(gate.metadata?['reason'], contains('docs/notes.md'));
    });

    test('a lane that was granted NOTHING is REFUSED, not passed', () async {
      final host = await _Host.start(temp: temp);

      final decision = await host.service.requestDesignApproval(
        workItemId: host.workItemId,
        declaredOwnedPaths: const [],
        question: 'Is this plan scoped to the paths it will touch?',
        declaredBy: 'design-lane',
      );
      final item = await host.accept(decision.decisionId);

      final request = await implementationRequestWithPathOwnership(
        _job(),
        _workload(),
        item,
        null,
      );

      await expectLater(
        host.evaluate(
          request.declaredOwnedPaths,
          commit: ('lib/calculator.dart', 'int add(int a, int b) => a + b;\n'),
        ),
        throwsA(
          isA<QAGateEvaluationFault>().having(
            (fault) => fault.reason,
            'reason',
            allOf(
              contains('could not be completed'),
              contains('declared no owned paths'),
            ),
          ),
        ),
        reason:
            'the fail-closed direction must survive the writer: a lane that '
            'declared nothing is still refused, exactly as it was before a '
            'writer existed',
      );
    });
  });
}

/// THE HOST: the production service over an in-memory durable substrate, plus
/// the repository the gate reads.
class _Host {
  _Host({
    required this.temp,
    required this.service,
    required this.workflowStore,
    required this.executionStore,
    required this.workItemId,
    required this.repo,
  });

  final Directory temp;
  final _TestService service;
  final InMemoryWorkflowStore workflowStore;
  final InMemoryExecutionStore executionStore;
  final String workItemId;
  final GitRepoFixture repo;

  /// Builds a host: a work item parked at the design review, a real
  /// repository, and the production service over both in-memory stores.
  ///
  /// [earlierScope] is a scope an EARLIER step recorded on the item — the
  /// intake form's guess. It is there so the design-time scope can be shown
  /// to replace it rather than to be added to it.
  static Future<_Host> start({
    required Directory temp,
    List<String> earlierScope = const [],
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final executionStore = InMemoryExecutionStore();
    final repo = GitRepoFixture.create('${temp.path}/repo');

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: _workItemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A lane that scoped its own paths',
        state: WorkItemState.designInReview,
        qaContractId: _contractId,
        metadata: {
          'producerActorId': _executionId,
          'acceptanceCriteria': 'the plan survives the promotion',
          ...declaredOwnedPathsMetadata(earlierScope),
        },
        createdAt: _at(),
        updatedAt: _at(),
      ),
    );

    return _Host(
      temp: temp,
      service: _TestService(
        _FakeSession(),
        workflowStore,
        executionStore,
      ),
      workflowStore: workflowStore,
      executionStore: executionStore,
      workItemId: _workItemId,
      repo: repo,
    );
  }

  /// Resolves the pending decision with [choice].
  Future<WorkItem> resolve(
    String decisionId,
    HumanDecisionChoice choice,
  ) {
    return service.resolveHumanDecision(
      decisionId: decisionId,
      choice: choice,
      decider: 'human-operator',
      rationale: 'the plan was reviewed by a human',
      signature: _signature(),
    );
  }

  /// Resolves the pending decision as an ACCEPTANCE.
  Future<WorkItem> accept(String decisionId) =>
      resolve(decisionId, HumanDecisionChoice.approve);

  /// Evaluates the SHIPPED change-scope gate against a commit, with the
  /// lane's grant taken from [declaredOwnedPaths].
  ///
  /// The grant reaches the gate the way it reaches it in production: the
  /// dispatch capture writes it into the execution row, and the production
  /// source reads it back.
  Future<QAGateEvaluationOutcome> evaluate(
    List<String> declaredOwnedPaths, {
    required (String, String) commit,
  }) async {
    final startingRevision = repo.startingRevision;
    repo.commitFile(commit.$1, commit.$2);

    await executionStore.saveExecution(
      AgentExecution(
        executionId: _executionId,
        workItemId: workItemId,
        requestId: 'req-design-scope-grant',
        runtimeTypeId: 'fake-runtime',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(
          workspaceId: 'ws-design-scope-grant',
          path: repo.root.path,
          startingRevision: startingRevision,
        ),
        startedAt: _at(),
        completedAt: _at(),
        // THE DISPATCH-TIME CAPTURE — the production helper, fed with the
        // declaration the production dispatch reader found.
        metadata: declaredOwnedPathsMetadata(declaredOwnedPaths),
      ),
    );

    final resolver = ProducerWorkspaceResolver(
      executionStore: executionStore,
      workflowStore: workflowStore,
    );

    final service = QAGateEvaluationService(
      orchestration: QAOrchestration(
        registry: buildGateRegistryOverDoubles(
          changeScopeSource: ProductionChangeScopeSource(resolver: resolver),
        ),
      ),
      contractStore: InMemoryQAContractStore(_shippedChangeScopeGate()),
      declaredOwnedPathsSource: ProductionDeclaredOwnedPathsSource(
        resolver: resolver,
        executionStore: executionStore,
      ),
    );

    return service.evaluateForWorkItem(
      workItemId: workItemId,
      qaContractId: _contractId,
      agentResult: _agentResult(workItemId),
    );
  }
}

/// [ControlPlaneService] with its durable substrate substituted, so the
/// PRODUCTION `requestDesignApproval` and `resolveHumanDecision` run for real.
/// The same shape `engineering_review_verdict_absent_decision_test.dart` uses.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store, this._executions);

  final WorkflowStore _store;
  final ExecutionStore _executions;
  final DesignGovernanceStore _designGovernance =
      InMemoryDesignGovernanceStore();

  @override
  WorkflowStore get workflowStore => _store;

  @override
  ExecutionStore get executionStore => _executions;

  @override
  DesignGovernanceStore get designGovernanceStore => _designGovernance;

  @override
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: _store);
}

class _FakeSession implements Session {
  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}

const String _workItemId = 'WI-design-scope-grant';
const String _executionId = 'exec-design-scope-grant';
const String _contractId = 'contract-design-scope-grant';

DateTime _at() => DateTime.utc(2026, 10, 22);

Job _job() => Job(
  jobId: 'job-design-scope-grant',
  workItemId: _workItemId,
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux},
  priority: JobPriority.normal,
  state: JobState.queued,
  dedupeKey: 'dedupe-design-scope-grant',
  createdAt: _at(),
  instruction: 'implement the thing',
  attempt: 1,
  maxAttempts: 3,
  version: 1,
);

SchedulerWorkload _workload() => const SchedulerWorkload(
  repositoryPath: '/repo',
  startingRevision: 'abc123',
  timeoutSeconds: 900,
  runtimeTypeId: 'opencode',
);

DecisionSignature _signature() => DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'test-public-key',
  signature: 'test-signature',
  signedAt: _at(),
);

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
    workItemId: _workItemId,
    manifestVersion: manifest.version,
    now: _at(),
  );
  final gate = contract.gates.firstWhere(
    (g) => g.gateId == 'feature-change-scope-confined',
  );
  return QAContract(
    contractId: _contractId,
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
    resultId: 'result-design-scope-grant',
    sessionId: 'session-design-scope-grant',
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
    completedAt: _at(),
  );
}
