import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _f5Config = {
  'reviewedRevisionField': 'endingRevision',
  'producedRevisionField': 'producedRevision',
  'requireStringEquality': true,
  'nullRevisionIsFailure': true,
};

class _FakeRevisionSource implements RevisionIdentitySource {
  _FakeRevisionSource({this.reviewed, this.produced});

  String? reviewed;
  WorkspaceHead? produced;
  final List<String> calls = [];

  @override
  Future<String?> readReviewedRevision(String workItemId) async {
    calls.add('reviewed:$workItemId');
    return reviewed;
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    calls.add('produced:$workItemId');
    return produced;
  }
}

void main() {
  group('RevisionIdentityMatchGate (F5)', () {
    late _FakeRevisionSource source;
    late RevisionIdentityMatchGate gate;

    RevisionIdentityMatchGate gateWith({
      String? reviewed,
      WorkspaceHead? produced,
    }) {
      source = _FakeRevisionSource(reviewed: reviewed, produced: produced);
      return RevisionIdentityMatchGate(source: source);
    }

    Future<QAGateResult> evaluate(
      RevisionIdentityMatchGate candidate, {
      Map<String, dynamic> config = _f5Config,
      String workItemId = 'work-1',
    }) {
      return candidate.evaluate(
        workItemId,
        agentResultFor(workItemId: workItemId),
        gateFor(
          gateId: 'qa-f5',
          type: 'revision-identity-match',
          config: config,
        ),
      );
    }

    const matching = WorkspaceHead(
      startingRevision: 'def456',
      headRevision: 'abc123',
      headMoved: true,
    );

    setUp(() {
      gate = gateWith(reviewed: 'abc123', produced: matching);
    });

    test('passes when reviewed and re-read revisions are equal', () async {
      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(source.calls, ['reviewed:work-1', 'produced:work-1']);
      expect(
        result.evidence
            .singleWhere((e) => e.evidenceType == 'review_verdict')
            .content['endingRevision'],
        'abc123',
      );
      expect(
        result.evidence
            .singleWhere((e) => e.evidenceType == 'committed_revision')
            .content['producedRevision'],
        'abc123',
      );
    });

    test('fails when the revisions differ', () async {
      final result = await evaluate(
        gateWith(
          reviewed: 'abc123',
          produced: const WorkspaceHead(
            startingRevision: 'def456',
            headRevision: 'def789',
            headMoved: true,
          ),
        ),
      );

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('is not the produced'));
    });

    test('fails when the reviewed revision is null', () async {
      final result = await evaluate(
        gateWith(reviewed: null, produced: matching),
      );

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('nullRevisionIsFailure'));
    });

    test('fails when the reviewed revision is the empty string', () async {
      final result = await evaluate(gateWith(reviewed: '', produced: matching));

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('empty reviewed revision'));
    });

    test('fails when HEAD could not be established', () async {
      final result = await evaluate(
        gateWith(reviewed: 'abc123', produced: null),
      );

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('could not be established'));
    });

    test(
      'fails on a whitespace-only difference, without normalizing',
      () async {
        final result = await evaluate(
          gateWith(
            reviewed: ' abc123',
            produced: const WorkspaceHead(
              startingRevision: null,
              headRevision: 'abc123',
              headMoved: null,
            ),
          ),
        );

        expect(result.status, QAGateStatus.failed);
      },
    );

    test('fails on a case-only difference', () async {
      final result = await evaluate(
        gateWith(
          reviewed: 'ABC123',
          produced: const WorkspaceHead(
            startingRevision: null,
            headRevision: 'abc123',
            headMoved: null,
          ),
        ),
      );

      expect(result.status, QAGateStatus.failed);
    });

    test(
      'passes on a re-run whose headMoved is null when the re-read matches',
      () async {
        // The bug F5 replaces: a re-run that committed and left an untracked
        // file produced a null that had never been established, and
        // nullRevisionIsFailure fired on a correct run. `headMoved` being null
        // is "no baseline to compare", not "the revision is unknown".
        final result = await evaluate(
          gateWith(
            reviewed: 'abc123',
            produced: const WorkspaceHead(
              startingRevision: null,
              headRevision: 'abc123',
              headMoved: null,
            ),
          ),
        );

        expect(result.status, QAGateStatus.passed);
      },
    );

    test('records how the produced revision was established', () async {
      final result = await evaluate(gate);
      final produced = result.evidence.singleWhere(
        (e) => e.evidenceType == 'committed_revision',
      );

      expect(produced.content['established'], isTrue);
      expect(produced.content['startingRevision'], 'def456');
      expect(produced.content['headMoved'], isTrue);
    });

    group('rejects malformed declarations with FormatException', () {
      test('unsupported reviewedRevisionField', () async {
        await expectLater(
          evaluate(
            gate,
            config: {..._f5Config, 'reviewedRevisionField': 'headRevision'},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('unsupported producedRevisionField', () async {
        await expectLater(
          evaluate(
            gate,
            config: {..._f5Config, 'producedRevisionField': 'someRunField'},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('requireStringEquality false', () async {
        await expectLater(
          evaluate(
            gate,
            config: {..._f5Config, 'requireStringEquality': false},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('nullRevisionIsFailure false', () async {
        await expectLater(
          evaluate(
            gate,
            config: {..._f5Config, 'nullRevisionIsFailure': false},
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
