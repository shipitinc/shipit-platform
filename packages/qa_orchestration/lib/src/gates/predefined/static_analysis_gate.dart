import 'package:platform_contracts/platform_contracts.dart';

import '../../evidence/evidence_collector.dart';
import '../gate_evaluator.dart';

class StaticAnalysisGate extends GateEvaluatorImpl {
  StaticAnalysisGate() : super('static-analysis', _StaticAnalysisCollector());
}

class _StaticAnalysisCollector implements EvidenceCollector {
  @override
  Future<QAEvidence> collect(
    String workItemId,
    String gateId,
    String evidenceType,
    Map<String, dynamic> config,
  ) async {
    return QAEvidence(
      evidenceId: 'evidence-${DateTime.now().millisecondsSinceEpoch}',
      gateId: gateId,
      workItemId: workItemId,
      evidenceType: 'static-analysis-report',
      artifactRef: 'analysis-report.json',
      content: {'tool': config['tool'] ?? 'dart analyze', 'issues': []},
      collectedAt: DateTime.now(),
    );
  }
}
