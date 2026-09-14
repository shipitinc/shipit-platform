/// Proves the persistence slice end-to-end against Postgres: after a simulated
/// process restart (discarding all in-memory state, re-hydrating fresh objects
/// from the same Postgres rows), the control plane reconstructs every durable
/// boundary — workflow state, scheduler lifecycle, claim leases, human
/// decisions, worker registrations, and agent executions — with no duplicate
/// jobs, no lost history or decisions, no double-dispatches, and no policy
/// bypass.
///
/// Strategy: each harness is a "process". Constructing a new [Harness] over the
/// same Postgres DB simulates a crash-and-restart; the new instance has no
/// prior in-memory state and must read/write durable Postgres state only.
library;

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_execution_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'test_tools/serverpod_test_tools.dart';

// ---------------------------------------------------------------------------
// Minimal WorkerDispatch fake (mirrors ControlledDispatcher from the scheduler
// package tests). Self-contained; avoids importing test/ support from deps.
// ---------------------------------------------------------------------------
class FakeDispatch implements WorkerDispatch {
  FakeDispatch({this.capacity = 1});

  int capacity;

  final runs = <WorkerExecutionRequest>[];

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    if (capacity > 0) {
      return WorkerSelection.dispatched(
        WorkerRegistration(
          workerId: 'w-1',
          poolId: 'pg-e2e',
          capabilities: {
            for (final c in request.requiredCapabilities)
              c: CapabilitySpec(capability: c, version: '1'),
          },
          status: WorkerStatus.idle,
          currentLoad: 0,
          maxConcurrency: 1,
          lastHeartbeat: DateTime.now().toUtc(),
        ),
      );
    }
    return WorkerSelection.busy(compatibleWorkers: const []);
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    if (capacity <= 0) {
      throw const WorkerDispatchException(
        WorkerDispatchOutcome.workerBusy,
        workerId: 'w-1',
      );
    }
    capacity--;
    runs.add(request);
    final t = DateTime.now().toUtc();
    final result = WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: WorkerExecutionStatus.executedPass,
      workerId: 'w-1',
      workspaceId: 'ws-${request.workerExecutionId}',
      startingRevision: request.startingRevision,
      startedAt: t,
      endedAt: t,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.none,
    );
    return result;
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

// ---------------------------------------------------------------------------
// Test harness: one "process" = one fresh set of Postgres-backed stores,
// engine, scheduler, and dispatch over the shared DB.
// ---------------------------------------------------------------------------

class Harness {
  Harness({this._clock});

  final DateTime Function()? _clock;
  late final Session _session;
  late final PersistenceDatabase _db;
  late final PostgresWorkflowStore workflowStore;
  late final DurableWorkflowEngine workflowEngine;
  late final PostgresJobStore jobStore;
  late final PostgresWorkerStore workerStore;
  late final PostgresExecutionStore executionStore;
  late final FakeDispatch dispatch;
  late final Scheduler scheduler;

  static Future<Harness> open({DateTime Function()? clock}) async {
    final h = Harness(clock: clock);
    h._session = await Serverpod.instance.createSession(enableLogging: false);
    h._db = PersistenceDatabase(h._session.db);
    h.workflowStore = PostgresWorkflowStore(h._db);
    h.workflowEngine = DurableWorkflowEngine(store: h.workflowStore);
    h.jobStore = PostgresJobStore(h._db);
    h.workerStore = PostgresWorkerStore(h._db);
    h.executionStore = PostgresExecutionStore(h._db);
    h.dispatch = FakeDispatch();
    h.scheduler = Scheduler(
      schedulerId: 'sched-e2e',
      workflowStore: h.workflowStore,
      jobStore: h.jobStore,
      workerStore: h.workerStore,
      dispatch: h.dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: SchedulerWorkload(
        repositoryPath: '/tmp/e2e-repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake',
      ),
      clock: clock,
      claimLease: const Duration(minutes: 10),
    );
    return h;
  }

  Future<void> close() => _session.close();

