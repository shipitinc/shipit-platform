import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _f1Config = {
  'evidenceTypes': ['execution_delta', 'committed_revision'],
  'requireReadableDelta': true,
  'requireHeadMoved': true,
  'recordProducedRevision': true,
};

const _start = 'aaa111start';
const _produced = 'bbb222produced';

class _FakeProvenanceSource implements ArtifactProvenanceSource {
  _FakeProvenanceSource({required this.delta, this.reReadHeadResult});

  ExecutionDelta delta;
  WorkspaceHead? reReadHeadResult;
  final List<String> calls = [];

  @override
  Future<ExecutionDelta> readDelta(String workItemId) async {
    calls.add('delta:$workItemId');
    return delta;
  }

  @override
  Future<WorkspaceHead?> reReadHead(
    String workItemId, {
    required String? startingRevision,
  }) async {
    calls.add('reRead:$workItemId:$startingRevision');
    return reReadHeadResult;
  }
}

/// A worktree-dirty probe answer whose `HEAD` was never read —
/// `GitWorkspaceDeltaProbe`'s short-circuit, `headMoved: null`
/// (`workspace_delta_probe.dart:210-216`).
const _dirtyUnreadHead = ExecutionDelta.changed(startingRevision: _start);

const _movedHead = WorkspaceHead(
  startingRevision: _start,
  headRevision: _produced,
  headMoved: true,
);

const _unmovedHead = WorkspaceHead(
  startingRevision: _start,
  headRevision: _start,
  headMoved: false,
);

AgentResult _agentClaimingFiles() {
  return agentResultFor().copyWith(
    changedFiles: [
      const ChangedFile(
        path: 'apps/server/lib/claimed.dart',
        operation: ChangedFileOperation.added,
      ),
    ],
  );
}

