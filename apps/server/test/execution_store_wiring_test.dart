import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show InMemoryWorkerStore, WorkerStore;
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// The composition root used to hand the execution coordinator a
/// `FileJsonExecutionStore` in container temp while every reader of an agent
/// execution read PostgreSQL. `agent_execution` therefore never had a row, and
/// the review gate could never read a producer's result.
///
/// Swapping the store is only safe if it cannot change which lane WINS the
/// `agentCompleted` race. That is the question this file answers, and it is
/// answered behaviourally rather than by asserting which class the composition
/// root constructs — an assertion of that shape passes just as happily against
/// a wiring that is still wrong.
///
/// The answer rests on ONE fact about the code under test:
/// `engineeringReviewMissingArtifact` evaluates its stand-down
/// (`_implementationInflowOwns`) BEFORE it reads the execution store, and that
/// stand-down consults only the `WorkerStore` and the work item's metadata. So
/// the stand-down's verdict is independent of which `ExecutionStore` is wired.
///
/// [_ExplodingExecutionStore] makes that structural rather than editorial: every
/// method throws, so any read of the execution store — now or after a future
/// refactor — fails the test loudly instead of silently changing an outcome.
const _startingRevision = '9f1c0a2b3d4e5f60718293a4b5c6d7e8f90a1b2c';

/// An [ExecutionStore] that refuses every operation.
///
/// The stand-down must not need one. A read that throws here proves the gate
/// reached a verdict before touching the store — which is exactly the property
/// that keeps the tick-order outcome independent of the wiring under test.
class _ExplodingExecutionStore implements ExecutionStore {
  final List<String> touched = <String>[];

  Never _boom(String operation) {
    touched.add(operation);
    throw StateError(
      'the stand-down must not read the execution store, but it called '
      '$operation',
    );
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(ExecutionStore store) body) =>
      _boom('inTransaction');

  @override
  Future<void> saveRequest(AgentExecutionRequest request) =>
      _boom('saveRequest');

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) =>
      _boom('readRequest');

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) => _boom('saveExecution');

  @override
  Future<AgentExecution> readExecution(String executionId) =>
      _boom('readExecution');

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) =>
      _boom('readExecutionOrNull');

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) =>
      _boom('listExecutions');

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) =>
      _boom('latestExecutionForWorkItem');

  @override
  Future<void> appendEvent(AgentEventRecord event) => _boom('appendEvent');

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) =>
      _boom('readEvents');

  @override
  Future<void> saveResult(String executionId, AgentResult result) =>
      _boom('saveResult');

  @override
  Future<AgentResult?> readResult(String executionId) => _boom('readResult');

  @override
  Future<void> saveVerification(PlatformVerification verification) =>
      _boom('saveVerification');

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) => _boom('readVerifications');
}

/// An [ExecutionStore] that is perfectly readable and holds nothing.
///
/// This, not the exploding store, is the state the wiring fix found in
/// production: `agent_execution` had zero rows, so every lookup resolved to
/// `null` without raising. [engineeringReviewMissingArtifact] could therefore
/// neither find a producer result nor report an error — it took the
/// `no-implementer-result` branch and returned, having done nothing at all.
/// Modelling that faithfully is the point: a store that THROWS would take a
/// different branch in the gate and would prove something else.
class _EmptyExecutionStore implements ExecutionStore {
  final List<String> touched = <String>[];

  @override
  Future<T> inTransaction<T>(Future<T> Function(ExecutionStore store) body) =>
      body(this);

  @override
  Future<void> saveRequest(AgentExecutionRequest request) async {}

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) async => null;

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {}

  @override
  Future<AgentExecution> readExecution(String executionId) async =>
      throw ExecutionNotFoundException(executionId);

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) async {
    touched.add('readExecutionOrNull');
    return null;
  }

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) async => [];

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) async {
    touched.add('latestExecutionForWorkItem');
    return null;
  }

  @override
  Future<void> appendEvent(AgentEventRecord event) async {}

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) async => [];

  @override
  Future<void> saveResult(String executionId, AgentResult result) async {}

  @override
  Future<AgentResult?> readResult(String executionId) async => null;

  @override
  Future<void> saveVerification(PlatformVerification verification) async {}

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async => [];
}

AgentResult _producerResult({required String workItemId}) => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: workItemId,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: const AgentDiagnostics(
    exitCode: 0,
    durationMs: 1,
    toolCalls: 1,
    errors: [],
    warnings: [],
  ),
  structuredResult: const {},
  summary: 'producer run',
  completedAt: DateTime.utc(2026, 1, 1),
);

/// The three durable records production assembles, assembled here the way
/// production assembles them — not hand-linked.
///
/// `LocalWorker._agentRequest` mints the anchor as
/// `'agx-${request.workerExecutionId}'`, records it on the worker execution,
/// and hands it to the coordinator as the request's execution id; the
/// coordinator stamps that same id onto the work item as `producerActorId`.
/// [_anchorFor] is that derivation, restated so a change to it in
/// `packages/worker_runtime` shows up as a failure here rather than as a
/// discriminator that silently stops resolving anything.
String _anchorFor(String workerExecutionId) => 'agx-$workerExecutionId';

