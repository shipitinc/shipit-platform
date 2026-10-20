import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _r3Config = {
  'sourceColumn': 'agent_result.structuredResultJson',
  'requiredFields': [
    'classification',
    'status',
    'confidence',
    'suspectedCategory',
  ],
  'classificationEnum': 'DefectClassification',
  'statusEnum': 'DefectStatus',
};

void main() {
  group('TriageClassificationAdmittedGate (R3)', () {
    test('fails when required fields missing', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(structuredResult: {}),
        gateFor(
          gateId: 'triage-classification-admitted',
          type: 'triage-classification-structure',
          config: _r3Config,
        ),
      );
      expect(result.status, QAGateStatus.failed);
    });

    test('fails when field is null', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: {
            'classification': null,
            'status': 'open',
            'confidence': 0.5,
            'suspectedCategory': 'ui',
          },
        ),
        gateFor(
          gateId: 'triage-classification-admitted',
          type: 'triage-classification-structure',
          config: _r3Config,
        ),
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('classification'));
    });

    test('fails when classification is outside DefectClassification', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: {
            'classification': 'not_a_class',
            'status': 'open',
            'confidence': 0.5,
            'suspectedCategory': 'ui',
          },
        ),
        gateFor(
          gateId: 'triage-classification-admitted',
          type: 'triage-classification-structure',
          config: _r3Config,
        ),
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('DefectClassification'));
    });

    test('passes on well-formed but vacuously true classification', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: {
            'classification': 'implementation_defect',
            'status': 'open',
            'confidence': 0.0,
            'suspectedCategory': 'unknown',
          },
        ),
        gateFor(
          gateId: 'triage-classification-admitted',
          type: 'triage-classification-structure',
          config: _r3Config,
        ),
      );
      expect(result.status, QAGateStatus.passed);
    });
  });
}
