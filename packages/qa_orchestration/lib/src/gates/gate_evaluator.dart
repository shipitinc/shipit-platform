import 'package:platform_contracts/platform_contracts.dart';

import '../evidence/evidence_collector.dart';

abstract class GateEvaluator {
  String get gateType;

  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  );
}

class GateEvaluatorImpl implements GateEvaluator {
  @override
  final String gateType;

  final EvidenceCollector _collector;

  GateEvaluatorImpl(this.gateType, this._collector);

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final evidence = <QAEvidence>[];

    for (final evidenceType in gate.evidenceTypes) {
      final collected = await _collector.collect(
        workItemId,
        gate.gateId,
        evidenceType,
        gate.config,
      );
      evidence.add(collected);
    }

    final passed = _validateEvidence(evidence, gate.config);

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: evidence,
      evaluatedAt: DateTime.now(),
      passedAt: passed ? DateTime.now() : null,
    );
  }

  bool _validateEvidence(
    List<QAEvidence> evidence,
    Map<String, dynamic> config,
  ) {
    return evidence.isNotEmpty;
  }
}
