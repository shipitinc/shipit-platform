import 'package:platform_contracts/platform_contracts.dart';

import 'workflow_store.dart';

/// A non-durable [WorkflowStore] for tests and single-instance usage.
class InMemoryWorkflowStore implements WorkflowStore {
  final Map<String, WorkItem> _workItems = {};
  final Map<String, HumanDecision> _decisions = {};
  final Map<String, WorkflowTransitionRecord> _records = {};

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) async => body(this);

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
}
