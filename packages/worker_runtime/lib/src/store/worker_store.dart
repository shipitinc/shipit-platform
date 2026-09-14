import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for everything one worker execution persists for
/// resume/reconciliation and audit: the [WorkerExecution] state record,
/// normalized [WorkerEventRecord]s, and the terminal [WorkerExecutionResult].
abstract interface class WorkerStore {
  Future<void> saveWorkerExecution(
    WorkerExecution execution, {
    int? expectedVersion,
  });

  Future<WorkerExecution?> readWorkerExecution(String workerExecutionId);

  Future<List<WorkerExecution>> listWorkerExecutions();

  Future<void> saveResult(WorkerExecutionResult result);

  Future<WorkerExecutionResult?> readResult(String workerExecutionId);

  Future<void> appendEvent(WorkerEventRecord event);

  Future<List<WorkerEventRecord>> readEvents(String workerExecutionId);

  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerStore store) body,
  ) async => body(this);
}

class WorkerExecutionNotFoundException implements Exception {
  WorkerExecutionNotFoundException(this.workerExecutionId);

  final String workerExecutionId;

  @override
  String toString() => 'Worker execution not found: $workerExecutionId';
}

class ConcurrentWorkerModificationException implements Exception {
  ConcurrentWorkerModificationException({
    required this.workerExecutionId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String workerExecutionId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of worker execution $workerExecutionId '
      '(expected version $expectedVersion, actual $actualVersion)';
}
