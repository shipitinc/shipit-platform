import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'execution_store.dart';

/// A durable [ExecutionStore] backed by a single JSON document on disk.
///
/// Every mutation is written to a temp file in the same directory and then
/// atomically renamed over the target, so a crash never leaves a truncated
/// document. State is fully reloaded from disk on construction, which makes
/// process-exit resume/reconcile tests meaningful: a brand new instance backed
/// by the same [File] observes everything the previous instance persisted.
class FileJsonExecutionStore implements ExecutionStore {
  FileJsonExecutionStore(this._file) {
    _load();
  }

  final File _file;

  final Map<String, AgentExecutionRequest> _requests = {};
  final Map<String, AgentExecution> _executions = {};
  final Map<String, AgentEventRecord> _events = {};
  final Map<String, AgentResult> _results = {};
  final Map<String, PlatformVerification> _verifications = {};

  /// Chains every [File.rename]-based write so concurrent mutations (e.g.
  /// event records appended from a stream listener) cannot race the same temp
  /// file, which would otherwise break the atomic rename with ENOENT.
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> _persist() {
    final write = _pendingWrite.then((_) => _writeDocument());
    _pendingWrite = write.then((_) {}, onError: (_) {});
    return write;
  }

  Future<void> _writeDocument() async {
    final document = <String, dynamic>{
      'requests': _requests.map((id, r) => MapEntry(id, r.toJson())),
      'executions': _executions.map((id, e) => MapEntry(id, e.toJson())),
      'events': _events.map((id, e) => MapEntry(id, e.toJson())),
      'results': _results.map((id, r) => MapEntry(id, r.toJson())),
      'verifications': _verifications.map((id, v) => MapEntry(id, v.toJson())),
    };

    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    await temp.rename(_file.path);
  }

  @override
  Future<void> saveRequest(AgentExecutionRequest request) async {
    _requests[request.executionId] = request;
    await _persist();
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
    await _persist();
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
      if (latest == null ||
          (execution.startedAt != null &&
              (latest.startedAt == null ||
                  execution.startedAt!.isAfter(latest.startedAt!)))) {
        latest = execution;
      }
    }
    return latest;
  }

  @override
  Future<void> appendEvent(AgentEventRecord event) async {
    _events[event.eventId] = event;
    await _persist();
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
    await _persist();
  }

  @override
  Future<AgentResult?> readResult(String executionId) async {
    return _results[executionId];
  }

  @override
  Future<void> saveVerification(PlatformVerification verification) async {
    _verifications[verification.verificationId] = verification;
    await _persist();
  }

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    return _verifications.values
        .where((v) => v.executionId == executionId)
        .toList();
  }

  void _load() {
    if (!_file.existsSync()) {
      return;
    }
    final decoded =
        jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    final requests = decoded['requests'] as Map<String, dynamic>? ?? {};
    final executions = decoded['executions'] as Map<String, dynamic>? ?? {};
    final events = decoded['events'] as Map<String, dynamic>? ?? {};
    final results = decoded['results'] as Map<String, dynamic>? ?? {};
    final verifications =
        decoded['verifications'] as Map<String, dynamic>? ?? {};

    requests.forEach((id, json) {
      _requests[id] = AgentExecutionRequest.fromJson(
        json as Map<String, dynamic>,
      );
    });
    executions.forEach((id, json) {
      _executions[id] = AgentExecution.fromJson(json as Map<String, dynamic>);
    });
    events.forEach((id, json) {
      _events[id] = AgentEventRecord.fromJson(json as Map<String, dynamic>);
    });
    results.forEach((id, json) {
      _results[id] = AgentResult.fromJson(json as Map<String, dynamic>);
    });
    verifications.forEach((id, json) {
      _verifications[id] = PlatformVerification.fromJson(
        json as Map<String, dynamic>,
      );
    });
  }
}
