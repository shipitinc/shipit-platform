import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _declaredCheckNames = ['dart_format', 'dart_analyze', 'dart_test'];

const _declaredCommands = {
  'dart_format': 'dart format --output=none --set-exit-if-changed .',
  'dart_analyze': 'dart analyze',
  'dart_test': 'dart test',
};

Map<String, dynamic> _f4Config({
  List<String> checkNames = _declaredCheckNames,
  Map<String, String> commands = _declaredCommands,
}) {
  return {
    'requireCheckNames': checkNames,
    'requireCommands': commands,
    'requireStatus': 'passed',
    'commandMatchIsExact': true,
  };
}

class _FakeVerificationReader implements PlatformVerificationReader {
  _FakeVerificationReader(this.rows);

  final List<PlatformVerification> rows;
  final List<String> calls = [];

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('test/_FakeVerificationReader');

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    calls.add(executionId);
    return rows;
  }
}

List<PlatformVerification> _allPassingRows() {
  return _declaredCheckNames
      .map(
        (name) =>
            verificationRow(checkName: name, command: _declaredCommands[name]!),
      )
      .toList(growable: false);
}

void main() {
  group('DeclaredValidationOutcomeGate (F4)', () {
    late _FakeVerificationReader reader;
    late DeclaredValidationOutcomeGate gate;

    DeclaredValidationOutcomeGate gateWith(List<PlatformVerification> rows) {
      reader = _FakeVerificationReader(rows);
      return DeclaredValidationOutcomeGate(verificationReader: reader);
    }

    Future<QAGateResult> evaluate(
      DeclaredValidationOutcomeGate candidate, {
      Map<String, dynamic>? config,
      String? executionId = 'exec-1',
    }) {
      return candidate.evaluate(
        'work-1',
        agentResultFor(executionId: executionId),
        gateFor(
          gateId: 'qa-f4',
          type: 'declared-validation-outcome',
          config: config ?? _f4Config(),
        ),
      );
    }

    setUp(() {
      gate = gateWith(_allPassingRows());
    });

    test('passes when every declared check ran its declared command', () async {
      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(result.passedAt, isNotNull);
      expect(result.evidence, hasLength(_declaredCheckNames.length));
      expect(reader.calls, ['exec-1']);
      for (final evidence in result.evidence) {
        expect(evidence.content['matched'], isTrue);
      }
    });

    test(
      'fails when the row carrying the check name ran the liveness probe',
      () async {
        // The live shape: the triage plan attaches `git rev-parse` to every
        // role, so a `dart_test`-named row can carry the probe's command.
        final rows = [
          for (final row in _allPassingRows())
            if (row.checkName == 'dart_test')
              verificationRow(
                checkName: 'dart_test',
                command: "git rev-parse --verify 'HEAD^{commit}'",
              )
            else
              row,
        ];
        final result = await evaluate(gateWith(rows));

        expect(result.status, QAGateStatus.failed);
        expect(result.metadata!['reason'], contains('dart_test'));
        expect(result.metadata!['reason'], contains('matches exactly'));
      },
    );

    test('does not accept a superstring of the declared command', () async {
      final rows = [
        for (final row in _allPassingRows())
          if (row.checkName == 'dart_test')
            verificationRow(
              checkName: 'dart_test',
              command: 'dart test --reporter=json',
            )
          else
            row,
      ];
      final result = await evaluate(gateWith(rows));

      expect(result.status, QAGateStatus.failed);
      expect(
        result.evidence
            .singleWhere((e) => e.content['checkName'] == 'dart_test')
            .content['matched'],
        isFalse,
      );
    });

    test('does not accept a substring of the declared command', () async {
      final rows = [
        for (final row in _allPassingRows())
          if (row.checkName == 'dart_test')
            verificationRow(checkName: 'dart_test', command: 'dart tes')
          else
            row,
      ];
      final result = await evaluate(gateWith(rows));

      expect(result.status, QAGateStatus.failed);
    });

    test('fails when a declared check has no row at all', () async {
      final rows = _allPassingRows()
          .where((row) => row.checkName != 'dart_analyze')
          .toList(growable: false);
      final result = await evaluate(gateWith(rows));

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('"dart_analyze" has no'));
    });

    test('fails when a declared check reports failed', () async {
      final rows = [
        for (final row in _allPassingRows())
          if (row.checkName == 'dart_format')
            verificationRow(
              checkName: 'dart_format',
              command: _declaredCommands['dart_format']!,
              status: AgentClaimStatus.failed,
            )
          else
            row,
      ];
      final result = await evaluate(gateWith(rows));

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('reporting failed'));
    });

    test(
      'fails when a failed sibling row exists for a declared check',
      () async {
        final rows = [
          ..._allPassingRows(),
          verificationRow(
            checkName: 'dart_test',
            command: 'dart test --retry',
            status: AgentClaimStatus.failed,
          ),
        ];
        final result = await evaluate(gateWith(rows));

        expect(result.status, QAGateStatus.failed);
        expect(result.metadata!['reason'], contains('reporting failed'));
      },
    );

    test('fails when the row is agent-claimed evidence', () async {
      final rows = [
        for (final row in _allPassingRows())
          if (row.checkName == 'dart_test')
            verificationRow(
              checkName: 'dart_test',
              command: _declaredCommands['dart_test']!,
              evidenceKind: EvidenceKind.agentClaimedEvidence,
            )
          else
            row,
      ];
      final result = await evaluate(gateWith(rows));

      expect(result.status, QAGateStatus.failed);
      expect(result.metadata!['reason'], contains('platform-verified'));
    });

    test(
      'fails without reading when the agent result has no executionId',
      () async {
        final result = await evaluate(gate, executionId: null);

        expect(result.status, QAGateStatus.failed);
        expect(result.metadata!['reason'], contains('no executionId'));
        expect(reader.calls, isEmpty);
      },
    );

    test('reads the declared set from config, not a hardcoded one', () async {
      const config = {
        'requireCheckNames': ['totally_custom_check'],
        'requireCommands': {'totally_custom_check': 'my check --flag'},
        'requireStatus': 'passed',
        'commandMatchIsExact': true,
      };
      final result = await evaluate(
        gateWith([
          verificationRow(
            checkName: 'totally_custom_check',
            command: 'my check --flag',
          ),
        ]),
        config: config,
      );

      expect(result.status, QAGateStatus.passed);
      expect(
        result.evidence.single.content['checkName'],
        'totally_custom_check',
      );
    });

    test('is non-vacuous: one changed character flips the verdict', () async {
      final rows = _allPassingRows();
      final original = await evaluate(gateWith(rows));
      expect(original.status, QAGateStatus.passed);

      final mutated = await evaluate(
        gateWith(rows),
        config: _f4Config(
          commands: {..._declaredCommands, 'dart_test': 'dart tesT'},
        ),
      );
      expect(mutated.status, QAGateStatus.failed);
    });

    group('rejects malformed declarations with FormatException', () {
      test('empty requireCheckNames', () async {
        await expectLater(
          evaluate(gate, config: _f4Config(checkNames: [])),
          throwsA(isA<FormatException>()),
        );
      });

      test('duplicate check names', () async {
        await expectLater(
          evaluate(
            gate,
            config: _f4Config(checkNames: ['dart_test', 'dart_test']),
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('a declared check with no declared command', () async {
        await expectLater(
          evaluate(
            gate,
            config: _f4Config(checkNames: ['dart_test', 'undeclared']),
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('requireStatus other than passed', () async {
        await expectLater(
          evaluate(gate, config: {..._f4Config(), 'requireStatus': 'failed'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('commandMatchIsExact false', () async {
        await expectLater(
          evaluate(
            gate,
            config: {..._f4Config(), 'commandMatchIsExact': false},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('commandMatchIsExact absent', () async {
        final config = _f4Config()..remove('commandMatchIsExact');
        await expectLater(
          evaluate(gate, config: config),
          throwsA(isA<FormatException>()),
        );
      });

      test('non-string check name', () async {
        await expectLater(
          evaluate(
            gate,
            config: _f4Config(
              checkNames: ['dart_test'],
              commands: {'dart_test': 'dart test'},
            )..['requireCheckNames'] = <Object>[42],
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
