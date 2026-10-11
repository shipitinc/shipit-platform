import 'package:platform_contracts/platform_contracts.dart' show HumanDecision;
import 'package:scheduler/scheduler.dart' show HumanDecisionStore;
import 'package:workflow_store/workflow_store.dart';

/// Adapts a [WorkflowStore] to the [HumanDecisionStore] seam the provider
/// health monitor writes through.
///
/// The production composition supplies `PostgresHumanDecisionStore`, which
/// declares both interfaces explicitly. `WorkflowStore` carries
/// `saveHumanDecision` but does not declare the narrower interface itself, so
/// the adapter is spelled out here exactly as the production wiring spells it
/// rather than leaning on a structural match.
class WorkflowStoreHumanDecisionStore implements HumanDecisionStore {
  const WorkflowStoreHumanDecisionStore(this._store);

  final WorkflowStore _store;

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _store.saveHumanDecision(decision);
}
