import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

/// A single execution slot: the worker owns the runtime environment in which
/// exactly one execution may run at a time (capacity-1 lease). A worker never
/// decides workflow outcomes or agent results; it only provides a bounded,
/// isolated place for one [WorkerExecutionRequest] to run.
abstract interface class Worker {
  String get workerId;

  String get poolId;

  Set<WorkerCapability> get capabilities;

  /// Host platform descriptor (e.g. `macos-14`); capability matching never
  /// depends on it.
  String? get platform;

  /// Capacity-1 lease state: [acquire] takes the slot, [release] frees it.
  bool get isAcquirable;

  Future<void> acquire();

  Future<void> release();

  /// Runs one execution from start to terminal state, applying the request's
  /// cleanup policy. Returns the typed result; throws on dispatch errors.
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request);

  /// Best-effort cancel of the in-flight execution's agent session.
  Future<void> cancel(String reason);

  /// A snapshot of this worker in [WorkerProtocol] terms for pure, typed
  /// capability selection without touching worker internals.
  WorkerRegistration toRegistration({WorkerStatus status = WorkerStatus.idle});
}
