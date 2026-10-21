import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

/// The gate is exercised against **the declared gate itself**
/// (`evidenceGrounded` from `lane_g_triage_qa_contract.dart`), not a
/// duplicated copy of its config map — a copy is the F-197 drift pattern,
/// where the declaration and the test's mirror of it can disagree silently.
Map<String, dynamic> _r2Config() =>
    Map<String, dynamic>.of(evidenceGrounded.config);

QAGateDefinition _gateWithConfig(Map<String, dynamic> config) =>
    QAGateDefinition(
      gateId: evidenceGrounded.gateId,
      type: evidenceGrounded.type,
      required: evidenceGrounded.required,
      evidenceTypes: evidenceGrounded.evidenceTypes,
      config: config,
    );

/// A reader that honors the contract: it returns only the rows that actually
/// belong to the requested defect.
class _FakeEvidenceReader implements DefectEvidenceReader {
  _FakeEvidenceReader(this.rows);

  final List<DefectEvidence> rows;
  final List<String> calls = [];

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async {
    calls.add(defectId);
    return rows.where((r) => r.defectId == defectId).toList();
  }
}

/// A reader that **ignores its defect argument** and returns every row it
/// holds — reviewer falsifier F1's misbehaving reader. If row identity is the
/// reader's courtesy rather than the gate's own check, this reader hands the
/// gate another defect's row and the gate passes.
class _UnfilteredEvidenceReader implements DefectEvidenceReader {
  _UnfilteredEvidenceReader(this.rows);

  final List<DefectEvidence> rows;

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async =>
      rows;
}

DefectEvidence evidence({
  required String evidenceId,
  required String defectId,
}) {
  return DefectEvidence(
    evidenceId: evidenceId,
    defectId: defectId,
    kind: EvidenceIntakeKind.textDescription,
    capturedAt: DateTime.utc(2026, 10, 20),
    createdAt: DateTime.utc(2026, 10, 20),
  );
}

Future<QAGateResult> evaluateGate(TriageEvidenceGroundingGate gate) {
  return gate.evaluate(
    'work-1',
    agentResultFor().copyWith(
      structuredResult: {
        'defectId': 'DEF-1',
        'evidenceUsed': ['E-7'],
      },
    ),
    evidenceGrounded,
  );
}

Matcher _formatExceptionNaming(String key) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  allOf(contains('triage-evidence-grounded'), contains(key)),
);