class _Host {
  _Host._({
    required this.engine,
    required this.workflowStore,
    required this.workerStore,
    required this.executionStore,
    required this.job,
  });

  static Future<_Host> withProducer({
    required String workItemId,
    required String? endingRevision,
    required ExecutionStore executionStore,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final workerStore = InMemoryWorkerStore();
    final workerExecutionId = 'wx-$workItemId';
    final anchor = _anchorFor(workerExecutionId);
    final now = DateTime.utc(2026, 1, 1);

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'The item under dispute',
        description: 'A producer finished and left what it left.',
        state: WorkItemState.agentCompleted,
        metadata: {'producerActorId': anchor},
        createdAt: now,
        updatedAt: now,
      ),
    );
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: workerExecutionId,
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: _startingRevision,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: anchor,
        endingRevision: endingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    return _Host._(
      engine: DurableWorkflowEngine(store: workflowStore),
      workflowStore: workflowStore,
      workerStore: workerStore,
      executionStore: executionStore,
      job: Job(
        jobId: 'jb-$workItemId',
        workItemId: workItemId,
        jobType: JobType.engineeringReview,
        requiredRole: AgentRole.engineeringReviewer,
        requiredCapabilities: const {
          WorkerCapability.engineeringReview,
        },
        priority: JobPriority.normal,
        state: JobState.queued,
        dedupeKey: 'engineering-review:$workItemId',
        instruction: 'Review the produced artifact.',
        attempt: 0,
        maxAttempts: 1,
        version: 1,
        createdAt: now,
      ),
    );
  }

  final DurableWorkflowEngine engine;
  final InMemoryWorkflowStore workflowStore;
  final WorkerStore workerStore;
  final ExecutionStore executionStore;
  final Job job;

  Future<WorkItem> runMissingArtifact() async {
    await engineeringReviewMissingArtifact(
      workflowEngine: engine,
      executionStore: executionStore,
      workerStore: workerStore,
      job: job,
      logger: (_, __) {},
    );
    return engine.loadWorkItem(job.workItemId);
  }
}