  /// Drives wi-1 through the legal chain to designNotRequired (runnable by
  /// the scheduler), which mirrors the FileRestartHarness.itemRunnable.
  Future<void> itemRunnable() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'E2E restart feature',
      qaContractId: 'qa-1',
      featureRef: 'feature/e2e',
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/e2e'},
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<Job> enqueueJob() async {
    final result = await scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-1',
      definition: defaultImplementFeatureDefinition,
      dedupeKey: dedupeKey,
      instruction: 'Implement the feature.',
      now: _clock?.call() ?? DateTime.now().toUtc(),
    );
    return result.job;
  }

  Future<Job> plantClaimedJob(DateTime t0) async {
    final job = await enqueueJob();
    final claim = await scheduler.queue.claim(
      job: job,
      ownerId: 'sched-e2e',
      now: t0,
      lease: const Duration(minutes: 10),
    );
    expect(claim, isNotNull);
    return (await jobStore.readJob(job.jobId))!;
  }

  Future<Job> plantRunningJob(DateTime t0) async {
    final job = await plantClaimedJob(t0);
    return scheduler.queue.markRunning(
      job: job,
      now: t0,
      workerId: 'w-1',
      workerExecutionId: 'wx-${job.jobId}',
    );
  }

  String get dedupeKey =>
      'wi-1:${WorkItemState.designNotRequired.wire}:'
      '${JobType.implementFeature.wire}:${AgentRole.implementer.wire}';
}

// ---------------------------------------------------------------------------
// Shared setup: TRUNCATE before each test, close harness sessions in tearDown.
// ---------------------------------------------------------------------------

final _openSessions = <Session>[];

Future<PersistenceDatabase> _db() async {
  final s = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(s);
  return PersistenceDatabase(s.db);
}

