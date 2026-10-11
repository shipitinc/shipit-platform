import 'package:platform_contracts/platform_contracts.dart';

import '../operator_action_record.dart';

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

  /// APPENDS one operator action. Append-only: there is no update or delete
  /// counterpart on this interface, and none may be added.
  ///
  /// This is the only way an [OperatorActionRecord] is written. In particular
  /// there is no code path that appends one outside the transaction
  /// `DurableWorkflowEngine.transition` already opens, which is what makes an
  /// audit row and the state change it authorises commit or roll back together.
  /// Implementations MUST enforce `operator_action_request_unique` on
  /// `(workItemId, requestId)`: a replay of the same operator intent collides
  /// rather than creating a second row, a second job, or a second spend.
  Future<void> appendOperatorAction(OperatorActionRecord record);

  /// Operator actions recorded against [workItemId], OLDEST FIRST.
  ///
  /// ONE read serves both needs, so no second read method exists: the replay
  /// check selects the row whose `requestId` matches, and the attempt count is
  /// the number of rows whose `action` is 'retry'. The count is
  /// order-independent; `requestId` is unique per work item, so the replay
  /// check cannot find two candidates to be ambiguous about.
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  );

  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) async => body(this);
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

/// Raised when an operator action would duplicate `(workItemId, requestId)`.
///
/// PostgreSQL enforces the same rule with `operator_action_request_unique`;
/// this is what the stores without a database say instead, so a replay is
/// refused everywhere rather than only in production.
class OperatorActionConflictException implements Exception {
  OperatorActionConflictException(this.record);

  final OperatorActionRecord record;

  @override
  String toString() =>
      'Operator action ${record.requestId} already recorded for '
      '${record.workItemId}';
}