void main() {
  group('the discriminator reaches a verdict on BOTH sides of the artifact', () {
    // The proof that is asked for directly: a producer execution WITH an
    // artifact discriminates as "commit produced", and one WITHOUT discriminates
    // as "no commit" — through the real resolver the scheduler dispatches from.
    test('a producer that committed resolves to the review workload', () async {
      final host = await _Host.withProducer(
        workItemId: 'wi-committed',
        endingRevision: 'a-real-commit',
        executionStore: _ExplodingExecutionStore(),
      );
      final item = await host.workflowStore.readWorkItem('wi-committed');

      final resolver = engineeringReviewWorkloadResolver(
        workerStore: host.workerStore,
        runtimeTypeId: 'rt-review',
      );
      final workload = await resolver(host.job, item);

      expect(
        workload,
        isNotNull,
        reason:
            'a commit that differs from the starting revision IS an artifact, '
            'and the anchor resolves without any agent execution row — this is '
            'the whole proof that the discriminator chain spans `worker_execution` '
            'and the work item metadata, and NOT the agent execution store',
      );
      expect(
        workload!.startingRevision,
        'a-real-commit',
        reason:
            'the resolver must point the reviewer at the PRODUCED revision, not '
            'at the revision the producer started from',
      );
    });

    test('a producer that committed nothing resolves to no workload', () async {
      // The measured shape of every real producer in the QA database: HEAD is
      // recorded either way, so an unchanged tree leaves `endingRevision` equal
      // to `requestedStartingRevision`.
      final host = await _Host.withProducer(
        workItemId: 'wi-triage',
        endingRevision: _startingRevision,
        executionStore: _ExplodingExecutionStore(),
      );
      final item = await host.workflowStore.readWorkItem('wi-triage');

      final resolver = engineeringReviewWorkloadResolver(
        workerStore: host.workerStore,
        runtimeTypeId: 'rt-review',
      );
      final workload = await resolver(host.job, item);

      expect(
        workload,
        isNull,
        reason:
            'a run that reached the revision it started from committed no code. '
            'It produced a report, not an artifact, and dispatching a reviewer '
            'against it would send a human to a revision nobody changed.',
      );
    });

    test(
      'a producer that recorded no ending revision resolves to no workload',
      () async {
        final host = await _Host.withProducer(
          workItemId: 'wi-null-rev',
          endingRevision: null,
          executionStore: _ExplodingExecutionStore(),
        );
        final item = await host.workflowStore.readWorkItem('wi-null-rev');

        final resolver = engineeringReviewWorkloadResolver(
          workerStore: host.workerStore,
          runtimeTypeId: 'rt-review',
        );

        expect(await resolver(host.job, item), isNull);
      },
    );
  });

  group('swapping the store cannot change which lane wins the race', () {
    test(
      'the stand-down decides WITHOUT reading the execution store, so the '
      'no-artifact item is still routed and never parked',
      () async {
        // THE tick-order question. `engineeringReviewMissingArtifact` evaluates
        // its stand-down before it reads the execution store, and the stand-down
        // consults only the worker store and the work item's metadata. So the
        // composition root's `executionStore: coordinator.store` — whatever it
        // resolves to, before or after the fix — cannot move this item.
        //
        // `_ExplodingExecutionStore` turns "does not read the store" from a
        // reading of the source into a fact this test enforces: any read throws.
        final store = _ExplodingExecutionStore();
        final host = await _Host.withProducer(
          workItemId: 'wi-stand-down',
          endingRevision: _startingRevision,
          executionStore: store,
        );

        final item = await host.runMissingArtifact();

        expect(
          item.state,
          WorkItemState.agentCompleted,
          reason:
              'the stand-down must return before the execution store is touched, '
              'leaving the item exactly where the implementation inflow finds it. '
              'Parking here would pre-empt the lane that can actually do the work.',
        );
        expect(
          item.blockingHumanDecisionId,
          isNull,
          reason:
              'no human gate may be raised for an item the platform routes.',
        );
        expect(
          store.touched,
          isEmpty,
          reason:
              'this is the assertion that makes the tick-order guarantee '
              'structural rather than a comment: if a future change makes the '
              'stand-down consult the execution store, the wiring under test '
              'starts deciding the race again and this fails.',
        );
      },
    );
  });

  group('the fail-closed park is reachable only once the store is readable', () {
    // The defect's other half. Before the wiring fix the producer's result could
    // not be read, so the park bailed on `no-implementer-result` and did nothing
    // — on every run, silently, for the items that exist to be parked.
    test(
      'with a READABLE store holding no row the gate bails and parks nothing',
      () async {
        // The exact production state the wiring fix found: `agent_execution`
        // empty, so the lookup answers `null` rather than raising. The gate
        // reaches `latestExecutionForWorkItem`, gets nothing, and returns
        // without transitioning or raising — the silent no-op that ran on every
        // tick, for every item review was supposed to be able to hand to a human.
        final store = _EmptyExecutionStore();
        final host = await _Host.withProducer(
          workItemId: 'wi-unreadable',
          endingRevision: 'a-real-commit',
          executionStore: store,
        );

        final item = await host.runMissingArtifact();

        expect(
          store.touched,
          contains('latestExecutionForWorkItem'),
          reason:
              'this branch must actually be reached, or the test is asserting '
              'nothing: the stand-down declined because a commit exists, so '
              'control reaches the producer-result lookup.',
        );
        expect(
          item.state,
          WorkItemState.agentCompleted,
          reason:
              'a commit exists and the inflow does not own the item, but '
              '`agentResultValid()` has nothing to check and forcing the '
              'transition would fabricate the evidence that guard exists to '
              'refuse. The gate leaves the item alone rather than invent a '
              'result — and, before the wiring fix, it did so silently on '
              'every run.',
        );
        expect(item.blockingHumanDecisionId, isNull);
      },
    );

    test(
      'with a readable producer result the gate transitions and raises the '
      'blocking decision',
      () async {
        final executionStore = InMemoryExecutionStore();
        final host = await _Host.withProducer(
          workItemId: 'wi-parkable',
          endingRevision: 'a-real-commit',
          executionStore: executionStore,
        );
        final anchor = _anchorFor('wx-wi-parkable');
        final now = DateTime.utc(2026, 1, 1);
        await executionStore.saveExecution(
          AgentExecution(
            executionId: anchor,
            workItemId: 'wi-parkable',
            requestId: 'req-1',
            runtimeTypeId: 'rt-impl',
            role: AgentRole.implementer,
            status: AgentSessionStatus.completed,
            sessionId: 'ses-1',
            resultId: 'res-1',
            workspace: const AgentWorkspace(
              workspaceId: 'ws-1',
              path: '/durable/clone',
              startingRevision: _startingRevision,
            ),
            startedAt: now,
            completedAt: now,
          ),
        );
        await executionStore.saveResult(
          anchor,
          _producerResult(workItemId: 'wi-parkable'),
        );

        final item = await host.runMissingArtifact();

        expect(
          item.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'a commit exists AND the producer\'s completed result is readable, '
              'so the entry transition\'s `agentResultValid()` guard passes and '
              'the item is handed to a human. This is the park the wiring fix '
              'restores; with the file store it was unreachable.',
        );
        expect(
          item.blockingHumanDecisionId,
          isNotNull,
          reason: 'the park must reference the decision it raised.',
        );
      },
    );
  });
}
