import 'package:platform_contracts/platform_contracts.dart';

import 'gates/gate_registry.dart';

class QAOrchestration {
  QAOrchestration({GateRegistry? registry})
    : _registry = registry ?? gateRegistry;

  final GateRegistry _registry;

  Future<List<QAGateResult>> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAContract contract,
  ) async {
    final results = <QAGateResult>[];

    for (final gate in contract.gates) {
      final evaluator = _registry.get(gate.type);
      if (evaluator == null) {
        results.add(
          QAGateResult(
            gateId: gate.gateId,
            workItemId: workItemId,
            status: QAGateStatus.skipped,
            evidence: [],
            evaluatedAt: DateTime.now(),
            metadata: {'error': 'No evaluator for gate type: ${gate.type}'},
          ),
        );
        continue;
      }

      final result = await evaluator.evaluate(workItemId, agentResult, gate);
      results.add(result);
    }

    return results;
  }

  bool isOverallPass(List<QAGateResult> results, QAContract contract) {
    final passCriteria = contract.passCriteria ?? const QAPassCriteria();

    if (passCriteria.allRequiredGatesMustPass) {
      final requiredGates = contract.gates
          .where((g) => g.required)
          .map((g) => g.gateId)
          .toSet();
      final requiredResults = results.where(
        (r) => requiredGates.contains(r.gateId),
      );

      for (final result in requiredResults) {
        if (result.status != QAGateStatus.passed &&
            result.status != QAGateStatus.waived) {
          return false;
        }
      }
    }

    if (passCriteria.optionalGateFailuresAllowed > 0) {
      final optionalGates = contract.gates
          .where((g) => !g.required)
          .map((g) => g.gateId)
          .toSet();
      final optionalResults = results.where(
        (r) => optionalGates.contains(r.gateId),
      );
      final failures = optionalResults
          .where((r) => r.status == QAGateStatus.failed)
          .length;

      if (failures > passCriteria.optionalGateFailuresAllowed) {
        return false;
      }
    }

    return true;
  }
}
