import 'package:control_plane_server/src/deploy/deploy_gate_sweep.dart';
import 'package:control_plane_server/src/endpoints/home_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show InMemoryJobStore;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;
import 'package:worker_runtime/worker_runtime.dart' show InMemoryWorkerStore;
import 'package:workflow_store/workflow_store.dart';

/// The deploy-gate sweep: `qa_passed` items auto-advance to the human they
/// were waiting for.
///
/// ## THE DEFECT THIS FILE HOLDS CLOSED — F-256
///
/// `pendingDecisions` — the Needs You surface — lists only items whose
/// `blockingHumanDecisionId` names an open decision. A `qa_passed` item
/// carried none: the deploy advance existed only as the manual
/// `advanceToDeploy` operator action, so a passed item parked invisibly
/// until a human opened its run detail. The sweep fires the same advance
/// every tick: `qaPassed -> deploying` on the artifact the producer's own
/// durable result builds, then `requestHumanDecision(deploymentApproval)`.
///
/// ## WHAT IS ASSERTED
///
///   1. a `qa_passed` item with a completed producer lands at
///      `waiting_for_human_decision` with a pending `deploymentApproval`;
///   2. the advance is idempotent — a re-tick mints nothing;
///   3. an item with no completed producer result stays `qa_passed`,
///      deferred honestly rather than failed;
///   4. an interrupted advance (`deploying` with no gate) is finished, not
///      re-transitioned;
///   5. Needs You (`pendingDecisions`) then surfaces the parked item.
///
/// ## WHY THE ENGINE IS THE REAL ONE
///
/// Same rule the QA drain's tests keep: the advance's legality is decided
/// by the workflow engine's guards — `artifactBuilt()` on the way into
/// `deploying`, `blockingHumanDecisionPendingOfType(deploymentApproval)` on
/// the way to a human — so a test that replaced the engine would be testing
/// the mock. This file drives the real [DurableWorkflowEngine] over the
/// real in-memory stores; only the persistence substrate is substituted.
void main() {
  late _Harness harness;
  late Session session;

  setUp(() {
    harness = _Harness();
    session = _FakeSession();
  });

  group('a qa_passed item is advanced to the human gate', () {
    test(
      'auto-advances: deploying, then waiting_for_human_decision with a '
      'pending deploymentApproval',
      () async {
        await harness.seedQaPassed(stampProducer: true);
        await harness.seedWorkerExecution();

        final result = await harness.run();

        expect(result.considered, 1);
        expect(result.advanced, 1);
        expect(result.gateRaised, 0);
        expect(result.deferred, 0);
        expect(result.faulted, 0);

        // The item is parked at the human gate, NOT deployed.
        final item = await harness.store.readWorkItem(_itemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(item.blockingHumanDecisionId, isNotNull);

        final decision = await harness.store.readHumanDecision(
          item.blockingHumanDecisionId!,
        );
        expect(decision.decisionType, HumanDecisionType.deploymentApproval);
        expect(decision.status, HumanDecisionStatus.pending);
        expect(decision.blocking, isTrue);
        expect(decision.decider, isNull);
        expect(
          decision.options!.map((option) => option.optionId),
          containsAll(<String>['approve', 'reject']),
        );
        expect(
          decision.metadata?['raisedBy'],
          'deploy_gate_sweep',
          reason:
              'the decision must name the machine raiser, so it cannot be '
              'mistaken for an operator\'s',
        );

        // The PATH, not only the end: qa_passed -> deploying -> the gate,
        // the edge taken as the sweep's own orchestrator actor.
        final history = await harness.store.readTransitionHistory(_itemId);
        final deploying = history.singleWhere(
          (record) => record.toState == WorkItemState.deploying,
        );
        expect(deploying.outcome, TransitionOutcome.accepted);
        expect(deploying.actorType, ActorType.orchestrator);
        expect(deploying.actorId, 'deploy-sweep');
        expect(deploying.idempotencyKey, 'deploy-sweep:$_itemId:advance:v1');

        // The artifact the guard was handed names the producer's commit.
        final artifact = harness.deploymentArtifacts.single;
        expect(artifact.manifest.gitCommit, 'c0ffee-prod');
        expect(artifact.manifest.metadata?['commitBasis'], 'producedCommit');
        expect(artifact.labels?['raisedBy'], 'deploy_gate_sweep');
        expect(decision.metadata?['deploymentArtifactId'], artifact.artifactId);
      },
    );

    test(
      'an UNSTAMPED producer falls back to the workspace base, never an '
      'invented revision',
      () async {
        await harness.seedQaPassed();

        final result = await harness.run();

        expect(result.advanced, 1);
        final artifact = harness.deploymentArtifacts.single;
        expect(
          artifact.manifest.metadata?['commitBasis'],
          'workspaceStartingRevision',
        );
        expect(artifact.manifest.gitCommit, 'base-abc');
      },
    );
  });

  group('the sweep is idempotent', () {
    test(
      'a second pass over the parked item mints nothing',
      () async {
        await harness.seedQaPassed();

        final first = await harness.run();
        final second = await harness.run();

        expect(first.advanced, 1);
        expect(
          second.considered,
          0,
          reason:
              'the item left qa_passed, so it is no longer a candidate; a '
              'sweep that advanced it twice would raise two decisions for '
              'one pass',
        );
        expect(second.advanced, 0);

        final decisions = await harness.store.readHumanDecisionsForWorkItem(
          _itemId,
        );
        expect(
          decisions.where(
            (d) => d.decisionType == HumanDecisionType.deploymentApproval,
          ),
          hasLength(1),
        );
        final history = await harness.store.readTransitionHistory(_itemId);
        expect(
          history.where((r) => r.toState == WorkItemState.deploying),
          hasLength(1),
        );
      },
    );

    test(
      'an item in a state the sweep does not own is not a candidate',
      () async {
        // In flight, not parked: the sweep owns `qa_passed` and the
        // gateless `deploying` strand — nothing else.
        await harness.store.saveWorkItem(
          _item(state: WorkItemState.agentExecuting),
        );

        final result = await harness.run();

        expect(result.considered, 0);
        expect(result.movedAnything, isFalse);
      },
    );
  });

  group('an item with nothing honest to deploy stays qa_passed', () {
    test('no producer execution at all is deferred, not failed', () async {
      await harness.seedQaPassed(withProducer: false);

      final result = await harness.run();

      expect(result.considered, 1);
      expect(result.deferred, 1);
      expect(result.advanced, 0);
      expect(result.faulted, 0);
      expect(result.outcomes.single.outcomeKind, 'deferred');

      final item = await harness.store.readWorkItem(_itemId);
      expect(
        item.state,
        WorkItemState.qaPassed,
        reason:
            'an item without a completed producer result stays qa_passed '
            'honestly — it is not advanced and it is not failed',
      );
      expect(
        await harness.store.readHumanDecisionsForWorkItem(_itemId),
        isEmpty,
      );
      expect(
        await harness.store.readTransitionHistory(_itemId),
        isEmpty,
        reason: 'a deferred item writes no transition record at all',
      );
    });

    test('a producer whose result never landed is deferred the same', () async {
      // The execution row exists but no result does — the platform could not
      // have read what the run produced.
      await harness.seedQaPassed(withResult: false);

      final result = await harness.run();

      expect(result.deferred, 1);
      expect(result.advanced, 0);
      expect(
        (await harness.store.readWorkItem(_itemId)).state,
        WorkItemState.qaPassed,
      );
    });
  });

  group('an interrupted advance is finished, not re-transitioned', () {
    test(
      'a crash between the transition and the raise is completed by the '
      'next pass',
      () async {
        // The two-durable-step gap: the `qa_passed -> deploying` write
        // committed and the process died before `deploymentApproval` was
        // raised. The item sits at `deploying` with no blocking decision —
        // the strand this arm exists for.
        await harness.seedQaPassed(stampProducer: true);
        final item = await harness.store.readWorkItem(_itemId);
        await harness.engine.transition(
          workItemId: _itemId,
          to: WorkItemState.deploying,
          trigger: TransitionTrigger.systemEvent,
          actor: deploySweepActor,
          context: {'deploymentArtifact': _testArtifact(item)},
          idempotencyKey: 'deploy-sweep:$_itemId:advance:v${item.version}',
        );
        expect(
          (await harness.store.readWorkItem(_itemId)).blockingHumanDecisionId,
          isNull,
        );

        final result = await harness.run();

        expect(result.considered, 1);
        expect(result.gateRaised, 1);
        expect(result.advanced, 0);
        expect(result.outcomes.single.outcomeKind, 'gate_raised');

        final parked = await harness.store.readWorkItem(_itemId);
        expect(parked.state, WorkItemState.waitingForHumanDecision);
        expect(parked.blockingHumanDecisionId, isNotNull);
        final decision = await harness.store.readHumanDecision(
          parked.blockingHumanDecisionId!,
        );
        expect(decision.decisionType, HumanDecisionType.deploymentApproval);
        expect(decision.status, HumanDecisionStatus.pending);

        // Exactly one `deploying` record — the interrupted advance's own.
        // A sweep that took the edge again would have recorded a second.
        final history = await harness.store.readTransitionHistory(_itemId);
        expect(
          history.where((r) => r.toState == WorkItemState.deploying),
          hasLength(1),
          reason: 'a partially-advanced item is finished, not re-transitioned',
        );
      },
    );

    test(
      'a parked item is not re-advanced: the sweep answers a gateless '
      'item, never a gated one',
      () async {
        await harness.seedQaPassed();
        await harness.run();

        // Sanity: parked, gated — and no longer a candidate.
        final second = await harness.run();
        expect(second.considered, 0);
        expect(
          (await harness.store.readWorkItem(_itemId)).state,
          WorkItemState.waitingForHumanDecision,
        );
      },
    );
  });

  group('the sweep never stacks an advance on live work', () {
    test('a non-terminal job defers the item to the next pass', () async {
      await harness.seedQaPassed();
      await harness.jobStore.saveJob(_job(_itemId, JobState.running));

      final result = await harness.run();

      expect(result.deferred, 1);
      expect(result.advanced, 0);
      expect(
        (await harness.store.readWorkItem(_itemId)).state,
        WorkItemState.qaPassed,
      );

      // The job finished; the next pass advances normally.
      await harness.jobStore.saveJob(
        _job(_itemId, JobState.succeeded),
      );
      final after = await harness.run();
      expect(after.advanced, 1);
      expect(
        (await harness.store.readWorkItem(_itemId)).state,
        WorkItemState.waitingForHumanDecision,
      );
    });
  });

  group('Needs You — the whole point', () {
    test(
      'pendingDecisions surfaces the parked item and its deploymentApproval',
      () async {
        await harness.seedQaPassed();
        await harness.run();

        final home = _TestHomeEndpoints(harness.store);
        final views = await home.pendingDecisions(session);

        final item = await harness.store.readWorkItem(_itemId);
        expect(views, hasLength(1));
        expect(views.single.decisionId, item.blockingHumanDecisionId);
      },
    );

    test(
      'a deferred item — no producer — surfaces nothing',
      () async {
        await harness.seedQaPassed(withProducer: false);
        await harness.run();

        final home = _TestHomeEndpoints(harness.store);
        expect(await home.pendingDecisions(session), isEmpty);
      },
    );
  });

  group("one item's failure cannot take the pass down with it", () {
    test('a deferred neighbour does not stop an advance', () async {
      await harness.seedQaPassed(workItemId: _bareItemId, withProducer: false);
      await harness.seedQaPassed(workItemId: _healthyItemId);

      final result = await harness.run();

      expect(result.considered, 2);
      expect(result.deferred, 1);
      expect(result.advanced, 1);
      expect(
        (await harness.store.readWorkItem(_bareItemId)).state,
        WorkItemState.qaPassed,
      );
      expect(
        (await harness.store.readWorkItem(_healthyItemId)).state,
        WorkItemState.waitingForHumanDecision,
      );
    });
  });
}

const _itemId = 'WI-deploy-1';
const _bareItemId = 'WI-deploy-bare';
const _healthyItemId = 'WI-deploy-healthy';

WorkItem _item({required WorkItemState state, String workItemId = _itemId}) {
  final now = DateTime.utc(2026, 10, 21);
  return WorkItem(
    workItemId: workItemId,
    productId: 'shipit-platform',
    category: WorkItemCategory.feature,
    title: 'A passed work item',
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}

/// The artifact a committed `qa_passed -> deploying` transition carried —
/// real enough for `artifactBuilt()` (a non-null DeploymentArtifact), built
/// here because the interrupted advance it simulates minted its own.
DeploymentArtifact _testArtifact(WorkItem item) => DeploymentArtifact(
  artifactId: 'artifact-deploy-${item.workItemId}-interrupted',
  contentHash: 'sha256-interrupted',
  manifest: ArtifactManifest(
    name: item.productId,
    version: 'c0ffee-prod',
    gitCommit: 'c0ffee-prod',
    files: const [],
    sbom: const SoftwareBillOfMaterials(
      format: 'CycloneDX',
      version: '1.5',
      components: [],
    ),
  ),
  builtAt: DateTime.utc(2026, 10, 21),
  builtBy: 'deploy-sweep',
);

/// A job in the given state. The id is stable in the item so a second
/// `saveJob` REPLACES the row — the job that finished is the job that was
/// running, not a second row alongside it.
Job _job(String workItemId, JobState state) => Job(
  jobId: 'jb-$workItemId',
  workItemId: workItemId,
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {},
  priority: JobPriority.normal,
  state: state,
  dedupeKey: '$workItemId:triage_defect',
  createdAt: DateTime.utc(2026),
  instruction: 'triage this defect',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

/// One sweep's worth of wiring.
class _Harness {
  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();
  final InMemoryWorkerStore workerStore = InMemoryWorkerStore();
  final InMemoryJobStore jobStore = InMemoryJobStore();
  final List<String> logEvents = [];

  /// The `DeploymentArtifact`s handed to transition contexts, captured the
  /// same way `work_item_action_endpoints_test.dart` does: the artifact is
  /// ephemeral by design — it satisfies `artifactBuilt()` and is never
  /// persisted — so the transition boundary is the only place it can be read.
  final List<DeploymentArtifact> deploymentArtifacts = [];

  late final DurableWorkflowEngine engine = _RecordingEngine(
    store: store,
    sink: deploymentArtifacts,
  );

  Future<DeploySweepResult> run() => runDeployGateSweep(
    workflowEngine: engine,
    workflowStore: store,
    executionStore: executionStore,
    workerStore: workerStore,
    jobStore: jobStore,
    log: (event, data) => logEvents.add(event),
  );

  /// A `qa_passed` work item, plus the completed implementer execution and
  /// completed result the artifact is built from.
  Future<void> seedQaPassed({
    String workItemId = _itemId,
    bool withProducer = true,
    bool withResult = true,
    bool stampProducer = false,
  }) async {
    await store.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A passed work item',
        state: WorkItemState.qaPassed,
        // The stamp `producedCommitFor` joins on: it names the producing
        // AGENT execution, and the matching worker execution carries it as
        // `agentExecutionId`.
        metadata: stampProducer ? const {'producerActorId': 'ex-prod'} : null,
        createdAt: DateTime.utc(2026, 10, 21),
        updatedAt: DateTime.utc(2026, 10, 21),
        version: 1,
      ),
    );
    if (!withProducer) return;
    await executionStore.saveExecution(
      AgentExecution(
        executionId: 'ex-prod',
        workItemId: workItemId,
        requestId: 'req-prod',
        runtimeTypeId: 'local',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-1',
          path: '/tmp/ws',
          startingRevision: 'base-abc',
        ),
        startedAt: DateTime.utc(2026),
      ),
    );
    if (!withResult) return;
    await executionStore.saveResult(
      'ex-prod',
      AgentResult(
        resultId: 'res-prod',
        sessionId: 'sess-prod',
        workItemId: workItemId,
        status: AgentResultStatus.completed,
        artifacts: const [
          AgentArtifact(
            artifactId: 'a-1',
            type: 'build',
            path: 'bin/app',
            sha256: 'deadbeef',
            sizeBytes: 42,
            mediaType: 'application/octet-stream',
          ),
        ],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 1,
          errors: [],
          warnings: [],
        ),
        structuredResult: const {},
        completedAt: DateTime.utc(2026),
      ),
    );
  }

  /// The worker execution `producedCommitFor` reads its `endingRevision`
  /// from — the `CommitProduced` arm.
  Future<void> seedWorkerExecution({
    String workItemId = _itemId,
    String endingRevision = 'c0ffee-prod',
  }) async {
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-prod',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: 'base-abc',
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: 'ex-prod',
        endingRevision: endingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );
  }
}

