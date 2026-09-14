import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'worker_store.dart';

/// A durable [WorkerStore] backed by a single JSON document on disk.
///
/// Every mutation is written to a temp file and atomically renamed over the
/// target so a crash never leaves a truncated document. A brand new instance
/// backed by the same [File] observes everything the previous instance
/// persisted, which makes worker orphan-reconciliation tests meaningful.
class FileJsonWorkerStore implements WorkerStore {
  FileJsonWorkerStore(this._file) {
    _load();
  }

  final File _file;

  final Map<String, WorkerExecution> _executions = {};
  final Map<String, WorkerEventRecord> _events = {};
  final Map<String, WorkerExecutionResult> _results = {};

  /// Chains every atomic write so concurrent mutations cannot race the same
  /// temp file and break the rename with ENOENT.
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> _persist() {
    final write = _pendingWrite.then((_) => _writeDocument());
    _pendingWrite = write.then((_) {}, onError: (_) {});
    return write;
  }

  Future<void> _writeDocument() async {
    final document = <String, dynamic>{
      'workerExecutions': _executions.map((id, e) => MapEntry(id, e.toJson())),
      'events': _events.map((id, e) => MapEntry(id, e.toJson())),
      'results': _results.map((id, r) => MapEntry(id, r.toJson())),
    };

    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    await temp.rename(_file.path);
  }

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
    await _persist();
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
    await _persist();
  }

  @override
  Future<WorkerExecutionResult?> readResult(String id) async => _results[id];

  @override
  Future<void> appendEvent(WorkerEventRecord event) async {
    _events[event.eventId] = event;
    await _persist();
  }

  @override
  Future<List<WorkerEventRecord>> readEvents(String id) async {
    final events = _events.values.where((e) => e.workerExecutionId == id);
    final sorted = events.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }

  void _load() {
    if (!_file.existsSync()) return;
    final decoded =
        jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    final executions =
        decoded['workerExecutions'] as Map<String, dynamic>? ?? {};
    final events = decoded['events'] as Map<String, dynamic>? ?? {};
    final results = decoded['results'] as Map<String, dynamic>? ?? {};

    executions.forEach((id, json) {
      _executions[id] = WorkerExecution.fromJson(json as Map<String, dynamic>);
    });
    events.forEach((id, json) {
      _events[id] = WorkerEventRecord.fromJson(json as Map<String, dynamic>);
    });
    results.forEach((id, json) {
      _results[id] = WorkerExecutionResult.fromJson(
        json as Map<String, dynamic>,
      );
    });
  }
}
