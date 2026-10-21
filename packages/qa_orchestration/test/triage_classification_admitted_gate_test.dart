import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

/// The gate is exercised against **the declared gate itself**
/// (`structuredClassificationAdmitted` from `lane_g_triage_qa_contract.dart`),
/// not a duplicated copy of its config map — a copy is the F-197 drift pattern,
/// where the declaration and the test's mirror of it can disagree silently.
Map<String, dynamic> _r3Config() =>
    Map<String, dynamic>.of(structuredClassificationAdmitted.config);

QAGateDefinition _gateWithConfig(Map<String, dynamic> config) =>
    QAGateDefinition(
      gateId: structuredClassificationAdmitted.gateId,
      type: structuredClassificationAdmitted.type,
      required: structuredClassificationAdmitted.required,
      evidenceTypes: structuredClassificationAdmitted.evidenceTypes,
      config: config,
    );

/// A structurally complete classification result: every declared
/// required field carries a value of the shape R3 checks.
Map<String, dynamic> _wellFormedClassification({
  Object? classification = 'implementation_defect',
  Object? status = 'reported',
}) => {
  'classification': classification,
  'status': status,
  'confidence': 0.0,
  'suspectedCategory': 'unknown',
};

void main() {
  group('TriageClassificationAdmittedGate (R3)', () {
    test('fails when required fields missing, naming every key', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(structuredResult: {}),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.failed);
      final reason = result.metadata!['reason'] as String;
      for (final field in [
        'classification',
        'status',
        'confidence',
        'suspectedCategory',
      ]) {
        expect(reason, contains(field));
      }
    });

    test('fails when field is null', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: _wellFormedClassification(classification: null),
        ),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('classification'));
    });

    test('fails when classification is outside DefectClassification', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: _wellFormedClassification(
            classification: 'not_a_class',
          ),
        ),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('DefectClassification'));
    });

    test(
      'F7 falsifier: a non-string classification fails closed and the reason '
      'names the key',
      () async {
        final gate = TriageClassificationAdmittedGate();
        final result = await gate.evaluate(
          'work-1',
          agentResultFor().copyWith(
            structuredResult: _wellFormedClassification(classification: 42),
          ),
          structuredClassificationAdmitted,
        );
        expect(result.status, QAGateStatus.failed);
        final reason = result.metadata!['reason'] as String;
        expect(reason, contains('classification'));
        expect(reason, contains('42'));
      },
    );

    test('fails when status is outside DefectStatus, naming the key', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(structuredResult: _wellFormedStatus('open')),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.failed);
      final reason = result.metadata!['reason'] as String;
      expect(reason, contains('status'));
      expect(reason, contains('DefectStatus'));
    });

    test('fails when status is a non-string', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(structuredResult: _wellFormedStatus(7)),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('status'));
    });

    test('passes on well-formed but vacuously true classification', () async {
      final gate = TriageClassificationAdmittedGate();
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: _wellFormedClassification(),
        ),
        structuredClassificationAdmitted,
      );
      expect(result.status, QAGateStatus.passed);
      expect(result.gateId, 'triage-classification-admitted');
    });

    group('rejects malformed declarations with FormatException', () {
      test('classificationEnum absent', () async {
        final config = _r3Config()..remove('classificationEnum');
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('classificationEnum')),
        );
      });

      test('statusEnum absent', () async {
        final config = _r3Config()..remove('statusEnum');
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('statusEnum')),
        );
      });

      test('requiredFields absent', () async {
        final config = _r3Config()..remove('requiredFields');
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('requiredFields')),
        );
      });

      test('empty requiredFields', () async {
        final config = _r3Config()..['requiredFields'] = <Object>[];
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('requiredFields')),
        );
      });

      test('non-string classificationEnum', () async {
        final config = _r3Config()..['classificationEnum'] = 42;
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('classificationEnum')),
        );
      });

      test('non-string sourceColumn', () async {
        final config = _r3Config()..['sourceColumn'] = 42;
        await expectLater(
          TriageClassificationAdmittedGate().evaluate(
            'work-1',
            agentResultFor(),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('sourceColumn')),
        );
      });
    });
  });
}

Map<String, dynamic> _wellFormedStatus(Object? status) => {
  'classification': 'implementation_defect',
  'status': status,
  'confidence': 0.0,
  'suspectedCategory': 'unknown',
};

Matcher _formatExceptionNaming(String key) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  allOf(contains('triage-classification-admitted'), contains(key)),
);
