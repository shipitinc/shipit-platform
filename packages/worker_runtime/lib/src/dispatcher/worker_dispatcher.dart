import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

import '../registry/worker_registry.dart';

/// Thrown when [WorkerDispatcher.run] cannot place a request.
class WorkerDispatchException implements Exception {
  const WorkerDispatchException(this.outcome, {this.workerId});

  final WorkerDispatchOutcome outcome;
  final String? workerId;

  @override
  String toString() => switch (outcome) {
    WorkerDispatchOutcome.noCompatibleWorker =>
      'No compatible worker for the requested capabilities',
    WorkerDispatchOutcome.workerBusy => 'Compatible worker $workerId is busy',
    WorkerDispatchOutcome.dispatched => 'Unexpected dispatch failure',
  };
}

/// Turns a [WorkerExecutionRequest] into a concrete, isolated run on a worker,
/// using the pure [WorkerSelector] for capability/availability decisions.
///
/// Dispatch is placement-only: it never decides whether the execution should
/// happen in workflow terms, and it never touches workflow state directly.
class WorkerDispatcher {
  WorkerDispatcher({required WorkerRegistry registry, WorkerSelector? selector})
    : _registry = registry,
      _selector = selector ?? const WorkerSelector();

  final WorkerRegistry _registry;
  final WorkerSelector _selector;

  /// Pure selection (no side effects). Distinguishes "no compatible worker"
  /// from "compatible but busy" for the reporting contract.
  WorkerSelection select(WorkerExecutionRequest request) {
    return _selector.select(
      requirements: TaskRequirements(
        requiredCapabilities: request.requiredCapabilities,
      ),
      pool: _registry.registrations(),
    );
  }

  /// Runs [request] to a terminal [WorkerExecutionResult] on the determined
  /// worker, or throws [WorkerDispatchException] without side effects.
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    final selection = select(request);
    if (!selection.isDispatched) {
      throw WorkerDispatchException(
        selection.outcome,
        workerId: selection.candidate?.workerId,
      );
    }
    final worker = _registry.byId(selection.candidate!.workerId);
    if (worker == null) {
      throw WorkerDispatchException(
        WorkerDispatchOutcome.noCompatibleWorker,
        workerId: selection.candidate!.workerId,
      );
    }
    // Re-check the live lease: the registration snapshot may be stale.
    if (!worker.isAcquirable) {
      throw WorkerDispatchException(
        WorkerDispatchOutcome.workerBusy,
        workerId: worker.workerId,
      );
    }
    await worker.acquire();
    try {
      return await worker.run(request);
    } finally {
      await worker.release();
    }
  }
}
