import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// A fully scriptable [WorkerDispatch] that never touches the real worker
/// stack. Used to deterministically exercise the scheduler's queue, claim
/// CAS, lease reconciliation, and crash-recovery paths (where the real
/// stack's git/agent machinery would introduce nondeterminism).
class ControlledDispatcher implements WorkerDispatch {
  ControlledDispatcher({Set<WorkerCapability> capabilities = const {}})
    : _capabilities = capabilities;

  final Set<WorkerCapability> _capabilities;

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

  /// What each accepted run resolves to. Defaults to executedPass.
  Iterable<WorkerExecutionStatus> Function() statusSeries = () => const [
    WorkerExecutionStatus.executedPass,
  ];

  int _runsStarted = 0;
  var _inFlight = false;

  List<WorkerExecutionRequest> get runs => List.unmodifiable(_runs);
  List<(String, String)> get cancellations => List.unmodifiable(_cancellations);

  /// Completes when a run is in flight and parked (capacity consumed).
  bool get hasRunInFlight => _inFlight;

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
          currentLoad: _inFlight ? 1 : 0,
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
    _inFlight = true;
    _runsStarted++;
    if (urgentError != null) throw urgentError!;
    final series = statusSeries();
    final status = series.length == 1
        ? series.first
        : series.elementAt(_runsStarted - 1);
    await Future<void>.delayed(Duration.zero);
    _inFlight = false;
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
    return result;
  }

  @override
  Future<void> cancel(String workerId, String reason) async {
    _cancellations.add((workerId, reason));
  }
}
