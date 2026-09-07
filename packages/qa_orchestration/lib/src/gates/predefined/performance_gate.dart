import 'package:platform_contracts/platform_contracts.dart';

import '../../evidence/evidence_collector.dart';
import '../gate_evaluator.dart';

class PerformanceGate extends GateEvaluatorImpl {
  PerformanceGate() : super('performance', _PerformanceCollector());
}

class _PerformanceCollector implements EvidenceCollector {
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
      evidenceType: 'performance-metrics',
      artifactRef: 'performance.json',
      content: {
        'benchmarks': config['benchmarks'] ?? [],
        'thresholds': config['thresholds'] ?? {},
      },
      collectedAt: DateTime.now(),
    );
  }
}
