import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show InMemoryWorkerStore, WorkerStore;
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:control_plane_server/server.dart';

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
/// The one property no harness here can reach is the CALL SITE itself: every
/// test in this file injects its own store, and `run()` cannot be entered from
/// a unit test. That is pinned separately, from the source text, and it pins
/// the BINDING rather than the type — see the group at the end of this file,
/// which is the difference between an assertion that rotted and one that would
/// have caught it.
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
        // The one production budget, named so the resolver holds no literal of
        // its own. See `AgentExecutionBudgets` — PROVISIONAL.
        timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
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
        // The one production budget, named so the resolver holds no literal of
        // its own. See `AgentExecutionBudgets` — PROVISIONAL.
        timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
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
          // The one production budget, named so the resolver holds no literal of
          // its own. See `AgentExecutionBudgets` — PROVISIONAL.
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
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
        // reaches the producer lookup, gets nothing, and returns without
        // transitioning or raising — the silent no-op that ran on every tick,
        // for every item review was supposed to be able to hand to a human.
        final store = _EmptyExecutionStore();
        final host = await _Host.withProducer(
          workItemId: 'wi-unreadable',
          endingRevision: 'a-real-commit',
          executionStore: store,
        );

        final item = await host.runMissingArtifact();

        expect(
          store.touched,
          contains('readExecutionOrNull'),
          reason:
              'this branch must actually be reached, or the test is asserting '
              'nothing: the stand-down declined because a commit exists, so '
              'control reaches the producer-result lookup. It reads the '
              'producerActorId the work item carries — a primary-key read — '
              'rather than `latestExecutionForWorkItem`, which was the '
              'role-blind lookup this finding was raised about.',
        );
        expect(
          store.touched,
          isNot(contains('latestExecutionForWorkItem')),
          reason:
              'the role-blind lookup must not be reachable from here at all. It '
              'is correct exactly once — for the first review of an item — and '
              'wrong for every review after, because the REVIEWER is then the '
              'newest row and its result would be handed to `agentResultValid()` '
              'as evidence that an implementer succeeded. That is '
              '`docs/engineering/learning/236-transition-rows-that-moved-'
              'nothing.md` §2, and it was recorded here as NOT RESOLVED.',
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
      'the producer lookup is by IDENTITY, not recency: a reviewer NEWER than '
      'the implementer is not read as the producer',
      () async {
        // The defect `236-…md` §2 measured, reproduced at the call site this
        // finding was raised about. Two executions on one item: the
        // implementer (older, completed, the one the item's `producerActorId`
        // names) and a reviewer (newer, FAILED, carrying a failed result).
        //
        // Under the old role-blind lookup the gate read the REVIEWER — the
        // newest row of any role — and handed `agentResultValid()` its failed
        // result, so the entry transition was refused and the item could never
        // reach a human no matter how many times it was tried. `resolveProducerExecution`
        // reads the stamp first, so the implementer's completed result is what
        // the guard sees and the park happens.
        //
        // NON-VACUITY: the reviewer here carries a RESULT. Without it the old
        // lookup would also have answered `null` and this test would pass for
        // the wrong reason.
        final executionStore = InMemoryExecutionStore();
        const workItemId = 'wi-recency';
        final host = await _Host.withProducer(
          workItemId: workItemId,
          endingRevision: 'a-real-commit',
          executionStore: executionStore,
        );
        final anchor = _anchorFor('wx-$workItemId');
        final earlier = DateTime.utc(2026, 1, 1);
        final later = earlier.add(const Duration(hours: 3));

        await executionStore.saveExecution(
          AgentExecution(
            executionId: anchor,
            workItemId: workItemId,
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
            startedAt: earlier,
            completedAt: earlier,
          ),
        );
        await executionStore.saveResult(
          anchor,
          _producerResult(workItemId: workItemId),
        );

        // The newer row, and it is a reviewer that FAILED — the exact shape
        // `236-…md` §2 measured on QA.
        await executionStore.saveExecution(
          AgentExecution(
            executionId: 'agx-wx-review-2',
            workItemId: workItemId,
            requestId: 'req-2',
            runtimeTypeId: 'eng-review-runtime',
            role: AgentRole.engineeringReviewer,
            status: AgentSessionStatus.failed,
            sessionId: 'ses-2',
            resultId: 'res-2',
            workspace: const AgentWorkspace(
              workspaceId: 'ws-2',
              path: '/worktrees/review',
              startingRevision: _startingRevision,
            ),
            startedAt: later,
            completedAt: later,
          ),
        );
        await executionStore.saveResult(
          'agx-wx-review-2',
          AgentResult(
            resultId: 'res-2',
            sessionId: 'ses-2',
            workItemId: workItemId,
            executionId: 'agx-wx-review-2',
            role: AgentRole.engineeringReviewer,
            // FAILED. `agentResultValid()` requires `completed`, so reading
            // THIS row is what made the edge unsatisfiable.
            status: AgentResultStatus.failed,
            artifacts: const [],
            diagnostics: const AgentDiagnostics(
              exitCode: 1,
              durationMs: 1,
              toolCalls: 0,
              errors: [],
              warnings: [],
            ),
            structuredResult: const {},
            summary: 'the reviewer failed',
            completedAt: later,
          ),
        );

        // The premise, stated: the role-blind lookup really does return the
        // failed reviewer here. If it did not, this test would be proving
        // nothing about recency.
        expect(
          (await executionStore.latestExecutionForWorkItem(
            workItemId,
          ))!.executionId,
          'agx-wx-review-2',
          reason:
              'the newest row of ANY role is the reviewer. This is the read the '
              'gate used to make, and the reason a second review of this item '
              'could never enter review.',
        );

        final item = await host.runMissingArtifact();

        expect(
          item.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'the item is `agentCompleted` because an IMPLEMENTER ran and '
              'succeeded, so the evidence `agentResultValid()` exists to read is '
              'the implementer\'s result. A reviewer failing afterwards must not '
              'retroactively un-produce the work.',
        );
        expect(
          item.blockingHumanDecisionId,
          isNotNull,
          reason: 'so the item reaches a person instead of self-locking',
        );
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

  group('the production composition binds the coordinator to the named seam', () {
    // ## WHY THIS FILE NEEDS A SOURCE-TEXT ASSERTION AT ALL
    //
    // Every other test here proves a property of the code UNDER TEST. None of
    // them proves that the production composition reaches that code. The
    // round-trip suite calls `agentExecutionStore(db)` itself; every harness in
    // this file injects its own store. `run()` is the one place the real wiring
    // is decided, and it needs a live database, a live `opencode` binary and a
    // worker registry — so it cannot be entered from a unit test at all.
    //
    // The consequence, which is the entire reason this group exists: reverting
    // `server.dart` to
    //
    //     store: FileJsonExecutionStore(
    //       File('${Directory.systemTemp.path}/execution_coordinator/store.json'),
    //     ),
    //
    // leaves the WHOLE suite green. A writer and a reader each satisfied
    // `ExecutionStore`, were wired to different instances, and no type, no
    // behavioural test and no integration test could see it — which is how
    // `agent_execution` stayed at zero rows across 35 worker executions while
    // every test in the repository passed.
    //
    // ## THIS IS NOT THE "ASSERT THE CLASS" ANTI-PATTERN. DO NOT SIMPLIFY IT.
    //
    // The anti-pattern — and the one this file's own header rejects — asserts
    // WHICH CLASS was constructed, e.g. `agentExecutionStore(db) is
    // PostgresExecutionStore`. That passes against a wiring that is still
    // wrong, and would have passed against the file store too, because it never
    // looks at the call site. It pins a TYPE.
    //
    // What follows pins a BINDING: that the `store:` argument of the one
    // `buildTriageExecutionCoordinator(` call inside `run()` is the seam, on the
    // same `db` every other Postgres store in that function already uses. The
    // type is still free to change; what may not change is that the production
    // composition and the tests' seam resolve to the same place. That is
    // exactly the thing which rotted, so it is the thing that is pinned.
    //
    // Read as text for the same reason `implementation_inflow_tick_order_test`
    // reads `lib/server.dart` as text: what is pinned here is not observable
    // from any in-process harness.
    late String source;

    setUpAll(() {
      source = File('lib/server.dart').readAsStringSync();
    });

    test(
      'the coordinator `run()` builds is bound to `agentExecutionStore(db)`',
      () {
        final call = _coordinatorCallInRun(source);

        expect(
          call,
          contains('store: agentExecutionStore(db)'),
          reason:
              'the coordinator `run()` builds must write through the SAME seam '
              'the integration suite drives. If `run()` hands it any other '
              'ExecutionStore, agent executions land where no reader looks and '
              'every test in this repository still passes — the exact defect '
              'this assertion exists to make impossible to reintroduce '
              'silently.',
        );
        expect(
          call,
          isNot(contains('FileJsonExecutionStore')),
          reason:
              'the belt to those braces. `FileJsonExecutionStore` is named in '
              'the comment above the call and in the `agentExecutionStore` doc '
              'comment, which is why this asserts on the call text and not on '
              'the whole file: inside the parentheses it can only mean the '
              'production wiring names it.',
        );
      },
    );
  });
}

/// Returns the source text of the single `buildTriageExecutionCoordinator(` CALL
/// inside `run()`, parentheses matched.
///
/// Scoped twice over on purpose. The declaration
/// (`ExecutionCoordinator buildTriageExecutionCoordinator({`) is not a call and
/// must never satisfy this, and a call outside `run()` would be a different
/// composition entirely — so the search runs inside `run()`'s body only, and
/// the factory is reached through `= ` so the declaration cannot be mistaken
/// for a call.
String _coordinatorCallInRun(String source) {
  final runStart = RegExp('^void run\\(', multiLine: true).firstMatch(source);
  expect(
    runStart,
    isNotNull,
    reason: 'the composition root must still be `run`',
  );
  final runEnd = RegExp('^\\}', multiLine: true).firstMatch(
    source.substring(runStart!.end),
  );
  expect(runEnd, isNotNull, reason: '`run()` must be a top-level function');
  final body = source.substring(runStart.end, runStart.end + runEnd!.start);

  final calls = RegExp('= buildTriageExecutionCoordinator\\(').allMatches(body);
  expect(
    calls,
    hasLength(1),
    reason:
        'exactly ONE call site, so the assertions cannot bind to nothing, to a '
        'declaration, or to one of several. Inlining an `ExecutionCoordinator('
        '...)` instead of going through the named factory means the '
        'composition is no longer reachable from a test at all.',
  );

  final open = body.indexOf('(', calls.single.start);
  var depth = 0;
  var close = -1;
  for (var i = open; i < body.length; i++) {
    if (body[i] == '(') {
      depth++;
    } else if (body[i] == ')') {
      depth--;
      if (depth == 0) {
        close = i;
        break;
      }
    }
  }
  expect(
    close,
    greaterThan(-1),
    reason: 'the call must be delimited by balanced parentheses to be read',
  );
  return body.substring(open, close + 1);
}
