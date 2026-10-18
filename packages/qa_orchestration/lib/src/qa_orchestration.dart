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
            status: QAGateStatus.notExecuted,
            evidence: [],
            evaluatedAt: DateTime.now(),
            metadata: {'reason': 'No evaluator for gate type: ${gate.type}'},
          ),
        );
        continue;
      }

      final result = await evaluator.evaluate(workItemId, agentResult, gate);
      results.add(result);
    }

    return results;
  }

  /// Whether the gate is satisfied for pass purposes.
  ///
  /// Mirrors AEF QA_GOVERNANCE.md gate_results semantics: passed, waived
  /// (SKIPPED with an authority_ref / Human Decision), and N/A are satisfied.
  /// A [QAGateStatus.skipped] gate is only satisfied when an authority
  /// reference is recorded; a required gate left [QAGateStatus.notExecuted]
  /// is not silently passed and must be routed to the determination lane.
  bool isGateSatisfied(QAGateResult result) {
    switch (result.status) {
      case QAGateStatus.passed:
      case QAGateStatus.waived:
      case QAGateStatus.notApplicable:
        return true;
      case QAGateStatus.skipped:
        return _hasSkippedAuthority(result);
      case QAGateStatus.pending:
      case QAGateStatus.running:
      case QAGateStatus.failed:
      case QAGateStatus.notExecuted:
        return false;
    }
  }

  /// Required gates that block overall pass and must be formally determined
  /// (made runnable, declared SKIPPED with reasons + authority_ref, or
  /// revised) rather than being left latent as REQUIRED + NOT_EXECUTED.
  List<String> requiresFormalDetermination(
    List<QAGateResult> results,
    QAContract contract,
  ) {
    final requiredGates = contract.gates
        .where((g) => g.required)
        .map((g) => g.gateId)
        .toSet();

    return [
      for (final result in results)
        if (requiredGates.contains(result.gateId) && !isGateSatisfied(result))
          result.gateId,
    ];
  }

  /// Whether [results] constitute an overall pass under [contract].
  ///
  /// The required-gate branch iterates the **contract's** required gates and
  /// looks each one up in [results], not the other way round. The invariant is
  /// one line, and it is the same one
  /// `_AllRequiredGatesPassedGuard` in `workflow_engine`'s
  /// `guard_conditions.dart` holds: *a required gate with no result is
  /// `notExecuted`, not absent.*
  ///
  /// Filtering [results] down to the required gate ids asks "of the results I
  /// was handed, are the required ones satisfied?" and cannot express that
  /// invariant: a contract declaring three required gates, handed only the one
  /// result that passed, filtered to a single element, and returned `true` —
  /// with two required gates never evaluated at all.
  ///
  /// §7.4 requires this and the guard to agree *by construction rather than by
  /// parallel maintenance*, so the duplicate rule matches the guard's too:
  /// every result carrying a required gate id must satisfy it, so a second
  /// result cannot mask a failing one.
  bool isOverallPass(List<QAGateResult> results, QAContract contract) {
    final passCriteria = contract.passCriteria ?? const QAPassCriteria();

    if (passCriteria.allRequiredGatesMustPass) {
      for (final gate in contract.gates.where((g) => g.required)) {
        final resultsForGate = results.where((r) => r.gateId == gate.gateId);

        // A required gate the contract declares and no result covers was never
        // evaluated. That is `not_executed`, which is not satisfied — so this
        // fails closed rather than passing on a gate nobody ran.
        if (resultsForGate.isEmpty) {
          return false;
        }

        if (!resultsForGate.every(isGateSatisfied)) {
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

  bool _hasSkippedAuthority(QAGateResult result) {
    if (result.waiver != null) {
      return true;
    }
    return result.evidenceDeterminations?.any(
          (d) =>
              d.determination == EvidenceDetermination.skipped &&
              d.authorityRef != null,
        ) ??
        false;
  }
}
