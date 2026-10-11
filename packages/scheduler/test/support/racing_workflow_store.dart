import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

/// A [WorkflowStore] where another writer wins the compare-and-swap between the
/// engine's read and its save.
///
/// This is the race the review identified as the blocker. `DurableWorkflowEngine
/// .transition` reads the item, then saves with `expectedVersion: item.version`;
/// if a concurrent writer moves the item in between, the store raises
/// [ConcurrentModificationException] and the engine rethrows it out of the
/// transaction. That exception is a SIBLING of
/// [WorkflowTransitionRejectedException], so a caller catching only the rejected
/// case lets it escape entirely.
///
/// Two modes, because they are different failures and must both converge:
///
///  * [racingMode] `versionBump` — the competing writer changes the item without
///    taking it out of `agentExecuting`. A reclaim that catches and moves on
///    would leave the item stranded, so the fix must RETRY.
///  * [racingMode] `takesOver` — the competing writer moves the item itself.
///    The reclaim must NOT fight it.
///
/// The race fires at most [races] times, so a bounded retry converges.
enum RacingMode {
  /// A competing writer bumps the version but leaves the state alone.
  versionBump,

  /// A competing writer moves the item to `takesOverState` itself.
  takesOver,
}

class RacingWorkflowStore implements WorkflowStore {
  RacingWorkflowStore(
    this._inner, {
    this.mode = RacingMode.versionBump,
    this.takesOverState = WorkItemState.agentFailed,
    this.races = 1,
  });

  final WorkflowStore _inner;
  final RacingMode mode;
  final WorkItemState takesOverState;
  final int races;

  /// How many times the race actually fired. A test asserting the race happened
  /// must check this, or it can pass for the wrong reason.
  int fired = 0;

  /// The work item ids whose reads should fail outright, used to force an
  /// unreconcilable row without needing the reclaim to cooperate.
  final Set<String> failingWorkItemIds = {};

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    if (failingWorkItemIds.contains(workItemId)) {
      throw StateError('unreconcilable row for $workItemId');
    }
    return _inner.readWorkItem(workItemId);
  }

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    if (expectedVersion != null && fired < races) {
      fired++;
      final current = await _inner.readWorkItem(item.workItemId);
      // The competing writer commits first, so the caller's CAS is stale.
      await _inner.saveWorkItem(
        mode == RacingMode.takesOver
            ? current.copyWith(
                state: takesOverState,
                version: current.version + 1,
              )
            : current.copyWith(
                updatedAt: DateTime.utc(2026, 6, 1),
                version: current.version + 1,
              ),
        expectedVersion: current.version,
      );
    }
    return _inner.saveWorkItem(item, expectedVersion: expectedVersion);
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

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

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  /// `WorkflowStore` is an `interface class`, so default bodies are not
  /// inherited by an implementer. Passing `this` keeps the race observable
  /// through the transaction handle the engine writes with.
  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      body(this);
}
