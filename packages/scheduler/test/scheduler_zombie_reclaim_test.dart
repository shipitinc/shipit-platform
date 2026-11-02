import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// Reconciliation used to answer "is the worker row terminal?" and, when it was
/// not, renew the lease forever. A worker whose process died mid-execution is
/// also not terminal, so it was renewed on every tick and the 10 minute lease
/// could never expire - which is how a zombie outlived it for 4.78 hours.
///
/// These tests pin both directions of the replacement: an execution nothing is
/// running behind is reclaimed to a terminal job state, and an execution that
/// really is alive is still renewed without a duplicate dispatch.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);
  // One lease past `t0`: the claim has expired, so reconciliation runs.
  final t1 = t0.add(const Duration(minutes: 11));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_zombie_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A non-terminal worker execution carrying the given agent execution id.
  WorkerExecution _execution({String? agentExecutionId}) => WorkerExecution(
    workerExecutionId: 'wx-1',
    workItemId: 'wi-1',
    repositoryPath: '${dir.path}/repo',
    requestedStartingRevision: 'deadbeef',
    requiredCapabilities: const {},
    status: WorkerExecutionStatus.agentExecuting,
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    workerId: 'w-1',
    agentExecutionId: agentExecutionId,
    startedAt: t0,
  );

  /// Plants the incident: a job claimed and marked running against a worker
  /// execution that has been stuck in `agentExecuting` since [startedAt], with
  /// no terminal outcome ever recorded.
  Future<FileRestartHarness> zombieHost({
    required DateTime startedAt,
    ExecutionLivenessProbe? probe,
    String? agentExecutionId,
  }) async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.itemRunnable();
    final running = await first.plantRunningJob(t0);
    await first.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: running.executionReference!.workerExecutionId,
        workItemId: 'wi-1',
        repositoryPath: '${dir.path}/repo',
        requestedStartingRevision: 'deadbeef',
        requiredCapabilities: running.requiredCapabilities,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-1',
        agentExecutionId: agentExecutionId,
        startedAt: startedAt,
      ),
    );
    return FileRestartHarness(dir, clock: () => t1, executionLiveness: probe);
  }

  group('reconciliation reclaims a zombie execution', () {
    test(
      'no live session and an execution far past any plausible runtime: the '
      'job reaches a terminal state instead of being renewed forever',
      () async {
        // 4.78 hours, the shape of the production stall.
        final host = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        );

        final tick = await host.scheduler.tick();

        expect(tick.reconciled, hasLength(1));
        final job = (await host.jobStore.listJobs()).single;

        // TERMINAL, and not running.
        expect(
          job.isTerminal,
          isTrue,
          reason:
              'a zombie must reach a terminal '
              'job state rather than be renewed forever',
        );
        expect(job.state, JobState.failed);
        expect(job.failure, isNotNull);
        expect(job.failure!.reason, contains('zombie execution reclaimed'));

        // The reason is honest about what was and was not observable.
        expect(
          job.failure!.reason,
          contains('no live execution could be observed'),
        );

        // The lease was NOT renewed, and nothing was re-dispatched.
        expect(await host.jobStore.readClaimForJob(job.jobId), isNull);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );

    test('a proven-dead execution is reclaimed even when it is young, because '
        'deadness needs no staleness window', () async {
      final host = await zombieHost(
        startedAt: t0, // only 11 minutes old
        probe: (_, _) async => ExecutionLiveness.dead,
      );

      final tick = await host.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect(job.failure!.reason, contains('nothing is running behind it'));
      expect(await host.jobStore.readClaimForJob(job.jobId), isNull);
      expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
    });

    test(
      'a zombie is reclaimed on a REPEATED tick rather than surviving the first '
      'one and being renewed on the next',
      () async {
        final first = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        );

        // The first tick after the lease expires reclaims it.
        await first.scheduler.tick();
        expect(
          ((await first.jobStore.listJobs()).single).state,
          JobState.failed,
        );

        // Later ticks find nothing held, so nothing is re-dispatched and the
        // job does not drift back to running.
        final second = FileRestartHarness(
          dir,
          clock: () => t1.add(const Duration(hours: 5)),
        );
        await second.scheduler.tick();
        await second.scheduler.tick();

        final job = (await second.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect((second.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });

  group('reconciliation still renews a genuinely live worker', () {
    test('an execution observed alive is renewed and never duplicated, however '
        'old it is', () async {
      final host = await zombieHost(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        probe: (_, _) async => ExecutionLiveness.alive,
      );

      final tick = await host.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      final job = (await host.jobStore.listJobs()).single;

      // NOT duplicated, NOT abandoned.
      expect(job.state, JobState.running);
      expect(job.isTerminal, isFalse);
      expect((host.dispatch as ControlledDispatcher).runs, isEmpty);

      // The lease was renewed, not dropped.
      final renewed = await host.jobStore.readClaimForJob(job.jobId);
      expect(renewed, isNotNull);
      expect(renewed!.leasedUntil, t1.add(const Duration(minutes: 10)));
    });

    test(
      'an execution whose liveness cannot be observed is still renewed inside '
      'the staleness window - failing closed is bounded, not immediate',
      () async {
        // Age at reconcile time is 11 minutes, inside the 14 minute bound.
        final host = await zombieHost(
          startedAt: t0,
          probe: (_, _) async => ExecutionLiveness.unknown,
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running);
        expect(job.isTerminal, isFalse);
        expect(await host.jobStore.readClaimForJob(job.jobId), isNotNull);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );

    test(
      'a probe that throws is treated as unknown, not as dead: an observation '
      'failure is not evidence of death',
      () async {
        final host = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
          probe: (_, _) async => throw StateError('probe unreachable'),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        // Stale, so still reclaimed - but by the STALENESS bound, not by
        // mistaking a thrown probe for proof of death.
        expect(
          job.failure!.reason,
          contains('no live execution could be observed'),
        );
        expect(
          job.failure!.reason,
          isNot(contains('nothing is running behind it')),
        );
      },
    );

    test(
      'a young execution survives a throwing probe on the fail-open side',
      () async {
        final host = await zombieHost(
          startedAt: t0,
          probe: (_, _) async => throw StateError('probe unreachable'),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });

  group('liveSessionLivenessProbe — the decision rule', () {
    // This is the probe `apps/server/lib/server.dart` supplies, and the rule is
    // asserted here against the real function rather than a copy of it.
    test('a live agent session is ALIVE', () async {
      final probe = liveSessionLivenessProbe((id) => id == 'agx-live');
      expect(
        await probe(_execution(agentExecutionId: 'agx-live'), t1),
        ExecutionLiveness.alive,
      );
    });

    test('no live agent session is DEAD', () async {
      final probe = liveSessionLivenessProbe((_) => false);
      expect(
        await probe(_execution(agentExecutionId: 'agx-gone'), t1),
        ExecutionLiveness.dead,
      );
    });

    test('no agent execution id is UNKNOWN, never DEAD — an absence of evidence '
        'is not evidence of death', () async {
      // The production incident left exactly this state: a worker row stuck in
      // `agentExecuting` while `agent_execution` had 0 rows. Calling that dead
      // would reclaim a worker whose first agent id merely failed to persist.
      var consulted = false;
      final probe = liveSessionLivenessProbe((_) {
        consulted = true;
        return false;
      });
      for (final id in <String?>[null, '']) {
        expect(
          await probe(_execution(agentExecutionId: id), t1),
          ExecutionLiveness.unknown,
          reason: 'for agentExecutionId ${id == null ? 'null' : 'empty'}',
        );
      }
      expect(consulted, isFalse, reason: 'the oracle must not be asked');
    });

    test('an oracle that throws is UNKNOWN, never DEAD', () async {
      final probe = liveSessionLivenessProbe(
        (_) => throw StateError('coordinator unreachable'),
      );
      expect(
        await probe(_execution(agentExecutionId: 'agx-unreachable'), t1),
        ExecutionLiveness.unknown,
      );
    });
  });

  group('the production probe, wired end to end', () {
    // The same rule, now driving a real Scheduler over a real store, to prove
    // the verdicts reach the outcomes the incident turns on.
    test(
      'a live execution is ALIVE and is renewed, never duplicated',
      () async {
        final host = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
          agentExecutionId: 'agx-live',
          probe: liveSessionLivenessProbe((id) => id == 'agx-live'),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(
          job.state,
          JobState.running,
          reason: 'a live agent is never killed',
        );
        expect(job.isTerminal, isFalse);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
        expect(
          await host.jobStore.readClaimForJob(job.jobId),
          isNotNull,
          reason: 'the lease was renewed, not dropped',
        );
      },
    );

    test(
      'a dead execution is DEAD and is reclaimed, however recent it is',
      () async {
        final host = await zombieHost(
          startedAt: t0, // 11 minutes old - well inside the staleness bound
          agentExecutionId: 'agx-gone',
          probe: liveSessionLivenessProbe((_) => false),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect(job.isTerminal, isTrue);
        expect(job.failure!.reason, contains('nothing is running behind it'));
        expect(await host.jobStore.readClaimForJob(job.jobId), isNull);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );

    test('an unobservable execution is renewed inside the bound and reclaimed '
        'past it — fail open, but never forever', () async {
      final fresh = await zombieHost(
        startedAt: t0,
        agentExecutionId: null,
        probe: liveSessionLivenessProbe((_) => false),
      );
      await fresh.scheduler.tick();
      expect(
        (await fresh.jobStore.listJobs()).single.state,
        JobState.running,
        reason: 'unknown fails OPEN inside the bound',
      );

      final stale = FileRestartHarness(
        dir,
        clock: () => t1.add(const Duration(hours: 5)),
        executionLiveness: liveSessionLivenessProbe((_) => false),
      );
      await stale.scheduler.tick();
      expect((await stale.jobStore.listJobs()).single.state, JobState.failed);
    });

    test('a throwing oracle leaves the job running, not failed', () async {
      final host = await zombieHost(
        startedAt: t0,
        agentExecutionId: 'agx-unreachable',
        probe: liveSessionLivenessProbe(
          (_) => throw StateError('coordinator unreachable'),
        ),
      );

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(
        job.state,
        JobState.running,
        reason: 'a failed observation must not be read as proof of death',
      );
      expect(job.failure, isNull);
    });
  });

  group('F-235: the reclaim also closes the agent_execution row', () {
    late InMemoryExecutionStore agentStore;

    setUp(() {
      agentStore = InMemoryExecutionStore();
    });

    /// The agent_execution row the dead drive wrote and never finalized:
    /// `running` since [t0], the shape QA accumulated 13+ of.
    AgentExecution wedgedAgentExecution(String executionId) => AgentExecution(
      executionId: executionId,
      workItemId: 'wi-1',
      requestId: executionId,
      runtimeTypeId: 'fake-runtime',
      role: AgentRole.implementer,
      status: AgentSessionStatus.running,
      workspace: const AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws'),
      startedAt: t0,
    );

    /// The same incident as [zombieHost], plus a scheduler wired with the
    /// store-backed retirement the composition root supplies. The worker row
    /// is left WITHOUT `agentExecutionId` deliberately: the zombie shape is a
    /// row that never reached `_finish`, which is the only write that stamps
    /// the link — the reclaim must derive it instead of skipping the row.
    Future<FileRestartHarness> zombieHostWithAgentStore({
      required DateTime startedAt,
      ExecutionLivenessProbe? probe,
    }) async {
      final first = FileRestartHarness(dir, clock: () => t0);
      await first.itemRunnable();
      final running = await first.plantRunningJob(t0);
      await first.workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: running.executionReference!.workerExecutionId,
          workItemId: 'wi-1',
          repositoryPath: '${dir.path}/repo',
          requestedStartingRevision: 'deadbeef',
          requiredCapabilities: running.requiredCapabilities,
          status: WorkerExecutionStatus.agentExecuting,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          workerId: 'w-1',
          startedAt: startedAt,
        ),
      );
      return FileRestartHarness(
        dir,
        clock: () => t1,
        executionLiveness: probe,
        agentExecutionRetirement: storeBackedAgentExecutionRetirement(
          agentStore,
        ),
      );
    }

    test('a wedged execution is reclaimed: the job AND the agent_execution row '
        'are both terminal — not just the job', () async {
      final host = await zombieHostWithAgentStore(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
      );
      final workerExecutionId = (await host.jobStore.listJobs())
          .single
          .executionReference!
          .workerExecutionId;
      final agentExecutionId = agentExecutionIdForWorkerExecution(
        workerExecutionId,
      );
      await agentStore.saveExecution(wedgedAgentExecution(agentExecutionId));

      await host.scheduler.tick();

      // The job went terminal exactly as before.
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect(job.failure!.reason, contains('zombie execution reclaimed'));

      // The worker execution row was retired as before — and now carries
      // the link the dead drive never wrote.
      final workerExecution = await host.workerStore.readWorkerExecution(
        workerExecutionId,
      );
      expect(workerExecution!.isTerminal, isTrue);
      expect(workerExecution.agentExecutionId, agentExecutionId);

      // THE FIX: the agent_execution row is terminal too — no `running`
      // row asserting a live execution that does not exist.
      final agentExecution = await agentStore.readExecutionOrNull(
        agentExecutionId,
      );
      expect(agentExecution, isNotNull);
      expect(agentExecution!.isTerminal, isTrue);
      expect(agentExecution.status, AgentSessionStatus.orphaned);
      expect(agentExecution.completedAt, t1);
      expect(agentExecution.reason, contains('zombie execution reclaimed'));

      // And the close left an audit event, not a bare status flip.
      expect(await agentStore.readEvents(agentExecutionId), isNotEmpty);
    });

    test('a genuinely-live execution is untouched: the agent_execution row '
        'stays running when the job is renewed', () async {
      final host = await zombieHostWithAgentStore(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        probe: (_, _) async => ExecutionLiveness.alive,
      );
      final workerExecutionId = (await host.jobStore.listJobs())
          .single
          .executionReference!
          .workerExecutionId;
      final agentExecutionId = agentExecutionIdForWorkerExecution(
        workerExecutionId,
      );
      await agentStore.saveExecution(wedgedAgentExecution(agentExecutionId));

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.running);
      final agentExecution = await agentStore.readExecution(agentExecutionId);
      expect(
        agentExecution.status,
        AgentSessionStatus.running,
        reason: 'a live execution is never reclaimed',
      );
      expect(agentExecution.completedAt, isNull);
    });

    test('re-reclaim is idempotent: an already-terminal agent_execution row is '
        'a no-op, not an error, and the job still fails', () async {
      final host = await zombieHostWithAgentStore(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
      );
      final workerExecutionId = (await host.jobStore.listJobs())
          .single
          .executionReference!
          .workerExecutionId;
      final agentExecutionId = agentExecutionIdForWorkerExecution(
        workerExecutionId,
      );
      // Already closed by another writer (a live finalize, an earlier
      // reclaim). The reclaim must not error or reopen it.
      await agentStore.saveExecution(
        wedgedAgentExecution(agentExecutionId).copyWith(
          status: AgentSessionStatus.interrupted,
          completedAt: t0,
          reason: 'settled by the drive before it died',
          version: 2,
        ),
      );

      final tick = await host.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      expect(tick.reconcileFailed, isEmpty);
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      final agentExecution = await agentStore.readExecution(agentExecutionId);
      expect(agentExecution.status, AgentSessionStatus.interrupted);
      expect(agentExecution.completedAt, t0);
      expect(agentExecution.version, 2);
    });

    test('no agent_execution row exists: the derived id names nothing, the '
        'retirement is a no-op, and the job still fails', () async {
      final host = await zombieHostWithAgentStore(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
      );

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect(await agentStore.listExecutions(), isEmpty);
    });

    test(
      'a retirement failure is a defer, not a terminal job over a still-open '
      'row: the claim stays held and the next tick converges',
      () async {
        final broken = _BrokenAgentStore();
        final first = FileRestartHarness(dir, clock: () => t0);
        await first.itemRunnable();
        final running = await first.plantRunningJob(t0);
        final workerExecutionId = running.executionReference!.workerExecutionId;
        await first.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: workerExecutionId,
            workItemId: 'wi-1',
            repositoryPath: '${dir.path}/repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.agentExecuting,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: t0.subtract(const Duration(hours: 5)),
          ),
        );
        final agentExecutionId = agentExecutionIdForWorkerExecution(
          workerExecutionId,
        );
        await broken.seed(wedgedAgentExecution(agentExecutionId));

        final host = FileRestartHarness(
          dir,
          clock: () => t1,
          agentExecutionRetirement: storeBackedAgentExecutionRetirement(broken),
        );
        final tick = await host.scheduler.tick();

        // The failure was reported, not swallowed into a false terminal.
        expect(tick.reconcileFailed, hasLength(1));
        final job = (await host.jobStore.listJobs()).single;
        expect(
          job.isTerminal,
          isFalse,
          reason: 'a job must not complete over a still-running agent row',
        );
        expect(
          (await broken.readExecution(agentExecutionId)).status,
          AgentSessionStatus.running,
        );

        // Heal the store: the SAME row, now writable. The next tick
        // re-enters the still-held claim and converges — job failed, agent
        // row orphaned, nothing half-applied.
        broken.heal();
        final healed = FileRestartHarness(
          dir,
          clock: () => t1.add(const Duration(minutes: 11)),
          agentExecutionRetirement: storeBackedAgentExecutionRetirement(broken),
        );
        await healed.scheduler.tick();

        expect(
          (await healed.jobStore.listJobs()).single.state,
          JobState.failed,
        );
        expect(
          (await broken.readExecution(agentExecutionId)).status,
          AgentSessionStatus.orphaned,
        );
      },
    );
  });

  group('the staleness bound is derived, not guessed', () {
    test(
      'with no configured bound it scales with the agent timeout, and a live '
      'but slow execution inside it is renewed',
      () async {
        // timeoutSeconds 60 -> bound is 4*60 + 600s = 14 minutes.
        final first = FileRestartHarness(dir, clock: () => t0);
        await first.itemRunnable();
        final running = await first.plantRunningJob(t0);
        await first.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: running.executionReference!.workerExecutionId,
            workItemId: 'wi-1',
            repositoryPath: '${dir.path}/repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.agentExecuting,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: t0.subtract(const Duration(minutes: 2)),
          ),
        );

        final host = FileRestartHarness(dir, clock: () => t1);
        expect(
          host.scheduler.zombieStalenessBound,
          const Duration(minutes: 14),
        );

        await host.scheduler.tick();
        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running, reason: 'inside the window');
      },
    );

    test('a scheduler that cannot observe liveness says so in its startup '
        'summary instead of failing silently', () {
      final host = FileRestartHarness(dir, clock: () => t0);
      expect(host.scheduler.livenessSummary, contains('NOT observable'));
    });
  });
}

/// An [InMemoryExecutionStore] whose transaction fails until [heal] is called
/// — the deterministic store fault the reclaim must survive as a defer,
/// never as a terminal job written over a still-open `agent_execution` row.
class _BrokenAgentStore extends InMemoryExecutionStore {
  var _broken = true;

  void heal() => _broken = false;

  Future<void> seed(AgentExecution execution) => super.saveExecution(execution);

  @override
  Future<T> inTransaction<T>(Future<T> Function(ExecutionStore store) body) {
    if (_broken) throw StateError('execution store unreachable');
    return super.inTransaction(body);
  }
}
