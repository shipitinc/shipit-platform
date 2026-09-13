import 'package:platform_contracts/platform_contracts.dart';

/// A durable container for the state a workflow needs to resume after a
/// process exit: the work item, its pending/resolved human decisions, and an
/// append-only transition history.
abstract interface class WorkflowStore {
  Future<WorkItem> readWorkItem(String workItemId);

  Future<List<WorkItem>> readAllWorkItems();

  /// Persists [item]. When [expectedVersion] is provided the write is a
  /// compare-and-swap against the currently stored version and fails with
  /// [ConcurrentModificationException] on mismatch, so concurrent writers
  /// cannot silently overwrite each other.
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion});

  Future<HumanDecision> readHumanDecision(String decisionId);

  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(String workItemId);

  Future<void> saveHumanDecision(HumanDecision decision);

  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  );

  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  );

  Future<void> appendTransitionRecord(WorkflowTransitionRecord record);
}

class WorkItemNotFoundException implements Exception {
  WorkItemNotFoundException(this.workItemId);

  final String workItemId;

  @override
  String toString() => 'Work item not found: $workItemId';
}

class HumanDecisionNotFoundException implements Exception {
  HumanDecisionNotFoundException(this.decisionId);

  final String decisionId;

  @override
  String toString() => 'Human decision not found: $decisionId';
}

class ConcurrentModificationException implements Exception {
  ConcurrentModificationException({
    required this.entityId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String entityId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of $entityId (expected version '
      '$expectedVersion, actual $actualVersion)';
}
