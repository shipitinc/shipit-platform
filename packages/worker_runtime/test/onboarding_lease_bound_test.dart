import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/src/worker/onboarding_worker.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// Regression coverage for F-232: the same lease-starvation defect F-226
/// closed on `LocalWorker`, in the same shape, on `OnboardingWorker`.
///
/// `OnboardingWorker._leased` was held for the whole duration of `run`
/// while every await inside the drive was unbounded — the workspace
/// prepare, every store write (events, transitions, cleanup records, the
/// terminal write), the inspection and the cleanup. A wedge in any of
/// them starved the worker's only slot forever; the zombie sweep can
/// orphan the durable row but has no path back to the in-process slot.
///
/// These tests wedge the drive at an unbounded await — a prepare that
/// never completes, a store transaction held on a gate, a cleanup held
/// on a gate — and prove the lease is released at the whole-run bound,
/// the terminal outcome is honest `timedOut`, a detached drive that
/// unwedges later writes nothing, and the worker takes the next run.
///
/// `OnboardingWorker` has no agent session and no artifact committer, so
/// the F-226 assertions about cancelling a session and not moving the
/// artifact branch have no counterpart here; the ported surface is the
/// store-write fences and the lease ownership.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late GitWorktreeWorkspaceManager workspaceManager;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('onboarding_lease_');
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

  OnboardingWorker buildWorker({
    required WorkerStore store,
    Duration abandonStepBound = const Duration(seconds: 5),
    WorkspaceManager? manager,
    GitWorkspaceInspector? inspector,
  }) {
    return OnboardingWorker(
      workerId: 'w-onboarding',
      poolId: 'test-pool',
      capabilities: const {WorkerCapability.linux},
      workspaceManager: manager ?? workspaceManager,
      workerStore: store,
      inspector: inspector ?? const GitWorkspaceInspector(),
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
    workItemId: 'wi-onb-1',
    repositoryPath: repo.root.path,
    startingRevision: repo.startingRevision,
    requiredCapabilities: const {WorkerCapability.linux},
    role: AgentRole.implementer,
    instruction: 'Onboard the repository.',
    timeoutSeconds: timeoutSeconds,
    runtimeTypeId: 'onboarding',
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    // Absolute paths only: the default EnvironmentPolicy resolves an
    // empty environment, so the spawned commands cannot rely on PATH.
    runtimeConfig: const {
      'buildCommand': '/bin/sh -c true',
      'testCommand': '/bin/sh -c true',
    },
  );

  group('an onboarding drive wedged at an unbounded await', () {
    test(
      'abandons at the whole-run bound, writes timedOut and frees the lease',
      () async {
        final store = InMemoryWorkerStore();
        // The wedge stands in for any unbounded await in the drive — the
        // F-226 candidates were prepare, event writes, inspection, cleanup
        // and the terminal write.
        final gatedWorkspace = _GatedWorkspaceManager(workspaceManager)
          ..wedgePrepare = true;
        final worker = buildWorker(store: store, manager: gatedWorkspace);

        final elapsed = Stopwatch()..start();
        final result = await worker.run(buildRequest('onb-wedge'));
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

        // The lease is free and the worker reads idle again.
        expect(worker.isAcquirable, isTrue);
        expect(worker.toRegistration().currentLoad, 0);

        // The durable record was marked terminal, honestly — the zombie
        // sweep is no longer the only thing that can end it.
        final persisted = await store.readWorkerExecution('onb-wedge');
        expect(persisted?.status, WorkerExecutionStatus.timedOut);
        expect(persisted?.failureCode, WorkerFailureCode.timedOut);
        final savedResult = await store.readResult('onb-wedge');
        expect(savedResult?.status, WorkerExecutionStatus.timedOut);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'the freed worker takes the next run normally',
      () async {
        final store = InMemoryWorkerStore();
        final gatedWorkspace = _GatedWorkspaceManager(workspaceManager)
          ..wedgePrepare = true;
        final worker = buildWorker(store: store, manager: gatedWorkspace);

        final abandoned = await worker.run(buildRequest('onb-first'));
        expect(abandoned.status, WorkerExecutionStatus.timedOut);

        gatedWorkspace.wedgePrepare = false;
        final result = await worker.run(buildRequest('onb-second'));

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
        final gatedWorkspace = _GatedWorkspaceManager(workspaceManager)
          ..wedgePrepare = true;
        final worker = buildWorker(
          store: store,
          manager: gatedWorkspace,
          abandonStepBound: const Duration(milliseconds: 300),
        );

        final elapsed = Stopwatch()..start();
        final result = await worker.run(buildRequest('onb-dead-store'));
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
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('the detached onboarding drive that unwedges later', () {
    test('resumed before its first write prepares nothing and cannot take '
        'the slot back', () async {
      final inner = InMemoryWorkerStore();
      // Hold every inTransaction open on a gate the test controls: the
      // drive wedges in its FIRST write, before any workspace exists.
      final store = _GatedStore(inner)..closeGate();
      final gatedWorkspace = _GatedWorkspaceManager(workspaceManager);
      final worker = buildWorker(
        store: store,
        manager: gatedWorkspace,
        abandonStepBound: const Duration(milliseconds: 300),
      );

      final result = await worker.run(buildRequest('onb-gated'));
      expect(result.status, WorkerExecutionStatus.timedOut);
      expect(worker.isAcquirable, isTrue);
      expect(gatedWorkspace.prepareCalls, isEmpty);

      // Now let the wedged await unwind. The detached drive resumes at
      // the top of the transaction body — and MUST NOT resurrect its
      // acquiring row or prepare a workspace on a slot it no longer owns.
      store.openGate();
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(
        gatedWorkspace.prepareCalls,
        isEmpty,
        reason:
            'an abandoned drive that unwedges must bail out rather than '
            'prepare a workspace nobody is waiting for',
      );
      expect(
        await inner.readWorkerExecution('onb-gated'),
        isNull,
        reason:
            'the fenced transaction body must not resurrect the '
            'acquiring row on a run that already settled',
      );
      expect(
        worker.isAcquirable,
        isTrue,
        reason:
            'the detached drive must never take the lease back — that '
            'would starve the slot a second time',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'cannot clear the lease of a successor run that took the freed slot',
      () async {
        final inner = InMemoryWorkerStore();
        final store = _GatedStore(inner)..closeGate();
        final gatedWorkspace = _GatedWorkspaceManager(workspaceManager)
          ..armCleanupGate();
        final worker = buildWorker(
          store: store,
          manager: gatedWorkspace,
          abandonStepBound: const Duration(milliseconds: 300),
        );

        final abandoned = await worker.run(buildRequest('onb-stale'));
        expect(abandoned.status, WorkerExecutionStatus.timedOut);
        expect(worker.isAcquirable, isTrue);

        // A successor takes the freed slot and parks on gates of its own —
        // a slow-but-alive drive, not a wedged one. The stale drive's gate
        // stays shut for now.
        final successorStoreGate = Completer<void>();
        store.releaseTo(heldBy: successorStoreGate);
        final successor = worker.run(
          buildRequest('onb-successor', timeoutSeconds: 8),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          worker.isAcquirable,
          isFalse,
          reason: 'the successor holds the slot now',
        );

        // Let the successor run until it is parked at the gated cleanup
        // (its FIRST cleanup call — the stale run never reached one)
        // holding the lease, THEN unwind the stale drive into the window
        // where a late lease-clear would hurt.
        successorStoreGate.complete();
        final deadline = DateTime.now().add(const Duration(seconds: 7));
        while (DateTime.now().isBefore(deadline)) {
          if (gatedWorkspace.cleanupCalls.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(
          gatedWorkspace.cleanupCalls,
          isNotEmpty,
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
          gatedWorkspace.prepareCalls,
          hasLength(1),
          reason:
              'the stale drive bails before its prepare; only the '
              'successor ran real work',
        );

        gatedWorkspace.openCleanupGate();
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

    test('wedged inside the inspection: the resumed drive writes nothing — '
        'the terminal row and the saved result stay the abandon '
        "path's", () async {
      final store = InMemoryWorkerStore();
      // Wedge the platform's own git inspection — one of the
      // post-command awaits nothing bounded before F-232.
      final inspector = _GatedInspector()..armGate();
      final worker = buildWorker(store: store, inspector: inspector);

      // Drive the run WITHOUT awaiting so the test can confirm the
      // drive reached the inspection wedge before the whole-run bound
      // fires — otherwise this exercises the wrong stage.
      final runFuture = worker.run(
        buildRequest('onb-inspect', timeoutSeconds: 4),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (inspector.inspectCalls.isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(
        inspector.inspectCalls,
        isNotEmpty,
        reason:
            'the drive must reach the inspection await and wedge there '
            'before the bound fires — this call arriving pre-bound is '
            'what makes the resume below exercise the post-checkpoint '
            'fences',
      );

      final abandoned = await runFuture;
      expect(abandoned.status, WorkerExecutionStatus.timedOut);
      expect(
        (await store.readWorkerExecution('onb-inspect'))?.status,
        WorkerExecutionStatus.timedOut,
      );

      // Unwedge the inspection. The abandoned run's workspace was already
      // removed by the abandon path, so the resumed inspect fails into
      // the stale catch — and even a clean return would hit the
      // post-inspection fence. Either way the workspaceReady event, the
      // cleanup record and _finish are writes the resumed drive must
      // never reach.
      inspector.openGate();
      await Future<void>.delayed(const Duration(seconds: 1));

      final persisted = await store.readWorkerExecution('onb-inspect');
      expect(
        persisted?.status,
        WorkerExecutionStatus.timedOut,
        reason:
            'a resumed detached drive must not CAS-overwrite the terminal '
            'row the abandon path wrote',
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
        (await store.readResult('onb-inspect'))?.status,
        WorkerExecutionStatus.timedOut,
        reason: 'the saved result must not be overwritten either',
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
      final worker = buildWorker(
        store: store,
        manager: gatedWorkspace,
        abandonStepBound: const Duration(milliseconds: 300),
      );

      // Drive the run WITHOUT awaiting so the test can confirm the
      // drive reached the cleanup wedge before the whole-run bound
      // fires — otherwise this exercises the wrong stage.
      final runFuture = worker.run(
        buildRequest('onb-cleanup', timeoutSeconds: 8),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 7));
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
            'gated call rather than the abandon path’s',
      );

      final abandoned = await runFuture;
      expect(abandoned.status, WorkerExecutionStatus.timedOut);
      expect(
        (await store.readWorkerExecution('onb-cleanup'))?.status,
        WorkerExecutionStatus.timedOut,
      );

      // Unwedge the cleanup. The detached drive resumes into
      // _setCleanup and _finish — the two blind upserts this
      // regression covers — and must be fenced out of both.
      gatedWorkspace.openCleanupGate();
      await Future<void>.delayed(const Duration(seconds: 1));

      final persisted = await store.readWorkerExecution('onb-cleanup');
      expect(
        persisted?.status,
        WorkerExecutionStatus.timedOut,
        reason:
            'the resumed drive’s blind cleanup-record upsert would '
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
        (await store.readResult('onb-cleanup'))?.status,
        WorkerExecutionStatus.timedOut,
        reason: 'the saved result must not be overwritten either',
      );
      expect(await workspaceManager.discoverAll(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

/// A [GitWorkspaceInspector] that holds the FIRST `inspect` call on a
/// gate the test controls — the shape of the drive wedging inside the
/// platform's own git read, one of the post-command awaits nothing
/// bounded before F-232.
class _GatedInspector extends GitWorkspaceInspector {
  _GatedInspector();

  Completer<void>? _gate;
  final inspectCalls = <String>[];

  void armGate() => _gate = Completer<void>();

  void openGate() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<GitWorkspaceInspection> inspect(
    String worktreePath, {
    required String startingRevision,
  }) async {
    inspectCalls.add(worktreePath);
    final gate = _gate;
    if (gate != null) await gate.future;
    return super.inspect(worktreePath, startingRevision: startingRevision);
  }
}

/// A [WorkspaceManager] that forwards to a real manager but can wedge
/// `prepare` outright — the shape of an unbounded await early in the
/// drive — and holds the FIRST `cleanup` call on a gate the test
/// controls: the shape of the drive wedging inside the cleanup await
/// that precedes the blind `_setCleanup` upsert. Only the first cleanup
/// call is gated: the abandon path's own cleanup must still run so the
/// terminal row is written with the honest outcome.
class _GatedWorkspaceManager implements WorkspaceManager {
  _GatedWorkspaceManager(this._inner);

  final WorkspaceManager _inner;
  Completer<void>? _cleanupGate;
  var _callIndex = 0;
  var wedgePrepare = false;
  final prepareCalls = <String>[];
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
  }) {
    prepareCalls.add(request.workerExecutionId);
    if (wedgePrepare) {
      // Never completes: the wedged await.
      return Completer<WorkspaceDescriptor>().future;
    }
    return _inner.prepare(request, workerId: workerId);
  }

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
