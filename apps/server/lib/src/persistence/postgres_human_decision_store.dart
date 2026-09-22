import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:workflow_store/workflow_store.dart';

/// Adapts the authoritative [WorkflowStore] to the narrow
/// [HumanDecisionStore] port required by [ProductRegistryEngine].
///
/// This reuses the single durable `human_decision` table (owned by
/// `workflow_store` / `apps/server`) rather than inventing a second
/// authorization store.
class PostgresHumanDecisionStore implements HumanDecisionStore {
  PostgresHumanDecisionStore(this._workflowStore);

  final WorkflowStore _workflowStore;

  @override
  Future<void> saveHumanDecision(HumanDecision decision) async =>
      _workflowStore.saveHumanDecision(decision);

  @override
  Future<HumanDecision?> readHumanDecision(String decisionId) async {
    try {
      return await _workflowStore.readHumanDecision(decisionId);
    } on HumanDecisionNotFoundException {
      return null;
    }
  }

  @override
  Future<List<HumanDecision>> readHumanDecisionsForScope(
    String scopeId,
  ) async => _workflowStore.readHumanDecisionsForWorkItem(scopeId);
}
