import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// The worker-facing surface the scheduler depends on: pure capability
/// selection, a bounded run, and cancellation. The scheduler never touches a
/// worker registry or worker lifecycle directly (worker_runtime owns that);
/// it only asks for the same allocation decisions a screwdriver would.
abstract interface class WorkerDispatch {
  WorkerSelection select(WorkerExecutionRequest request);

  Future<WorkerExecutionResult> run(WorkerExecutionRequest request);

  /// Requests a graceful cancel of the currently-running execution on
  /// [workerId]; harmless when nothing is running.
  Future<void> cancel(String workerId, String reason);
}

/// Adapts the worker_runtime [WorkerDispatcher] into [WorkerDispatch].
///
/// Placement logic, acquire/release, workspaces, and coordination all remain
/// owned by worker_runtime; this adapter only forwards. Cancellation reaches
/// the specific worker through the dispatcher's live [WorkerRegistry], so a
/// scheduler instance can interrupt *its own* executions without owning the
/// pool.
class WorkerDispatcherAdapter implements WorkerDispatch {
  const WorkerDispatcherAdapter(this._dispatcher);

  final WorkerDispatcher _dispatcher;

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      _dispatcher.select(request);

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      _dispatcher.run(request);

  @override
  Future<void> cancel(String workerId, String reason) async {
    final worker = _dispatcher.registry.byId(workerId);
    await worker?.cancel(reason);
  }
}
