import 'dart:async';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// A fully scriptable [WorkerDispatch] that never touches the real worker
/// stack. Used to deterministically exercise the scheduler's queue, claim
/// CAS, lease reconciliation, and crash-recovery paths (where the real
/// stack's git/agent machinery would introduce nondeterminism).
class ControlledDispatcher implements WorkerDispatch {
  ControlledDispatcher({
    Set<WorkerCapability> capabilities = const {},
    this.workerStore,
  }) : _capabilities = capabilities;

  final Set<WorkerCapability> _capabilities;

  /// When set, `run` persists the terminal worker execution row and the
  /// [WorkerExecutionResult] BEFORE it returns — the same durable tail
  /// `LocalWorker._finish` commits — so the scheduler's reconcile-adoption
  /// path (`_reconcileClaim` -> `_adoptFromExecution`) can settle the job from
  /// durable state exactly the way it does after a real run or a restart.
  /// Without it a finished run leaves no durable record and reconcile can only
  /// requeue the job for want of a referenced execution.
  ///
  /// Mutable rather than final so a harness can wire its own store into a
  /// dispatcher it was handed — the store's owner is the harness, not the
  /// fake's construction site.
  WorkerStore? workerStore;

  final _runs = <WorkerExecutionRequest>[];
  final _cancellations = <(String, String)>[];
  final _resultsByWorkerExecutionId = <String, WorkerExecutionResult>{};

  /// When true, [run] throws WorkerDispatchException before any execution
  /// exists — simulating a crash between claim and dispatch.
  bool failRun = false;

  /// When non-null, [run] throws [urgentError] instead of returning a result.
  Object? urgentError;

  /// When true, a run is accepted and completes; otherwise the "pool" is busy
  /// (no acquirable worker) and selection reports [WorkerDispatchOutcome.workerBusy].
  int capacity = 1;

  /// When set, `run` resolves to exactly what this returns instead of building
  /// the default [WorkerExecutionStatus.executedPass] result.
  ///
  /// Lets a test hand the scheduler a PRECISE terminal outcome — in particular a
  /// supersession, whose entire identity is a string on `failureDetail` — plus
  /// whatever durable state must have moved by the time adoption reads it. The
  /// hook is awaited, so it may itself move a work item: that is the only
  /// deterministic way to reproduce "the item moved between dispatch and
  /// adoption", which against the real stack is a race with no fixed schedule.
  FutureOr<WorkerExecutionResult> Function(WorkerExecutionRequest request)?
  resultBuilder;

  /// What each accepted run resolves to. Defaults to executedPass.
  Iterable<WorkerExecutionStatus> Function() statusSeries = () => const [
    WorkerExecutionStatus.executedPass,
  ];

  int _runsStarted = 0;
  var _inFlight = 0;

  List<WorkerExecutionRequest> get runs => List.unmodifiable(_runs);
  List<(String, String)> get cancellations => List.unmodifiable(_cancellations);

