import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

/// A [WorkflowStore] that fails exactly one operation: recording a transition.
///
/// Used to simulate a durable-store fault at the precise moment a reclaim
/// moves the work item, so the ORDER of the reclaim's writes can be observed
/// rather than asserted in a comment. Nothing else in a scheduler tick calls
/// this — `RunnableWorkEvaluator` asks the pure transition table, it does not
/// write — so the fault lands on the reclaim and nowhere else.
class FaultyTransitionStore implements WorkflowStore {
  FaultyTransitionStore(this._inner);

  final WorkflowStore _inner;

  /// How many transition-record writes were attempted.
  int attempted = 0;

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) async {
    attempted++;
    throw StateError('durable store unavailable during transition record');
  }

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _inner.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  /// `WorkflowStore` is an `interface class`, so its default bodies are not
  /// inherited by an implementer and every member must be redeclared.
  ///
  /// Deliberately passes `this` as the transaction rather than delegating:
  /// `DurableWorkflowEngine` writes work items and transition records through
  /// the `tx` handed to [inTransaction], so delegating would route the record
  /// write straight past this fault and the test would silently prove nothing.
  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      body(this);
}
