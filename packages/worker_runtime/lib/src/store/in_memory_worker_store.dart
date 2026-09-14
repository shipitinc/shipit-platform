import 'package:platform_contracts/platform_contracts.dart';

import 'worker_store.dart';

class InMemoryWorkerStore implements WorkerStore {
  final Map<String, WorkerExecution> _executions = {};
  final Map<String, WorkerEventRecord> _events = {};
  final Map<String, WorkerExecutionResult> _results = {};

  @override
  Future<void> saveWorkerExecution(
    WorkerExecution execution, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final current = _executions[execution.workerExecutionId];
      final actual = current?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentWorkerModificationException(
          workerExecutionId: execution.workerExecutionId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _executions[execution.workerExecutionId] = execution;
  }

  @override
  Future<WorkerExecution?> readWorkerExecution(String id) async =>
      _executions[id];

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async =>
      _executions.values.toList();

  @override
  Future<void> saveResult(WorkerExecutionResult result) async {
    _results[result.workerExecutionId] = result;
  }

  @override
  Future<WorkerExecutionResult?> readResult(String id) async => _results[id];

  @override
  Future<void> appendEvent(WorkerEventRecord event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<List<WorkerEventRecord>> readEvents(String id) async {
    final events = _events.values.where((e) => e.workerExecutionId == id);
    final sorted = events.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }
}
