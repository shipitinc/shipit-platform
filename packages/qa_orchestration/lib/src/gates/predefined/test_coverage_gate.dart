import 'package:platform_contracts/platform_contracts.dart';

import '../../evidence/evidence_collector.dart';
import '../gate_evaluator.dart';

class TestCoverageGate extends GateEvaluatorImpl {
  TestCoverageGate() : super('unit-tests', _TestCoverageCollector());
}

class _TestCoverageCollector implements EvidenceCollector {
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
      evidenceType: 'coverage-report',
      artifactRef: 'coverage/lcov.info',
      content: {'format': 'lcov', 'threshold': config['threshold'] ?? 0.8},
      collectedAt: DateTime.now(),
    );
  }
}
