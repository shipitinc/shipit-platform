import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for everything one agent execution persists for resume:
/// the execution request, the [AgentExecution] state record, normalized
/// [AgentEventRecord]s, the final [AgentResult], and platform-collected
/// [PlatformVerification] evidence.
abstract interface class ExecutionStore {
  Future<void> saveRequest(AgentExecutionRequest request);

  Future<AgentExecutionRequest?> readRequest(String executionId);

  Future<void> saveExecution(AgentExecution execution, {int? expectedVersion});

  Future<AgentExecution> readExecution(String executionId);

  Future<AgentExecution?> readExecutionOrNull(String executionId);

  Future<List<AgentExecution>> listExecutions({String? workItemId});

  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId);

  Future<void> appendEvent(AgentEventRecord event);

  Future<List<AgentEventRecord>> readEvents(String executionId);

  Future<void> saveResult(String executionId, AgentResult result);

  Future<AgentResult?> readResult(String executionId);

  Future<void> saveVerification(PlatformVerification verification);

  Future<List<PlatformVerification>> readVerifications(String executionId);

  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(
    Future<T> Function(ExecutionStore store) body,
  ) async => body(this);
}

class ExecutionNotFoundException implements Exception {
  ExecutionNotFoundException(this.executionId);

  final String executionId;

  @override
  String toString() => 'Execution not found: $executionId';
}

class ConcurrentExecutionModificationException implements Exception {
  ConcurrentExecutionModificationException({
    required this.executionId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String executionId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of execution $executionId '
      '(expected version $expectedVersion, actual $actualVersion)';
}
