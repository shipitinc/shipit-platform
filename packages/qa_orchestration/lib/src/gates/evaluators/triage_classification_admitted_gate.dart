import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// Gate R3: triage-classification-admitted (type: triage-classification-structure)
/// Gate ID must be 'triage-classification-admitted'
class TriageClassificationAdmittedGate implements GateEvaluator {
  TriageClassificationAdmittedGate();

  @override
  String get gateType => 'triage-classification-structure';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _TriageClassificationConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final failures = <String>[];
    final structured = agentResult.structuredResult;

    if (structured is Map<String, dynamic>) {
      for (final field in config.requiredFields) {
        if (!structured.containsKey(field)) {
          failures.add('missing required field: $field');
        } else {
          final value = structured[field];
          if (value == null) {
            failures.add('required field is null: $field');
          }
        }
      }

      // Validate classification enum
      if (structured.containsKey('classification')) {
        final classification = structured['classification'];
        if (classification == null) {
          // already caught above
        } else if (classification is String) {
          try {
            DefectClassification.fromWire(classification);
          } catch (_) {
            failures.add(
              'classification is outside DefectClassification: $classification',
            );
          }
        }
      }
    } else {
      failures.add('structuredResult is not a Map');
    }

    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId, // must remain as declared
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:classification_check:${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'triage_structured_result',
          artifactRef: config.sourceColumn,
          content: <String, dynamic>{
            'sourceColumn': config.sourceColumn,
            'requiredFields': config.requiredFields,
            'classificationEnum': config.classificationEnum,
            'statusEnum': config.statusEnum,
            'hasStructuredResult': structured is Map<String, dynamic>,
            if (structured is Map<String, dynamic>)
              'structuredResult': structured,
            'resolved': passed,
            if (!passed) 'reasons': failures,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{if (!passed) 'reason': failures.join('; ')},
    );
  }
}
