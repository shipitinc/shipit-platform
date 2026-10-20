import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _r2Config = {
  'sourceColumn': 'defect_evidence.evidenceId',
  'everyCitedEvidenceMustExist': true,
  'mustBelongToReportedDefect': true,
};

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
          gateFor(
            gateId: 'triage-evidence-grounded',
            type: 'triage-evidence-grounding',
            config: _r2Config,
          ),
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
        gateFor(
          gateId: 'triage-evidence-grounded',
          type: 'triage-evidence-grounding',
          config: _r2Config,
        ),
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('does not exist for defect'));
    });

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
        gateFor(
          gateId: 'triage-evidence-grounded',
          type: 'triage-evidence-grounding',
          config: _r2Config,
        ),
      );
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('empty evidenceUsed'));
    });

    test('passes when evidence exists and belongs to same defect', () async {
      final reader = _FakeEvidenceReader([
        evidence(evidenceId: 'E-7', defectId: 'DEF-1'),
      ]);
      final gate = TriageEvidenceGroundingGate(defectEvidenceReader: reader);
      final result = await evaluateGate(gate, reader);
      expect(result.status, QAGateStatus.passed);
    });
  });
}

Future<QAGateResult> evaluateGate(
  TriageEvidenceGroundingGate gate,
  _FakeEvidenceReader reader,
) async {
  return gate.evaluate(
    'work-1',
    agentResultFor().copyWith(
      structuredResult: {
        'defectId': 'DEF-1',
        'evidenceUsed': ['E-7'],
      },
    ),
    gateFor(
      gateId: 'triage-evidence-grounded',
      type: 'triage-evidence-grounding',
      config: _r2Config,
    ),
  );
}