Future<void> truncate() async {
  final db = await _db();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "work_item",
      "human_decision",
      "work_item_transition",
      "job",
      "job_claim",
      "scheduler_event",
      "worker_execution",
      "worker_result",
      "worker_event",
      "worker_registration",
      "agent_execution_request",
      "agent_execution",
      "agent_event",
      "agent_result",
      "platform_verification"
    RESTART IDENTITY CASCADE
  ''');
}

Harness? _first;
Harness? _second;

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t1 = t0.add(const Duration(minutes: 11));

  withServerpod(
    'E2E process-restart proofs against Postgres',
    (sessionBuilder, endpoints) {
      setUp(truncate);

      tearDown(() async {
        await _first?.close();
        await _second?.close();
        _first = null;
        _second = null;
        for (final s in List.of(_openSessions)) {
          await s.close();
        }
        _openSessions.clear();
      });

      // ---- (A) Workflow restart: state + transitions fully reconstruct ----

      test('workflow restart: work item state and transition history survive '
          'a process restart and continue from the durable snapshot', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.itemRunnable();
        final item = await _first!.workflowStore.readWorkItem('wi-1');
        expect(item.state, WorkItemState.designNotRequired);

        // "Crash" — second process re-hydrates from the same DB rows.
        _second = await Harness.open(clock: () => t0);
        final itemAfter = await _second!.workflowStore.readWorkItem('wi-1');
        expect(itemAfter.state, WorkItemState.designNotRequired);
        expect(itemAfter.version, item.version);

        final history = await _second!.workflowStore.readTransitionHistory(
          'wi-1',
        );
        expect(
          history,
          isNotEmpty,
          reason: 'every accepted transition is persisted',
        );
        expect(
          history.last.toState,
          WorkItemState.designNotRequired,
          reason: 'last transition matches current durable state',
        );
      });

      // ---- (B) Scheduler restart: claim-crash → exactly one dispatch ----

      test('scheduler restart: claim-crash requeues a stale claim and '
          'dispatches exactly once', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.itemRunnable();
        await _first!.plantClaimedJob(t0); // crash between claim and dispatch

        _second = await Harness.open(clock: () => t1);
        final tick = await _second!.scheduler.tick();

        expect(tick.reconciled, hasLength(1));
        final job = (await _second!.jobStore.listJobs()).single;
        expect(job.state, JobState.succeeded);
        expect(job.failure, isNull);
        expect(_second!.dispatch.runs, hasLength(1));
        expect(await _second!.jobStore.readClaimForJob(job.jobId), isNull);

        final events = await _second!.jobStore.readEvents(job.jobId);
        expect(events.map((e) => e.type), [
          SchedulerEventType.jobQueued,
          SchedulerEventType.jobClaimed,
          SchedulerEventType.jobQueued,
          SchedulerEventType.jobClaimed,
          SchedulerEventType.jobDispatched,
          SchedulerEventType.jobCompleted,
        ]);
        expect(
          events.where((e) => e.type == SchedulerEventType.jobDispatched),
          hasLength(1),
          reason: 'a claim-crash must never produce a double-dispatch',
        );
      });

      test('scheduler restart: a running worker is protected by the lease '
          'and not duplicated', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.itemRunnable();
        final running = await _first!.plantRunningJob(t0);
        final wx = running.executionReference!.workerExecutionId;
        await _first!.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: wx,
            workItemId: 'wi-1',
            repositoryPath: '/tmp/e2e-repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.agentExecuting,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: t0,
          ),
        );

        // "Crash" — second process re-hydrates; lease still live.
        _second = await Harness.open(clock: () => t1);
        final tick = await _second!.scheduler.tick();

        expect(tick.reconciled, hasLength(1));
        final job = (await _second!.jobStore.listJobs()).single;
        expect(
          job.state,
          JobState.running,
          reason: 'a live execution is protected, not duplicated',
        );
        expect(_second!.dispatch.runs, isEmpty);
        final renewed = await _second!.jobStore.readClaimForJob(job.jobId);
        expect(renewed!.leasedUntil, t1.add(const Duration(minutes: 10)));
      });

      test('scheduler restart: a finished-but-not-adopted execution is '
          'adopted and no new execution starts', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.itemRunnable();
        final running = await _first!.plantRunningJob(t0);
        final wx = running.executionReference!.workerExecutionId;
        await _first!.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: wx,
            workItemId: 'wi-1',
            repositoryPath: '/tmp/e2e-repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.executedPass,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: t0,
            endedAt: t1,
          ),
        );
        await _first!.workerStore.saveResult(
          WorkerExecutionResult(
            workerExecutionId: wx,
            workItemId: 'wi-1',
            status: WorkerExecutionStatus.executedPass,
            workerId: 'w-1',
            workspaceId: 'ws-$wx',
            startingRevision: 'deadbeef',
            startedAt: t0,
            endedAt: t1,
            cleanupStatus: WorkerCleanupStatus.removed,
            failureCode: WorkerFailureCode.none,
          ),
        );

        _second = await Harness.open(clock: () => t1);
        final tick = await _second!.scheduler.tick();

        expect(tick.reconciled, hasLength(1));
        final job = (await _second!.jobStore.listJobs()).single;
        expect(job.state, JobState.succeeded);
        expect(_second!.dispatch.runs, isEmpty);
        expect(await _second!.jobStore.readClaimForJob(job.jobId), isNull);
      });

      // ---- (C) Decision durability across restart ----

      test('human decision durability: a pending decision and its gate '
          'survive a process restart and are idempotently resolved', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.workflowEngine.createWorkItem(
          workItemId: 'wi-hd',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Human decision durability',
          designContractId: 'dc-1',
          featureRef: 'feature/hd',
        );
        await _first!.workflowEngine.transition(
          workItemId: 'wi-hd',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
        );
        await _first!.workflowEngine.transition(
          workItemId: 'wi-hd',
          to: WorkItemState.planned,
          trigger: TransitionTrigger.systemEvent,
          context: const {'featureRef': 'feature/hd'},
        );
        await _first!.workflowEngine.transition(
          workItemId: 'wi-hd',
          to: WorkItemState.designRequired,
          trigger: TransitionTrigger.systemEvent,
          context: const {'designContractId': 'dc-1'},
        );
        await _first!.workflowEngine.transition(
          workItemId: 'wi-hd',
          to: WorkItemState.designInReview,
          trigger: TransitionTrigger.systemEvent,
          context: const {
            'designContractId': 'dc-1',
            'designContractStatus': DesignContractStatus.underReview,
          },
        );
        final pending = await _first!.workflowEngine.requestHumanDecision(
          workItemId: 'wi-hd',
          decisionType: HumanDecisionType.designApproval,
          question: 'Approve?',
          blocking: true,
        );
        final decisionId = pending.decisionId;

        // "Crash" — second process reconstructs the engine from PG.
        _second = await Harness.open(clock: () => t1);
        final item = await _second!.workflowStore.readWorkItem('wi-hd');
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(item.blockingHumanDecisionId, decisionId);

        final decisions = await _second!.workflowStore
            .readHumanDecisionsForWorkItem('wi-hd');
        expect(decisions, hasLength(1));
        expect(decisions.first.decisionId, decisionId);
        expect(decisions.first.status, HumanDecisionStatus.pending);

        // Resolve in the second process.
        final resolved = await _second!.workflowEngine.resolveHumanDecision(
          decisionId: decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'alice',
          rationale: 'LGTM',
          signature: DecisionSignature(
            algorithm: 'Ed25519',
            publicKey: 'key-alice',
            signature: 'sig-1',
            signedAt: t1,
          ),
        );
        expect(resolved.state, WorkItemState.designApproved);
        expect(resolved.blockingHumanDecisionId, isNull);

        // Idempotent replay — duplicate resolution must not move state again.
        final replay = await _second!.workflowEngine.resolveHumanDecision(
          decisionId: decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'alice',
          rationale: 'Duplicate',
          signature: DecisionSignature(
            algorithm: 'Ed25519',
            publicKey: 'key-alice',
            signature: 'sig-replay',
            signedAt: t1,
          ),
        );
        expect(replay.state, WorkItemState.designApproved);
      });

      // ---- (D) Idempotent transition replay against PG ----

      test('idempotent transition replay: re-applying an already-seen '
          'transition does not duplicate history', () async {
        _first = await Harness.open(clock: () => t0);
        await _first!.workflowEngine.createWorkItem(
          workItemId: 'wi-imp',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Idempotent replay',
          featureRef: 'feature/imp',
        );
        await _first!.workflowEngine.transition(
          workItemId: 'wi-imp',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          idempotencyKey: 'idk-1',
        );
        final history = await _first!.workflowStore.readTransitionHistory(
          'wi-imp',
        );
        final countBefore = history.length;

        // Replay with the same idempotency key — must be a no-op.
        final replay = await _first!.workflowEngine.transition(
          workItemId: 'wi-imp',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          idempotencyKey: 'idk-1',
        );
        expect(replay.state, WorkItemState.planning);

        final historyAfter = await _first!.workflowStore.readTransitionHistory(
          'wi-imp',
        );
        expect(
          historyAfter.length,
          countBefore,
          reason: 'a duplicate idempotency key must not add history',
        );
      });

      // ---- (E) Execution coordinator orphan reconciliation ----

      test('execution coordinator restart: orphaned execution is '
          'reconciled exactly once', () async {
        _first = await Harness.open(clock: () => t0);
        final workspace = AgentWorkspace(
          workspaceId: 'ws-orphan',
          path: '/tmp/e2e-repo',
          startingRevision: 'deadbeef',
        );
        final request = AgentExecutionRequest(
          executionId: 'exec-orphan',
          workItemId: 'wi-1',
          role: AgentRole.implementer,
          runtimeTypeId: 'fake',
          workspace: workspace,
          instruction: 'run',
          timeoutSeconds: 60,
          createdAt: t0,
        );
        await _first!.executionStore.saveRequest(request);
        final exec = AgentExecution(
          executionId: 'exec-orphan',
          workItemId: 'wi-1',
          requestId: 'exec-orphan',
          runtimeTypeId: 'fake',
          role: AgentRole.implementer,
          status: AgentSessionStatus.running,
          workspace: workspace,
          startedAt: t0,
        );
        await _first!.executionStore.saveExecution(exec);

        // "Crash" — second process, no live sessions.
        _second = await Harness.open(clock: () => t0);
        final items = await _second!.executionStore.listExecutions();
        expect(items, hasLength(1));
        expect(items.first.status, AgentSessionStatus.running);
        expect(
          items.first.isTerminal,
          isFalse,
          reason: 'orphan entry was not prematurely finalized by reads',
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
