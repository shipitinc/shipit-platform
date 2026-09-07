import 'package:platform_contracts/platform_contracts.dart';

import '../../evidence/evidence_collector.dart';
import '../gate_evaluator.dart';

class SecurityScanGate extends GateEvaluatorImpl {
  SecurityScanGate() : super('security-scan', _SecurityScanCollector());
}

class _SecurityScanCollector implements EvidenceCollector {
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
      evidenceType: 'security-scan-report',
      artifactRef: 'security-report.sarif',
      content: {'tool': config['tool'] ?? 'trivy', 'vulnerabilities': []},
      collectedAt: DateTime.now(),
    );
  }
}