void main() {
  group('TriageEvidenceGroundingGate (R2)', () {
    test(
      'fails when classification cites evidence that does not exist',
      () async {
        final reader = _FakeEvidenceReader([
          evidence(evidenceId: 'E-7', defectId: 'DEF-1'),
        ]);
        final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
        final result = await gate.evaluate(
          'work-1',
          agentResultFor().copyWith(
            structuredResult: {
              'defectId': 'DEF-1',
              'evidenceUsed': ['E-99'],
            },
          ),
          evidenceGrounded,
        );
        expect(result.status, QAGateStatus.failed);
        expect(result.metadata!['reason'], contains('E-99'));
      },
    );

    test('fails when evidence belongs to different defect', () async {
      final reader = _FakeEvidenceReader([
        evidence(evidenceId: 'E-7', defectId: 'DEF-2'), // different defect
      ]);
      final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: {
            'defectId': 'DEF-1',
            'evidenceUsed': ['E-7'],
          },
        ),
        evidenceGrounded,
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('does not exist for defect'));
    });

    test(
      'F1 falsifier: a reader that ignores its defect argument cannot smuggle '
      'another defect\'s row past the gate',
      () async {
        // DEF-2's row E-7, returned for a request about DEF-1, cited for
        // DEF-1. The gate must re-check `row.defectId == defectId` itself; if
        // it only trusts the reader's filtering, this passes.
        final reader = _UnfilteredEvidenceReader([
          evidence(evidenceId: 'E-7', defectId: 'DEF-2'),
        ]);
        final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
        final result = await gate.evaluate(
          'work-1',
          agentResultFor().copyWith(
            structuredResult: {
              'defectId': 'DEF-1',
              'evidenceUsed': ['E-7'],
            },
          ),
          evidenceGrounded,
        );
        expect(result.status, QAGateStatus.failed);
        final reason = result.metadata!['reason'] as String;
        expect(reason, contains('belongs to defect'));
        expect(reason, contains('DEF-2'));
        expect(reason, contains('DEF-1'));
      },
    );

    test('fails when classification cites nothing at all', () async {
      final reader = _FakeEvidenceReader([
        evidence(evidenceId: 'E-7', defectId: 'DEF-1'),
      ]);
      final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
      final result = await gate.evaluate(
        'work-1',
        agentResultFor().copyWith(
          structuredResult: {'defectId': 'DEF-1', 'evidenceUsed': []},
        ),
        evidenceGrounded,
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('empty evidenceUsed'));
    });

    test('passes when evidence exists and belongs to same defect', () async {
      final reader = _FakeEvidenceReader([
        evidence(evidenceId: 'E-7', defectId: 'DEF-1'),
      ]);
      final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
      final result = await evaluateGate(gate);
      expect(result.status, QAGateStatus.passed);
      expect(result.gateId, 'triage-evidence-grounded');
    });

    group('rejects malformed declarations with FormatException', () {
      test('everyCitedEvidenceMustExist absent', () async {
        final config = _r2Config()..remove('everyCitedEvidenceMustExist');
        await expectLater(
          TriageEvidenceGroundingGate(
            defectEvidenceReader: _FakeEvidenceReader([]),
          ).evaluate(
            'work-1',
            agentResultFor().copyWith(
              structuredResult: {
                'defectId': 'DEF-1',
                'evidenceUsed': ['E-7'],
              },
            ),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('everyCitedEvidenceMustExist')),
        );
      });

      test('everyCitedEvidenceMustExist false', () async {
        final config = _r2Config()..['everyCitedEvidenceMustExist'] = false;
        await expectLater(
          TriageEvidenceGroundingGate(
            defectEvidenceReader: _FakeEvidenceReader([]),
          ).evaluate(
            'work-1',
            agentResultFor().copyWith(
              structuredResult: {
                'defectId': 'DEF-1',
                'evidenceUsed': ['E-7'],
              },
            ),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('everyCitedEvidenceMustExist')),
        );
      });

      test('mustBelongToReportedDefect absent', () async {
        final config = _r2Config()..remove('mustBelongToReportedDefect');
        await expectLater(
          TriageEvidenceGroundingGate(
            defectEvidenceReader: _FakeEvidenceReader([]),
          ).evaluate(
            'work-1',
            agentResultFor().copyWith(
              structuredResult: {
                'defectId': 'DEF-1',
                'evidenceUsed': ['E-7'],
              },
            ),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('mustBelongToReportedDefect')),
        );
      });

      test('mustBelongToReportedDefect false', () async {
        final config = _r2Config()..['mustBelongToReportedDefect'] = false;
        await expectLater(
          TriageEvidenceGroundingGate(
            defectEvidenceReader: _FakeEvidenceReader([]),
          ).evaluate(
            'work-1',
            agentResultFor().copyWith(
              structuredResult: {
                'defectId': 'DEF-1',
                'evidenceUsed': ['E-7'],
              },
            ),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('mustBelongToReportedDefect')),
        );
      });

      test('non-string sourceColumn', () async {
        final config = _r2Config()..['sourceColumn'] = 42;
        await expectLater(
          TriageEvidenceGroundingGate(
            defectEvidenceReader: _FakeEvidenceReader([]),
          ).evaluate(
            'work-1',
            agentResultFor().copyWith(
              structuredResult: {
                'defectId': 'DEF-1',
                'evidenceUsed': ['E-7'],
              },
            ),
            _gateWithConfig(config),
          ),
          throwsA(_formatExceptionNaming('sourceColumn')),
        );
      });
    });
  });
}