  /// True while at least one accepted run is still parked (capacity consumed).
  /// A count rather than a flag because dispatch is detached: two runs may be
  /// in flight at once, and the first to finish must not zero the signal.
  bool get hasRunInFlight => _inFlight > 0;

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    if (capacity > 0) {
      return WorkerSelection.dispatched(
        WorkerRegistration(
          workerId: 'w-scripted-1',
          poolId: 'scripted-pool',
          capabilities: {
            for (final c in {..._capabilities, ...request.requiredCapabilities})
              c: CapabilitySpec(capability: c, version: '1'),
          },
          status: WorkerStatus.idle,
          currentLoad: _inFlight > 0 ? 1 : 0,
          maxConcurrency: 1,
          lastHeartbeat: DateTime.now(),
        ),
      );
    }
    return WorkerSelection.busy(compatibleWorkers: const []);
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    if (failRun) {
      throw const WorkerDispatchException(
        WorkerDispatchOutcome.workerBusy,
        workerId: 'w-scripted-1',
      );
    }
    _runs.add(request);
    _inFlight++;
    _runsStarted++;
    try {
      if (urgentError != null) throw urgentError!;
      final builder = resultBuilder;
      if (builder != null) {
        final scripted = await builder(request);
        _resultsByWorkerExecutionId[request.workerExecutionId] = scripted;
        await _persistTerminal(request, scripted);
        return scripted;
      }
      final series = statusSeries();
      final status = series.length == 1
          ? series.first
          : series.elementAt(_runsStarted - 1);
      await Future<void>.delayed(Duration.zero);
      final t = DateTime.now().toUtc();
      final result = WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: status,
        workerId: 'w-scripted-1',
        workspaceId: 'ws-${request.workerExecutionId}',
        startingRevision: request.startingRevision,
        startedAt: t,
        endedAt: t,
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: status == WorkerExecutionStatus.prepareFailed
            ? WorkerFailureCode.prepareFailed
            : WorkerFailureCode.none,
        failureDetail: status == WorkerExecutionStatus.prepareFailed
            ? 'scripted prepare failure'
            : null,
      );
      _resultsByWorkerExecutionId[request.workerExecutionId] = result;
      await _persistTerminal(request, result);
      return result;
    } finally {
      _inFlight--;
    }
  }

  /// The durable tail `LocalWorker` commits inside its terminal transaction:
  /// the execution row in its terminal status plus the stored result, so the
  /// scheduler's reconcile-adoption path settles this job from durable state
  /// rather than from the returned future.
  Future<void> _persistTerminal(
    WorkerExecutionRequest request,
    WorkerExecutionResult result,
  ) async {
    final store = workerStore;
    if (store == null) return;
    await persistWorkerOutcome(store, request, result);
  }

  @override
  Future<void> cancel(String workerId, String reason) async {
    _cancellations.add((workerId, reason));
  }
}

/// The durable tail a real worker commits before `run` returns: the terminal
/// [WorkerExecution] row plus the stored [WorkerExecutionResult]. Any
/// [WorkerDispatch] test double that plays a completed run must persist this
/// pair, or the scheduler's reconcile-adoption path finds no durable record
/// and can only requeue the job for want of a referenced execution.
Future<void> persistWorkerOutcome(
  WorkerStore store,
  WorkerExecutionRequest request,
  WorkerExecutionResult result,
) async {
  await store.saveWorkerExecution(
    WorkerExecution(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      repositoryPath: request.repositoryPath,
      requestedStartingRevision: request.startingRevision,
      requiredCapabilities: request.requiredCapabilities,
      status: result.status,
      cleanupPolicy: request.cleanupPolicy,
      workerId: result.workerId,
      workspaceId: result.workspaceId,
      agentExecutionId: result.agentExecutionId,
      cleanupStatus: result.cleanupStatus,
      failureCode: result.failureCode,
      reason: result.failureDetail,
      createdAt: result.startedAt,
      startedAt: result.startedAt,
      endedAt: result.endedAt,
    ),
  );
  // The scheduler's JobExecutionReference names the REQUEST's execution id,
  // so the stored result is keyed under it even when the dispatcher reports
  // a different one — `readResult(ref)` must hit for adoption to see the
  // reported agentExecutionId. The reported id stays on the record itself.
  final stored = result.workerExecutionId == request.workerExecutionId
      ? result
      : WorkerExecutionResult(
          workerExecutionId: request.workerExecutionId,
          workItemId: result.workItemId,
          status: result.status,
          workerId: result.workerId,
          workspaceId: result.workspaceId,
          startingRevision: result.startingRevision,
          startedAt: result.startedAt,
          endedAt: result.endedAt,
          cleanupStatus: result.cleanupStatus,
          failureCode: result.failureCode,
          failureDetail: result.failureDetail,
          agentExecutionId: result.agentExecutionId,
        );
  await store.saveResult(stored);
}
