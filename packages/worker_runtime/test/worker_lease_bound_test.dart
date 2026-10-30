import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// Regression coverage for F-226 worker-lease starvation.
///
/// `LocalWorker._leased` was held for the whole duration of `run` while only
/// ONE await inside the drive — `executionDriver.execute` — was bounded. Two
/// live QA executions wedged inside unbounded awaits ran 8-9 hours past their
/// budgets; the zombie sweep orphaned their durable rows but has no path back
/// to the in-process slot, so both workers reported `busy 1/1` for ever and
/// every queued job deferred `workerBusy`.
///
/// These tests wedge the drive at an unbounded await — a verification read
/// that never completes, a store transaction held on a gate — and prove the
/// lease is released at the whole-run bound, the hung session is cancelled,
/// and the worker takes the next run.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late GitWorktreeWorkspaceManager workspaceManager;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_lease_');
    repo = GitRepoFixture.create(temp.path);
    workspaceManager = GitWorktreeWorkspaceManager(
      workspaceRoot: '${temp.path}/workspaces',
    );
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {
      // cleanup may already have removed worktrees; root removal is best-effort
    }
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  LocalWorker buildWorker({
    required AgentExecutionDriver driver,
    required WorkerStore store,
    Duration abandonStepBound = const Duration(seconds: 5),
    ArtifactCommitter artifactCommitter = const ArtifactCommitter(),
    WorkspaceManager? manager,
  }) {
    return LocalWorker(
      workerId: 'w-test',
      poolId: 'test-pool',
      capabilities: const {WorkerCapability.linux},
      workspaceManager: manager ?? workspaceManager,
      executionDriver: driver,
      workerStore: store,
      artifactCommitter: artifactCommitter,
      // A whole-run bound of roughly timeoutSeconds + 50ms + 400ms: small
      // enough to test, structured exactly like production.
      workerLeaseGrace: const Duration(milliseconds: 50),
      driveOverheadBound: const Duration(milliseconds: 400),
      abandonStepBound: abandonStepBound,
    );
  }

  WorkerExecutionRequest buildRequest(
    String workerExecutionId, {
    int timeoutSeconds = 1,
  }) => WorkerExecutionRequest(
    workerExecutionId: workerExecutionId,
    workItemId: 'wi-1',
    repositoryPath: repo.root.path,
    startingRevision: repo.startingRevision,
    requiredCapabilities: const {WorkerCapability.linux},
    role: AgentRole.implementer,
    instruction: 'Implement add(2,3)==5 inside the worktree.',
    timeoutSeconds: timeoutSeconds,
    runtimeTypeId: 'stub-runtime',
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
  );

  group('a drive wedged at an unbounded await', () {
    test(
      'abandons at the whole-run bound, cancels the session, writes timedOut '
      'and frees the lease',
      () async {
        final store = InMemoryWorkerStore();
        // The wedge stands in for any unbounded await after `execute` — the
        // F-226 candidates were event writes, inspection, verification reads,
        // cleanup and the terminal write.
        final driver = _WedgingDriver()..wedgeVerifications = true;
        final worker = buildWorker(driver: driver, store: store);

        final elapsed = Stopwatch()..start();
        final result = await worker.run(buildRequest('wx-wedge'));
        elapsed.stop();

        expect(
          result.status,
          WorkerExecutionStatus.timedOut,
          reason:
              'an abandoned drive is an honest timeout: transient to '
              'RetryPolicy, never a silent success and never a hang',
        );
        expect(result.failureCode, WorkerFailureCode.timedOut);
        expect(result.failureDetail, contains('whole-run bound'));
        expect(
          elapsed.elapsed,
          lessThan(const Duration(seconds: 10)),
          reason:
              'the wedged future NEVER completes; a run that waits for it '
              'is the starvation defect returning (waited ${elapsed.elapsed})',
        );

        // The hung agent session is stopped through the existing cancel
        // path, not merely unblocked around.
        expect(
          driver.cancelCalls,
          contains('agx-wx-wedge'),
          reason: 'abandonment must cancel the in-flight agent execution',
        );

        // The lease is free and the worker reads idle again.
        expect(worker.isAcquirable, isTrue);
        expect(worker.liveStatus, WorkerStatus.idle);
        expect(worker.toRegistration().currentLoad, 0);

        // The durable record was marked terminal, honestly — the zombie
        // sweep is no longer the only thing that can end it.
        final persisted = await store.readWorkerExecution('wx-wedge');
        expect(persisted?.status, WorkerExecutionStatus.timedOut);
        expect(persisted?.failureCode, WorkerFailureCode.timedOut);
        final savedResult = await store.readResult('wx-wedge');
        expect(savedResult?.status, WorkerExecutionStatus.timedOut);

        // The workspace the drive prepared was cleaned by the abandon path.
        expect(await workspaceManager.discoverAll(), isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'the freed worker takes the next run normally',
      () async {
        final store = InMemoryWorkerStore();
        final driver = _WedgingDriver()..wedgeVerifications = true;
        final worker = buildWorker(driver: driver, store: store);

        final abandoned = await worker.run(buildRequest('wx-first'));
        expect(abandoned.status, WorkerExecutionStatus.timedOut);

        driver.wedgeVerifications = false;
        final result = await worker.run(buildRequest('wx-second'));

        expect(
          result.status,
          WorkerExecutionStatus.executedPass,
          reason:
              'the point of freeing the lease is that the worker keeps '
              'working; a slot that only LOOKS free is the same starvation',
        );
        expect(worker.isAcquirable, isTrue);
        expect(await workspaceManager.discoverAll(), isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'still frees the lease when the terminal write is itself the wedge',
      () async {
        // A store whose reads never return stands in for the locked
        // connection pool from the F-226 diagnosis. The abandon path's own
        // terminal write must be bounded, or the fix re-wedges one level
        // down.
        final store = _GatedStore(InMemoryWorkerStore())..wedgeReads = true;
        final driver = _WedgingDriver()..wedgeVerifications = true;
        final worker = buildWorker(
          driver: driver,
          store: store,
          abandonStepBound: const Duration(milliseconds: 300),
        );

        final elapsed = Stopwatch()..start();
        final result = await worker.run(buildRequest('wx-dead-store'));
        elapsed.stop();

        expect(result.status, WorkerExecutionStatus.timedOut);
        expect(result.failureCode, WorkerFailureCode.timedOut);
        expect(
          elapsed.elapsed,
          lessThan(const Duration(seconds: 10)),
          reason:
              'a wedged store must not turn the abandon path into a second '
              'place the lease can be held forever (waited ${elapsed.elapsed})',
        );
        expect(worker.isAcquirable, isTrue);
        expect(worker.liveStatus, WorkerStatus.idle);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('the detached drive that unwedges later', () {
    test(
      'cannot start an agent session and cannot take the slot back',
      () async {
        final inner = InMemoryWorkerStore();
        // Hold every inTransaction open on a gate the test controls: the
        // drive wedges in its FIRST write, before any session exists.
        final store = _GatedStore(inner)..closeGate();
        final driver = _WedgingDriver();
        final worker = buildWorker(
          driver: driver,
          store: store,
          abandonStepBound: const Duration(milliseconds: 300),
        );

        final result = await worker.run(buildRequest('wx-gated'));
        expect(result.status, WorkerExecutionStatus.timedOut);
        expect(worker.isAcquirable, isTrue);
        expect(driver.executeCalls, isEmpty);

        // Now let the wedged await unwind. The detached drive resumes,
        // writes its early events and prepares a workspace — and MUST NOT
        // start a session on a slot it no longer owns.
        store.openGate();

        final deadline = DateTime.now().add(const Duration(seconds: 15));
        WorkerExecution? record;
        while (DateTime.now().isBefore(deadline)) {
          record = await inner.readWorkerExecution('wx-gated');
          if (record != null &&
              (record.status == WorkerExecutionStatus.agentExecuting ||
                  record.status == WorkerExecutionStatus.timedOut)) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        // Give the detached drive room to reach the point where it would
        // have called execute, then prove it did not.
        await Future<void>.delayed(const Duration(seconds: 1));

        expect(
          driver.executeCalls,
          isEmpty,
          reason:
              'an abandoned drive that unwedges must bail out rather than '
              'spawn real agent work nobody is waiting for',
        );
        expect(
          worker.isAcquirable,
          isTrue,
          reason:
              'the detached drive must never take the lease back — that '
              'would starve the slot a second time',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'cannot clear the lease of a successor run that took the freed slot',
      () async {
        final inner = InMemoryWorkerStore();
        final store = _GatedStore(inner)..closeGate();
        final firstDriver = _WedgingDriver();
        final worker = buildWorker(
          driver: firstDriver,
          store: store,
          abandonStepBound: const Duration(milliseconds: 300),
        );

        final abandoned = await worker.run(buildRequest('wx-stale'));
        expect(abandoned.status, WorkerExecutionStatus.timedOut);
        expect(worker.isAcquirable, isTrue);

        // A successor takes the freed slot and parks on gates of its own —
        // a slow-but-alive drive, not a wedged one. The stale drive's gate
        // stays shut for now.
        final successorStoreGate = Completer<void>();
        store.releaseTo(heldBy: successorStoreGate);
        firstDriver.verificationsGate = Completer<void>();
        final successor = worker.run(buildRequest('wx-successor'));

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          worker.isAcquirable,
          isFalse,
          reason: 'the successor holds the slot now',
        );

        // Let the successor run until it is parked at the verification read
        // holding the lease, THEN unwind the stale drive into the window
        // where a late lease-clear would hurt.
        successorStoreGate.complete();
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(deadline)) {
          if (firstDriver.verificationsCalls.contains('agx-wx-successor')) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(
          firstDriver.verificationsCalls,
          contains('agx-wx-successor'),
          reason: 'the successor is mid-drive and holds the slot',
        );

        store.openGate();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(
          worker.isAcquirable,
          isFalse,
          reason:
              'the stale drive resuming must not free the slot the '
              'successor still holds — the starvation bug one level down',
        );
        expect(
          firstDriver.executeCalls,
          isNot(contains('agx-wx-stale')),
          reason: 'the stale drive bails before starting its session',
        );

        firstDriver.verificationsGate!.complete();
        final result = await successor;
        expect(result.status, WorkerExecutionStatus.executedPass);
        expect(
          worker.isAcquirable,
          isTrue,
          reason: 'after the SUCCESSOR finishes the slot is free again',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('resumed after the execute checkpoint writes nothing: the terminal '
        'row, the saved result and the artifact branch stay the abandon '
        "path's", () async {
      final store = InMemoryWorkerStore();
      final driver = _WedgingDriver()
        ..verificationsGate = Completer<void>()
        // Give the abandoned run a produced artifact: without the
        // post-checkpoint fence the resumed drive commits it, and the
        // counting committer + branch check below catch the regression.
        ..writeArtifact = true;
      final committer = _CountingCommitter();
      final worker = buildWorker(
        driver: driver,
        store: store,
        artifactCommitter: committer,
      );

      // The drive wedges at verificationsFor — AFTER execute and inspect,
      // one of the post-checkpoint awaits the pre-execute fence never
      // covered — and the run abandons at the whole-run bound.
      final abandoned = await worker.run(buildRequest('wx-resume'));
      expect(abandoned.status, WorkerExecutionStatus.timedOut);
      expect(
        (await store.readWorkerExecution('wx-resume'))?.status,
        WorkerExecutionStatus.timedOut,
      );

      // Prove the drive wedged POST-checkpoint: otherwise this test is a
      // rerun of the pre-execute fence, not a regression test for it.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        if (driver.verificationsCalls.contains('agx-wx-resume')) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        driver.verificationsCalls,
        contains('agx-wx-resume'),
        reason:
            'the drive must have wedged post-checkpoint for this to '
            'exercise the resume fence',
      );

      // Unwedge the drive. It resumes through the status switch, the
      // artifact commit, the cleanup record and _finish — all writes a
      // detached drive must not reach.
      driver.verificationsGate!.complete();
      await Future<void>.delayed(const Duration(seconds: 1));

      final persisted = await store.readWorkerExecution('wx-resume');
      expect(
        persisted?.status,
        WorkerExecutionStatus.timedOut,
        reason:
            'a resumed detached drive must not CAS-overwrite the terminal '
            'row the abandon path wrote',
      );
      expect(persisted?.failureCode, WorkerFailureCode.timedOut);
      expect(
        (await store.readResult('wx-resume'))?.status,
        WorkerExecutionStatus.timedOut,
        reason: 'the saved result must not be overwritten either',
      );
      expect(
        committer.calls,
        0,
        reason:
            'a stale drive running the artifact commit would checkout -B '
            'force-move shipit/impl/<workItemId> onto an abandoned '
            "run's artifact",
      );
      final branchLookup = await Process.run('git', [
        '-C',
        repo.root.path,
        'rev-parse',
        '--verify',
        'refs/heads/shipit/impl/wi-1',
      ]);
      expect(
        branchLookup.exitCode,
        isNot(0),
        reason: 'the artifact branch must not exist for an abandoned run',
      );
      expect(await workspaceManager.discoverAll(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('wedged inside workspaceManager.cleanup: the resumed drive cannot '
        'resurrect the timedOut row', () async {
      final store = InMemoryWorkerStore();
      // The drive makes it all the way to _finalCleanup and wedges on
      // the FIRST cleanup call — the exact await the post-resume blind
      // _setCleanup upsert follows. Later calls (the abandon path's own
      // cleanup) pass straight through, so the terminal write lands
      // with the honest cleanup outcome.
      final gatedWorkspace = _GatedWorkspaceManager(workspaceManager)
        ..armCleanupGate();
      final driver = _WedgingDriver();
      final worker = buildWorker(
        driver: driver,
        store: store,
        manager: gatedWorkspace,
        abandonStepBound: const Duration(milliseconds: 300),
      );

      // Drive the run WITHOUT awaiting so the test can confirm the
      // drive reached the cleanup wedge before the whole-run bound
      // fires at ~4.45s — otherwise this exercises the wrong stage.
      final runFuture = worker.run(
        buildRequest('wx-cleanup', timeoutSeconds: 4),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (gatedWorkspace.cleanupCalls.isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(
        gatedWorkspace.cleanupCalls,
        isNotEmpty,
        reason:
            'the drive must reach _finalCleanup and wedge inside '
            'workspaceManager.cleanup before the bound fires — this '
            'call arriving pre-bound is what makes it the FIRST, '
            'gated call rather than the abandon path\u2019s',
      );

      final abandoned = await runFuture;
      expect(abandoned.status, WorkerExecutionStatus.timedOut);
      expect(
        (await store.readWorkerExecution('wx-cleanup'))?.status,
        WorkerExecutionStatus.timedOut,
      );

      // Unwedge the cleanup. The detached drive resumes into
      // _setCleanup and _finish — the two blind upserts this
      // regression covers — and must be fenced out of both.
      gatedWorkspace.openCleanupGate();
      await Future<void>.delayed(const Duration(seconds: 1));

      final persisted = await store.readWorkerExecution('wx-cleanup');
      expect(
        persisted?.status,
        WorkerExecutionStatus.timedOut,
        reason:
            'the resumed drive\u2019s blind cleanup-record upsert would '
            'rewrite the terminal row back to agentExecuting',
      );
      expect(
        persisted?.endedAt,
        isNotNull,
        reason:
            'a resurrected row is the stale in-memory copy: it carries '
            'endedAt=null again',
      );
      expect(persisted?.failureCode, WorkerFailureCode.timedOut);
      expect(
        (await store.readResult('wx-cleanup'))?.status,
        WorkerExecutionStatus.timedOut,
        reason: 'the saved result must not be overwritten either',
      );
      expect(await workspaceManager.discoverAll(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

/// An [AgentExecutionDriver] that completes `execute` promptly but can wedge
/// `verificationsFor` forever — the shape of an unbounded await inside the
/// drive.
class _WedgingDriver implements AgentExecutionDriver {
  var wedgeVerifications = false;
  var writeArtifact = false;
  Completer<void>? verificationsGate;
  final executeCalls = <String>[];
  final cancelCalls = <String>[];
  final verificationsCalls = <String>[];

  AgentExecution _execution(
    AgentExecutionRequest request,
    AgentSessionStatus status,
  ) => AgentExecution(
    executionId: request.executionId,
    workItemId: request.workItemId,
    requestId: 'req-${request.executionId}',
    runtimeTypeId: request.runtimeTypeId,
    role: request.role,
    status: status,
    workspace: request.workspace,
    sessionId: 'ses-stub',
    startedAt: DateTime.now().toUtc(),
    completedAt: DateTime.now().toUtc(),
  );

  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    executeCalls.add(request.executionId);
    if (writeArtifact) {
      // A produced artifact in the worktree: an unfenced resumed drive
      // would commit it onto shipit/impl/<workItemId>.
      File(
        '${request.workspace.path}/produced_artifact.txt',
      ).writeAsStringSync('produced by the abandoned run\n');
    }
    return _execution(request, AgentSessionStatus.completed);
  }

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async {
    cancelCalls.add(executionId);
    return AgentExecution(
      executionId: executionId,
      workItemId: 'wi-1',
      requestId: 'req-$executionId',
      runtimeTypeId: 'stub-runtime',
      role: AgentRole.implementer,
      status: AgentSessionStatus.cancelled,
      workspace: const AgentWorkspace(workspaceId: 'ws-stub', path: '/tmp'),
    );
  }

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async {
    verificationsCalls.add(executionId);
    final gate = verificationsGate;
    if (gate != null) await gate.future;
    if (wedgeVerifications) {
      // Never completes: the wedged await.
      return Completer<List<PlatformVerification>>().future;
    }
    return const [];
  }
}

/// An [ArtifactCommitter] that counts invocations: a stale drive must never
/// reach the artifact commit, so any non-zero count is the unfenced-write
/// defect returning.
class _CountingCommitter extends ArtifactCommitter {
  var calls = 0;

  @override
  Future<ArtifactCommitOutcome> commit({
    required String worktreePath,
    required String workItemId,
    required String startingRevision,
    required String message,
    String branchPrefix = 'shipit/impl',
  }) {
    calls++;
    return super.commit(
      worktreePath: worktreePath,
      workItemId: workItemId,
      startingRevision: startingRevision,
      message: message,
      branchPrefix: branchPrefix,
    );
  }
}

/// A [WorkspaceManager] that forwards to a real manager but holds the
/// FIRST `cleanup` call on a gate the test controls — the shape of the
/// drive wedging inside the cleanup await that precedes the blind
/// `_setCleanup` upsert. Only the first call is gated: the abandon
/// path's own cleanup must still run so the terminal row is written
/// with the honest outcome.
class _GatedWorkspaceManager implements WorkspaceManager {
  _GatedWorkspaceManager(this._inner);

  final WorkspaceManager _inner;
  Completer<void>? _cleanupGate;
  var _callIndex = 0;
  final cleanupCalls = <WorkspaceDescriptor>[];

  void armCleanupGate() => _cleanupGate = Completer<void>();

  void openCleanupGate() {
    _cleanupGate?.complete();
    _cleanupGate = null;
  }

  @override
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  }) => _inner.prepare(request, workerId: workerId);

  @override
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor) async {
    final index = _callIndex++;
    cleanupCalls.add(descriptor);
    final gate = _cleanupGate;
    if (gate != null && index == 0) await gate.future;
    return _inner.cleanup(descriptor);
  }

  @override
  Future<List<WorkspaceDescriptor>> discoverAll() => _inner.discoverAll();
}

/// A [WorkerStore] that forwards everything to an in-memory store but can
/// hold `inTransaction` on a gate the test controls — the shape of a
/// database write wedged on a locked connection pool — and can wedge reads
/// outright.
class _GatedStore implements WorkerStore {
  _GatedStore(this._inner);

  final WorkerStore _inner;

  Completer<void>? _gate;
  Completer<void>? _staleGate;
  Completer<void>? _heldBy;
  var wedgeReads = false;

  void closeGate() => _gate = Completer<void>();

  /// Stops gating new calls on [_gate] and hands the pause to [heldBy]:
  /// calls arriving after this wait on [heldBy] instead, so a test can
  /// control the stale drive and the successor drive separately. The gate
  /// the stale calls already captured is kept in [_staleGate] so
  /// [openGate] can still unwind them.
  void releaseTo({required Completer<void> heldBy}) {
    _staleGate = _gate;
    _gate = null;
    _heldBy = heldBy;
  }

  void openGate() {
    _staleGate?.complete();
    _gate?.complete();
    _staleGate = null;
    _gate = null;
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkerStore) body) async {
    final gate = _gate ?? _heldBy;
    if (gate != null) await gate.future;
    return _inner.inTransaction(body);
  }

  @override
  Future<WorkerExecution?> readWorkerExecution(String workerExecutionId) {
    if (wedgeReads) return Completer<WorkerExecution?>().future;
    return _inner.readWorkerExecution(workerExecutionId);
  }

  @override
  Future<void> saveWorkerExecution(
    WorkerExecution execution, {
    int? expectedVersion,
  }) => _inner.saveWorkerExecution(execution, expectedVersion: expectedVersion);

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() =>
      _inner.listWorkerExecutions();

  @override
  Future<void> saveResult(WorkerExecutionResult result) =>
      _inner.saveResult(result);

  @override
  Future<WorkerExecutionResult?> readResult(String workerExecutionId) =>
      _inner.readResult(workerExecutionId);

  @override
  Future<void> appendEvent(WorkerEventRecord event) =>
      _inner.appendEvent(event);

  @override
  Future<List<WorkerEventRecord>> readEvents(String workerExecutionId) =>
      _inner.readEvents(workerExecutionId);
}
