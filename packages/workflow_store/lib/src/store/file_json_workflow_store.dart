import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'workflow_store.dart';

/// A durable [WorkflowStore] backed by a single JSON document on disk.
///
/// Every mutation is written to a temp file in the same directory and then
/// atomically renamed over the target, so a crash never leaves a truncated
/// document. State is fully reloaded from disk on construction, which is what
/// makes the process-exit resume test meaningful: a brand new instance backed
/// by the same [File] observes everything the previous instance persisted.
class FileJsonWorkflowStore implements WorkflowStore {
  FileJsonWorkflowStore(this._file) {
    _load();
  }

  final File _file;

  final Map<String, WorkItem> _workItems = {};
  final Map<String, HumanDecision> _decisions = {};
  final Map<String, WorkflowTransitionRecord> _records = {};

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    final item = _workItems[workItemId];
    if (item == null) {
      throw WorkItemNotFoundException(workItemId);
    }
    return item;
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() async => _workItems.values.toList();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    _checkVersion(item, expectedVersion);
    _workItems[item.workItemId] = item;
    await _persist();
  }

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) async {
    final decision = _decisions[decisionId];
    if (decision == null) {
      throw HumanDecisionNotFoundException(decisionId);
    }
    return decision;
  }

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) async {
    return _decisions.values.where((d) => d.workItemId == workItemId).toList();
  }

  @override
  Future<void> saveHumanDecision(HumanDecision decision) async {
    _decisions[decision.decisionId] = decision;
    await _persist();
  }

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) async {
    return _records.values.where((r) => r.workItemId == workItemId).toList();
  }

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) async {
    for (final record in _records.values) {
      if (record.workItemId == workItemId &&
          record.idempotencyKey == idempotencyKey) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) async {
    _records[record.transitionId] = record;
    await _persist();
  }

  void _checkVersion(WorkItem item, int? expectedVersion) {
    if (expectedVersion == null) {
      return;
    }
    final current = _workItems[item.workItemId];
    final actual = current?.version ?? 0;
    if (actual != expectedVersion) {
      throw ConcurrentModificationException(
        entityId: item.workItemId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }
  }

  void _load() {
    if (!_file.existsSync()) {
      return;
    }
    final decoded =
        jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    final workItems = decoded['workItems'] as Map<String, dynamic>? ?? {};
    final decisions = decoded['humanDecisions'] as Map<String, dynamic>? ?? {};
    final records = decoded['transitionRecords'] as Map<String, dynamic>? ?? {};

    workItems.forEach((id, json) {
      _workItems[id] = WorkItem.fromJson(json as Map<String, dynamic>);
    });
    decisions.forEach((id, json) {
      _decisions[id] = HumanDecision.fromJson(json as Map<String, dynamic>);
    });
    records.forEach((id, json) {
      _records[id] = WorkflowTransitionRecord.fromJson(
        json as Map<String, dynamic>,
      );
    });
  }

  Future<void> _persist() async {
    final document = <String, dynamic>{
      'workItems': _workItems.map((id, item) => MapEntry(id, item.toJson())),
      'humanDecisions': _decisions.map(
        (id, decision) => MapEntry(id, decision.toJson()),
      ),
      'transitionRecords': _records.map(
        (id, record) => MapEntry(id, _recordToJsonMap(record)),
      ),
    };

    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    await temp.rename(_file.path);
  }

  Map<String, dynamic> _recordToJsonMap(WorkflowTransitionRecord record) {
    // WorkflowTransitionRecord (raw enums in json_serializable) serializes
    // via its own toJson; keep the map round-trip stable.
    return record.toJson();
  }
}
