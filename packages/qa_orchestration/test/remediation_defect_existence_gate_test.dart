import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _r1Config = {
  'idSource': 'workItemDefectReference',
  'sourceColumn': 'defect.defectId',
  'requireResolvable': true,
};

class _FakeDefectReader implements DefectRowReader {
  _FakeDefectReader(this.defects);

  final Map<String, Defect> defects;
  final List<String> calls = [];

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('test/_FakeDefectReader');

  @override
  Future<Defect?> readDefect(String defectId) async {
    calls.add(defectId);
    return defects[defectId];
  }
}

void main() {
  group('RemediationDefectExistenceGate (R1)', () {
    late RemediationDefectExistenceGate gate;

    RemediationDefectExistenceGate gateWith(Map<String, Defect> defects) {
      return RemediationDefectExistenceGate(
        defectReader: _FakeDefectReader(defects),
      );
    }

    Future<QAGateResult> evaluate(
      RemediationDefectExistenceGate candidate, {
      String workItemId = 'design-remediation-DEF-1',
      Map<String, dynamic> config = _r1Config,
    }) {
      return candidate.evaluate(
        workItemId,
        agentResultFor(workItemId: workItemId),
        gateFor(
          gateId: 'qa-r1',
          type: 'triage-defect-existence',
          config: config,
        ),
      );
    }

    setUp(() {
      gate = gateWith({'DEF-1': defectRow(defectId: 'DEF-1')});
    });

    test('passes when the referenced defect row resolves', () async {
      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(result.passedAt, isNotNull);
      expect(result.metadata!['referencedDefectId'], 'DEF-1');
    });

    test('fails when the referenced defect row is missing', () async {
      final g = gateWith({});
      final result = await evaluate(
        g,
        workItemId: 'design-remediation-DEF-1791686085546076',
      );

      expect(result.status, QAGateStatus.failed);
      expect(
        result.metadata!['reason'],
        contains('triage.processed.defect_missing'),
      );
      expect(result.metadata!['referencedDefectId'], 'DEF-1791686085546076');
    });

    test('fails without reading when the work item names no defect', () async {
      final reader = _FakeDefectReader({'DEF-1': defectRow(defectId: 'DEF-1')});
      final g = RemediationDefectExistenceGate(defectReader: reader);
      final result = await evaluate(g, workItemId: 'work-1');

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['referencedDefectId'], isNull);
      expect(reader.calls, isEmpty);
    });

    test('fails without reading when only the prefix is present', () async {
      final reader = _FakeDefectReader({'DEF-1': defectRow(defectId: 'DEF-1')});
      final g = RemediationDefectExistenceGate(defectReader: reader);
      final result = await evaluate(g, workItemId: 'design-remediation-');

      expect(result.status, QAGateStatus.failed);
      expect(reader.calls, isEmpty);
    });

    test(
      'treats sourceColumn as a label: it never reaches the reader',
      () async {
        const hostile = 'defect.defectId); DROP TABLE defects; --';
        final reader = _FakeDefectReader({
          'DEF-1': defectRow(defectId: 'DEF-1'),
        });
        final g = RemediationDefectExistenceGate(defectReader: reader);

        final result = await evaluate(
          g,
          config: {..._r1Config, 'sourceColumn': hostile},
        );

        expect(result.status, QAGateStatus.passed);
        expect(reader.calls, ['DEF-1']);
        expect(result.evidence.single.artifactRef, hostile);
        expect(result.evidence.single.content['sourceColumn'], hostile);
      },
    );

    test('fails when the reader returns a different defect row', () async {
      final g = gateWith({'DEF-1': defectRow(defectId: 'DEF-2')});
      final result = await evaluate(g);

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('not the row'));
    });

    test('is non-vacuous: removing the row flips pass to fail', () async {
      final withRow = await evaluate(
        gateWith({'DEF-1': defectRow(defectId: 'DEF-1')}),
      );
      expect(withRow.status, QAGateStatus.passed);

      final withoutRow = await evaluate(gateWith({}));
      expect(withoutRow.status, QAGateStatus.failed);
    });

    group('rejects malformed declarations with FormatException', () {
      test('unsupported idSource', () async {
        await expectLater(
          evaluate(gate, config: {..._r1Config, 'idSource': 'defectRowColumn'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('requireResolvable false', () async {
        await expectLater(
          evaluate(gate, config: {..._r1Config, 'requireResolvable': false}),
          throwsA(isA<FormatException>()),
        );
      });

      test('non-string sourceColumn', () async {
        await expectLater(
          evaluate(gate, config: {..._r1Config, 'sourceColumn': 42}),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
