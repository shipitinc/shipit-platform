import 'package:platform_contracts/platform_contracts.dart';

import 'human_decision_store.dart';

/// Deterministic in-memory [HumanDecisionStore] for unit tests and local
/// development. Mirrors the durable store's contract (last write wins on
/// [saveHumanDecision], scoped read by the owning scope key).
class InMemoryHumanDecisionStore implements HumanDecisionStore {
  final Map<String, HumanDecision> _byId = <String, HumanDecision>{};

  @override
  Future<void> saveHumanDecision(HumanDecision decision) async {
    _byId[decision.decisionId] = decision;
  }

  @override
  Future<HumanDecision?> readHumanDecision(String decisionId) async =>
      _byId[decisionId];

  @override
  Future<List<HumanDecision>> readHumanDecisionsForScope(
    String scopeId,
  ) async =>
      _byId.values.where((d) => d.workItemId == scopeId).toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  /// Test-only durable snapshot (survives a simulated process restart).
  Map<String, Map<String, dynamic>> snapshot() => {
    for (final entry in _byId.entries) entry.key: entry.value.toJson(),
  };

  /// Test-only restore from a [snapshot].
  void restore(Map<String, Map<String, dynamic>> snapshot) {
    _byId
      ..clear()
      ..addAll({
        for (final entry in snapshot.entries)
          entry.key: HumanDecision.fromJson(entry.value),
      });
  }
}
