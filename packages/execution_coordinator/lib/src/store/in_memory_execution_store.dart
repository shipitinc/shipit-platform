import 'package:platform_contracts/platform_contracts.dart';

import 'execution_store.dart';

/// A non-durable [ExecutionStore] for tests and single-instance usage.
class InMemoryExecutionStore implements ExecutionStore {
  final Map<String, AgentExecutionRequest> _requests = {};
  final Map<String, AgentExecution> _executions = {};
  final Map<String, AgentEventRecord> _events = {};
  final Map<String, AgentResult> _results = {};
  final Map<String, PlatformVerification> _verifications = {};

  @override
  Future<void> saveRequest(AgentExecutionRequest request) async {
    _requests[request.executionId] = request;
  }

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) async {
    return _requests[executionId];
  }

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final current = _executions[execution.executionId];
      final actual = current?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentExecutionModificationException(
          executionId: execution.executionId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _executions[execution.executionId] = execution;
  }

  @override
  Future<AgentExecution> readExecution(String executionId) async {
    final execution = _executions[executionId];
    if (execution == null) {
      throw ExecutionNotFoundException(executionId);
    }
    return execution;
  }

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) async {
    return _executions[executionId];
  }

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) async {
    final items = _executions.values.toList();
    if (workItemId == null) return items;
    return items.where((e) => e.workItemId == workItemId).toList();
  }

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) async {
    AgentExecution? latest;
    for (final execution in _executions.values) {
      if (execution.workItemId != workItemId) continue;
      if (latest == null || execution.startedAt!.isAfter(latest.startedAt!)) {
        latest = execution;
      }
    }
    return latest;
  }

  @override
  Future<void> appendEvent(AgentEventRecord event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) async {
    final events =
        _events.values.where((e) => e.executionId == executionId).toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return events;
  }

  @override
  Future<void> saveResult(String executionId, AgentResult result) async {
    _results[executionId] = result;
  }

  @override
  Future<AgentResult?> readResult(String executionId) async {
    return _results[executionId];
  }

  @override
  Future<void> saveVerification(PlatformVerification verification) async {
    _verifications[verification.verificationId] = verification;
  }

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    return _verifications.values
        .where((v) => v.executionId == executionId)
        .toList();
  }
}