/// The REAL engine, with the same one observation
/// `work_item_action_endpoints_test.dart` adds: the `DeploymentArtifact` a
/// transition call carries in its context is recorded before the call runs.
/// The engine is the real one and every transition still runs through it;
/// recording substitutes nothing.
class _RecordingEngine extends DurableWorkflowEngine {
  _RecordingEngine({required super.store, required this.sink});

  final List<DeploymentArtifact> sink;

  @override
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = DurableWorkflowEngine.operatorRetryActor,
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
    String? reason,
    OperatorActionRecord? operatorAction,
    Map<String, dynamic>? metadataMerge,
  }) {
    final artifact = context['deploymentArtifact'];
    if (artifact is DeploymentArtifact) sink.add(artifact);
    return super.transition(
      workItemId: workItemId,
      to: to,
      trigger: trigger,
      actor: actor,
      context: context,
      decisionId: decisionId,
      idempotencyKey: idempotencyKey,
      reason: reason,
      operatorAction: operatorAction,
      metadataMerge: metadataMerge,
    );
  }
}

/// Drives the REAL `pendingDecisions` over the same in-memory store, so the
/// Needs You assertion reads the surface the operator reads — not a copy of
/// its rule re-asserted in a comment.
class _TestHomeEndpoints extends HomeEndpoints {
  _TestHomeEndpoints(this._store);

  final WorkflowStore _store;

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store);
}

class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store);

  final WorkflowStore _store;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  Future<List<Job>> listJobs() async => const [];

  @override
  Future<List<WorkerRegistration>> listWorkers() async => const [];

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async => const [];
}

/// A [Session] that records log lines and never touches a database.
class _FakeSession implements Session {
  final List<String> logs = [];

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}