void main() {
  group('ImplementationArtifactProvenanceGate (F1)', () {
    late _FakeProvenanceSource source;

    ImplementationArtifactProvenanceGate gateWith({
      required ExecutionDelta delta,
      WorkspaceHead? reReadHeadResult,
    }) {
      source = _FakeProvenanceSource(
        delta: delta,
        reReadHeadResult: reReadHeadResult,
      );
      return ImplementationArtifactProvenanceGate(source: source);
    }

    Future<QAGateResult> evaluate(
      ImplementationArtifactProvenanceGate candidate, {
      Map<String, dynamic> config = _f1Config,
      String workItemId = 'work-1',
      AgentResult? agentResult,
    }) {
      return candidate.evaluate(
        workItemId,
        agentResult ?? agentResultFor(workItemId: workItemId),
        gateFor(
          gateId: 'feature-change-committed',
          type: 'implementation-artifact-provenance',
          config: config,
        ),
      );
    }

    String reason(QAGateResult result) => result.metadata!['reason'] as String;

    // ------------------------------------------------------------------
    // The six falsifiers of design §3.1 F1, one test each.
    // ------------------------------------------------------------------

    test('falsifier 1: clean tree with HEAD equal to startingRevision FAILS '
        '(the seven-of-seven case), after an unconditional re-read', () async {
      final gate = gateWith(
        delta: const ExecutionDelta.unchanged(
          startingRevision: _start,
          headRevision: _start,
        ),
        reReadHeadResult: _unmovedHead,
      );

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.failed);
      expect(reason(result), contains('nothing was produced'));
      // Unconditional: the probe already answered, yet the gate still
      // re-read rather than trusting the delta's headMoved.
      expect(
        source.calls,
        contains('reRead:work-1:$_start'),
        reason: 'the re-read must run even when the delta is unchanged',
      );
    });

    test(
      'falsifier 2: dirty tree, HEAD unmoved, re-read confirms headMoved false '
      'FAILS',
      () async {
        final gate = gateWith(
          delta: _dirtyUnreadHead,
          reReadHeadResult: _unmovedHead,
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('HEAD did not move'));
        expect(reason(result), contains('uncommitted work'));
      },
    );

    test('falsifier 3 (the correction): dirty tree with headMoved null PASSES '
        'when the re-read finds a new revision', () async {
      final gate = gateWith(
        delta: _dirtyUnreadHead,
        reReadHeadResult: _movedHead,
      );

      final result = await evaluate(gate);

      // Failing this run fails every correctly-committing lane that leaves
      // an untracked file — the waiver-pressure failure §3.3 names.
      expect(result.status, QAGateStatus.passed);
      expect(source.calls, contains('reRead:work-1:$_start'));
      expect(result.metadata!['producedRevision'], _produced);
      final committed = result.evidence.singleWhere(
        (e) => e.evidenceType == 'committed_revision',
      );
      expect(committed.content['producedRevision'], _produced);
      expect(committed.content['established'], isTrue);
      expect(committed.content['headMoved'], isTrue);
    });

    test(
      'falsifier 4: dirty tree with headMoved null, re-read cannot establish '
      'HEAD FAILS with "HEAD could not be established"',
      () async {
        final gate = gateWith(delta: _dirtyUnreadHead, reReadHeadResult: null);

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        // The verdict reason IS the establishment failure — never a
        // nothing-was-produced claim about a run nobody could look at.
        expect(
          reason(result),
          startsWith('HEAD could not be established'),
          reason:
              'a tooling fault must not be readable as an agent that '
              'did nothing',
        );
        expect(
          reason(result),
          contains('I could not look'),
          reason:
              'the null-head verdict must carry the could-not-look '
              'marker: "I could not look" is not "nothing was produced", '
              'and a rewrite that drops the marker launders the fault',
        );
        expect(result.metadata!['producedRevision'], isNull);
      },
    );

    test('falsifier 5: WorkspaceDelta.unreadable FAILS even when the re-read '
        'finds a moved HEAD', () async {
      final gate = gateWith(
        delta: const ExecutionDelta.unreadable(
          'the workspace could not be inspected with git',
        ),
        // Worst case for the predicate: the re-read alone would say moved.
        reReadHeadResult: _movedHead,
      );

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.failed);
      expect(reason(result), contains('could not be read'));
      expect(reason(result), contains('I could not look'));
      // Unconditional even here: the re-read is never skipped because the
      // probe failed — the two reads answer different questions.
      expect(source.calls, contains('reRead:work-1:null'));
    });

    test(
      'falsifier 6: AgentResult.changedFiles non-empty but HEAD unmoved FAILS '
      '- the claim cannot substitute for git',
      () async {
        final gate = gateWith(
          delta: _dirtyUnreadHead,
          reReadHeadResult: _unmovedHead,
        );

        final result = await evaluate(gate, agentResult: _agentClaimingFiles());

        expect(result.status, QAGateStatus.failed);
        // The claim is recorded in the evidence — seen — and did not move the
        // verdict.
        final deltaEvidence = result.evidence.singleWhere(
          (e) => e.evidenceType == 'execution_delta',
        );
        expect(deltaEvidence.content['agentReportedChangedFilePaths'], [
          'apps/server/lib/claimed.dart',
        ]);
      },
    );

    // ------------------------------------------------------------------
    // Structure beyond the six rows: evidence shape and unconditionality.
    // ------------------------------------------------------------------

    test('emits both declared evidence rows', () async {
      final gate = gateWith(
        delta: _dirtyUnreadHead,
        reReadHeadResult: _movedHead,
      );

      final result = await evaluate(gate);

      expect(
        result.evidence.map((e) => e.evidenceType),
        containsAll(['execution_delta', 'committed_revision']),
      );
      expect(
        result.evidence
            .firstWhere((e) => e.evidenceType == 'execution_delta')
            .artifactRef,
        'workspace_delta_probe',
      );
      expect(
        result.evidence
            .firstWhere((e) => e.evidenceType == 'committed_revision')
            .artifactRef,
        'workspace_head_reader',
      );
    });

    test(
      'records the probe short-circuit as three-valued, not as a false',
      () async {
        final gate = gateWith(
          delta: _dirtyUnreadHead,
          reReadHeadResult: _movedHead,
        );

        final result = await evaluate(gate);
        final deltaEvidence = result.evidence.singleWhere(
          (e) => e.evidenceType == 'execution_delta',
        );

        expect(deltaEvidence.content['probeHeadMoved'], isNull);
        expect(deltaEvidence.content['worktreeDirty'], isTrue);
        expect(deltaEvidence.content['isReadable'], isTrue);
      },
    );

    test(
      'reads delta and re-read for the work item, never the other way round',
      () async {
        final gate = gateWith(
          delta: _dirtyUnreadHead,
          reReadHeadResult: _movedHead,
        );

        await evaluate(gate, workItemId: 'work-42');

        expect(source.calls, ['delta:work-42', 'reRead:work-42:$_start']);
      },
    );

    // ------------------------------------------------------------------
    // Provision refusals (config-strict declarations, E3's pattern).
    // ------------------------------------------------------------------

    group('rejects malformed declarations with FormatException', () {
      Future<void> expectRefusal(Map<String, dynamic> config) async {
        final gate = gateWith(delta: _dirtyUnreadHead, reReadHeadResult: null);
        await expectLater(
          evaluate(gate, config: config),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message.toString(),
              'message',
              contains('feature-change-committed'),
            ),
          ),
        );
        expect(
          source.calls,
          isEmpty,
          reason:
              'a refusal happens at provision, '
              'before either read',
        );
      }

      test('requireReadableDelta absent', () async {
        await expectRefusal({..._f1Config}..remove('requireReadableDelta'));
      });

      test('requireReadableDelta false', () async {
        await expectRefusal({..._f1Config, 'requireReadableDelta': false});
      });

      test('requireHeadMoved absent', () async {
        await expectRefusal({..._f1Config}..remove('requireHeadMoved'));
      });

      test('requireHeadMoved false', () async {
        await expectRefusal({..._f1Config, 'requireHeadMoved': false});
      });

      test('recordProducedRevision absent', () async {
        await expectRefusal({..._f1Config}..remove('recordProducedRevision'));
      });

      test('recordProducedRevision false', () async {
        await expectRefusal({..._f1Config, 'recordProducedRevision': false});
      });
    });
  });
}
