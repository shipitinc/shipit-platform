import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

const _gateId = 'feature-change-scope-confined';

const _f2Config = {
  'evidenceTypes': ['committed_diff_paths'],
  'ownedPathGlobs': ['apps/server/**', 'packages/qa_orchestration/**'],
  'forbiddenPathGlobs': ['.decisions/**', 'AGENTS.md'],
  'pathSource': 'git_diff_name_only',
};

const _start = 'aaa111start';
const _produced = 'bbb222produced';

/// Stands in for the collector's `CommittedDiffPathCollectionException`
/// (`committed_diff_path_collector.dart:33`), which lives in
/// `execution_coordinator` and is not importable from this package — the fake
/// throws the same *shape* (an Exception, never an Error).
class _FakeCollectionException implements Exception {
  const _FakeCollectionException(this.message);

  final String message;

  @override
  String toString() => 'CommittedDiffPathCollectionException: $message';
}

const _baseline = CommittedDiffScopeBaseline(
  workingDirectory: '/work/workspace',
  startingRevision: _start,
);

const _movedHead = WorkspaceHead(
  startingRevision: _start,
  headRevision: _produced,
  headMoved: true,
);

CommittedDiffPaths _paths(List<String> paths) {
  return CommittedDiffPaths(
    startingRevision: _start,
    producedRevision: _produced,
    paths: paths,
  );
}

class _FakeScopeSource implements ChangeScopeSource {
  _FakeScopeSource({
    required this.baseline,
    required this.producedHeadResult,
    this.pathsResult,
    this.pathsError,
  });

  CommittedDiffScopeBaseline? baseline;
  WorkspaceHead? producedHeadResult;
  CommittedDiffPaths? pathsResult;
  Object? pathsError;
  final List<String> calls = [];

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('test/_FakeScopeSource');

  @override
  Future<CommittedDiffScopeBaseline?> readBaseline(String workItemId) async {
    calls.add('baseline:$workItemId');
    return baseline;
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    calls.add('producedHead:$workItemId');
    return producedHeadResult;
  }

  @override
  Future<CommittedDiffPaths> collectPaths({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async {
    calls.add('collect:$workingDirectory:$startingRevision..$producedRevision');
    final error = pathsError;
    if (error != null) {
      throw error;
    }
    return pathsResult!;
  }
}

void main() {
  group('ChangeScopeConfinementGate (F2)', () {
    late _FakeScopeSource source;

    ChangeScopeConfinementGate gateWith({
      CommittedDiffScopeBaseline? baseline = _baseline,
      WorkspaceHead? producedHeadResult = _movedHead,
      CommittedDiffPaths? pathsResult,
      Object? pathsError,
    }) {
      source = _FakeScopeSource(
        baseline: baseline,
        producedHeadResult: producedHeadResult,
        pathsResult: pathsResult,
        pathsError: pathsError,
      );
      return ChangeScopeConfinementGate(source: source);
    }

    Future<QAGateResult> evaluate(
      ChangeScopeConfinementGate candidate, {
      Map<String, dynamic> config = _f2Config,
      String workItemId = 'work-1',
    }) {
      return candidate.evaluate(
        workItemId,
        agentResultFor(workItemId: workItemId),
        gateFor(
          gateId: _gateId,
          type: 'change-scope-confinement',
          config: config,
        ),
      );
    }

    String reason(QAGateResult result) => result.metadata!['reason'] as String;

    // ------------------------------------------------------------------
    // The five falsifiers of design §3.1 F2, one test each.
    // ------------------------------------------------------------------

    test(
      'falsifier 1: a path matching no owned glob FAILS and names the path',
      () async {
        final gate = gateWith(
          pathsResult: _paths([
            'apps/server/lib/ok.dart',
            'apps/control_plane/lib/sneaky.dart', // owned by nobody here
          ]),
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('apps/control_plane/lib/sneaky.dart'));
        expect(reason(result), contains('matches no owned glob'));
      },
    );

    test(
      'falsifier 2: a path matching a forbidden glob FAILS even when it also '
      'matches an owned glob (forbidden wins)',
      () async {
        final gate = gateWith(
          pathsResult: _paths([
            'apps/server/lib/ok.dart',
            // Inside an owned tree AND on the forbidden list: ownership does
            // not launder a prohibition.
            'AGENTS.md',
          ]),
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('forbidden glob'));
        expect(reason(result), contains('AGENTS.md'));
      },
    );

    test(
      'falsifier 3: no baseline ("I could not look") FAILS and never reaches '
      'the collector',
      () async {
        final gate = gateWith(baseline: null);

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('could not be established'));
        expect(
          source.calls.where((c) => c.startsWith('collect:')),
          isEmpty,
          reason: 'a failed look must not be laundered into an enumeration',
        );
      },
    );

    test('falsifier 4: re-read returns null HEAD ("HEAD could not be '
        'established") FAILS and never reaches the collector', () async {
      final gate = gateWith(producedHeadResult: null);

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.failed);
      expect(reason(result), contains('HEAD could not be established'));
      expect(source.calls.where((c) => c.startsWith('collect:')), isEmpty);
    });

    test(
      'falsifier 5: a throwing enumeration FAILS — never an empty list, never '
      'a vacuous pass',
      () async {
        // This is the §6.4 N1 vacuous-pass shape: a broken reader that reports
        // failure as an empty set would pass here with "no paths out of
        // bounds". The collector surfaces it as an exception instead, and the
        // gate converts it to a failure.
        final gate = gateWith(
          pathsError: const _FakeCollectionException(
            'git diff failed: exit 128',
          ),
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('could not be enumerated'));
        expect(reason(result), contains('git diff failed'));
        expect(
          reason(result),
          contains('never an empty path set'),
          reason: 'the message must state the rule, not just the fault',
        );
      },
    );

    // ------------------------------------------------------------------
    // Structure beyond the falsifiers: plumbing, evidence, pass shape.
    // ------------------------------------------------------------------

    test('all-owned paths PASS and the collector receives <start>..<produced> '
        'with the baseline working directory', () async {
      final gate = gateWith(
        pathsResult: _paths([
          'apps/server/lib/a.dart',
          'packages/qa_orchestration/lib/b.dart',
        ]),
      );

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(source.calls, [
        'baseline:work-1',
        'producedHead:work-1',
        'collect:/work/workspace:$_start..$_produced',
      ]);
    });

    test('an empty committed set from a SUCCESSFUL enumeration PASSES — empty '
        'means "git answered with nothing", not "could not look"', () async {
      // CommittedDiffPaths' own contract: the empty set is only constructible
      // from a successful read (committed_diff_paths.dart:67-70). The gate
      // must treat that as confined, not invent a failure.
      final gate = gateWith(pathsResult: _paths([]));

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(result.metadata!['pathCount'], 0);
    });

    test(
      'the evidence row is uncapped: every judged path is recorded',
      () async {
        // The sixth path is where a hidden prohibited file lives when a reader
        // takes a 5-prefix (workspace_delta_probe.dart:160). This row shows
        // all seven, and the seventh is the forbidden one.
        final gate = gateWith(
          pathsResult: _paths([
            'apps/server/lib/1.dart',
            'apps/server/lib/2.dart',
            'apps/server/lib/3.dart',
            'apps/server/lib/4.dart',
            'apps/server/lib/5.dart',
            'apps/server/lib/6.dart',
            '.decisions/record.json',
          ]),
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        final row = result.evidence.single;
        expect(row.evidenceType, 'committed_diff_paths');
        expect(row.artifactRef, 'git_diff_name_only');
        expect((row.content['paths'] as List).length, 7);
        expect(row.content['pathCount'], 7);
        expect(row.content['startingRevision'], _start);
        expect(row.content['producedRevision'], _produced);
      },
    );

    test('producedRevision comes from the typed re-read, and the collector is '
        'never asked with an unestablished head', () async {
      // headMoved:false with a revision is still a valid right edge (the run
      // may have committed nothing, but the range is well-formed and any
      // untracked files are still confinement-relevant).
      final unmovedHead = WorkspaceHead(
        startingRevision: _start,
        headRevision: _start,
        headMoved: false,
      );
      final gate = gateWith(
        producedHeadResult: unmovedHead,
        pathsResult: _paths(['apps/server/lib/untracked.dart']),
      );

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.passed);
      expect(
        source.calls,
        contains('collect:/work/workspace:$_start..$_start'),
      );
      expect(result.metadata!['producedRevision'], _start);
    });

    test('a re-read with an empty headRevision refuses the range', () async {
      // WorkspaceHead.headRevision is non-empty by contract
      // (workspace_head.dart:34-35); a reader that broke that contract must
      // fail closed rather than build a range with a hole in it.
      final gate = gateWith(
        producedHeadResult: const WorkspaceHead(
          startingRevision: _start,
          headRevision: '',
          headMoved: true,
        ),
        pathsResult: _paths([]),
      );

      final result = await evaluate(gate);

      expect(result.status, QAGateStatus.failed);
      expect(reason(result), contains('empty produced revision'));
      expect(source.calls.where((c) => c.startsWith('collect:')), isEmpty);
    });

    test(
      'a baseline with an empty starting revision refuses the range',
      () async {
        final gate = gateWith(
          baseline: const CommittedDiffScopeBaseline(
            workingDirectory: '/work/workspace',
            startingRevision: '  ',
          ),
          pathsResult: _paths([]),
        );

        final result = await evaluate(gate);

        expect(result.status, QAGateStatus.failed);
        expect(reason(result), contains('empty starting revision'));
        expect(source.calls.where((c) => c.startsWith('collect:')), isEmpty);
      },
    );
  });

  // ------------------------------------------------------------------
  // The hand-rolled glob matcher: the confinement rule's own mechanism.
  // ------------------------------------------------------------------
  group('ownership glob matching', () {
    Future<QAGateStatus> status({
      required List<String> owned,
      List<String> forbidden = const [],
      required List<String> paths,
    }) async {
      final gate = ChangeScopeConfinementGate(
        source: _FakeScopeSource(
          baseline: _baseline,
          producedHeadResult: _movedHead,
          pathsResult: _paths(paths),
        ),
      );
      final result = await gate.evaluate(
        'work-1',
        agentResultFor(),
        gateFor(
          gateId: _gateId,
          type: 'change-scope-confinement',
          config: {
            'ownedPathGlobs': owned,
            'forbiddenPathGlobs': forbidden,
            'pathSource': 'git_diff_name_only',
          },
        ),
      );
      return result.status;
    }

    test('dir/** matches files at every depth under dir/', () async {
      expect(
        await status(
          owned: const ['apps/server/**'],
          paths: const [
            'apps/server/lib/a.dart',
            'apps/server/lib/deep/b/c.dart',
          ],
        ),
        QAGateStatus.passed,
      );
    });

    test(
      'dir/** does NOT match a sibling that merely shares a prefix',
      () async {
        // 'apps/serverX' must not be owned by the 'apps/server/**' glob —
        // a prefix match would confine nothing.
        expect(
          await status(
            owned: const ['apps/server/**'],
            paths: const ['apps/serverX/lib/a.dart'],
          ),
          QAGateStatus.failed,
        );
      },
    );

    test('* does not cross /', () async {
      expect(
        await status(
          owned: const ['apps/server/*.dart'],
          paths: const ['apps/server/a.dart'],
        ),
        QAGateStatus.passed,
      );
      expect(
        await status(
          owned: const ['apps/server/*.dart'],
          paths: const ['apps/server/lib/a.dart'],
        ),
        QAGateStatus.failed,
      );
    });

    test('**/x matches x at any depth including the root', () async {
      expect(
        await status(
          owned: const ['**/AGENTS.md'],
          paths: const ['AGENTS.md', 'apps/server/AGENTS.md'],
        ),
        QAGateStatus.passed,
      );
    });

    test('a/**/b matches both a/b and a/x/b', () async {
      expect(
        await status(owned: const ['a/**/b'], paths: const ['a/b', 'a/x/b']),
        QAGateStatus.passed,
      );
    });

    test('? matches exactly one non-slash character', () async {
      expect(
        await status(
          owned: const ['apps/server/file?.dart'],
          paths: const ['apps/server/file1.dart'],
        ),
        QAGateStatus.passed,
      );
      expect(
        await status(
          owned: const ['apps/server/file?.dart'],
          paths: const ['apps/server/file.dart', 'apps/server/file12.dart'],
        ),
        QAGateStatus.failed,
      );
    });

    test('regex metacharacters in globs and paths are literal', () async {
      // A path with a '.' must not be eaten by the dot, and a glob with a '+'
      // must not become a regex quantifier.
      expect(
        await status(
          owned: const ['apps/server/a+b.dart'],
          paths: const ['apps/server/a+b.dart', 'apps/server/aab.dart'],
        ),
        QAGateStatus.failed, // a+b.dart matches; aab.dart must not
      );
    });

    test('a trailing slash on a glob means "everything under here"', () async {
      expect(
        await status(
          owned: const ['apps/server/'],
          paths: const ['apps/server/lib/a.dart'],
        ),
        QAGateStatus.passed,
      );
    });

    test(
      'a leading ./ on paths and globs is stripped before matching',
      () async {
        expect(
          await status(
            owned: const ['./apps/server/**'],
            paths: const ['./apps/server/lib/a.dart'],
          ),
          QAGateStatus.passed,
        );
      },
    );

    test('matching is case-sensitive', () async {
      expect(
        await status(
          owned: const ['apps/server/**'],
          paths: const ['Apps/Server/lib/a.dart'],
        ),
        QAGateStatus.failed,
      );
    });
  });

  // ------------------------------------------------------------------
  // Provision refusals (config-strict declarations).
  // ------------------------------------------------------------------
  group('rejects malformed declarations with FormatException', () {
    Future<void> expectRefusal(Map<String, dynamic> config) async {
      final source = _FakeScopeSource(
        baseline: _baseline,
        producedHeadResult: _movedHead,
        pathsResult: _paths([]),
      );
      final gate = ChangeScopeConfinementGate(source: source);
      await expectLater(
        gate.evaluate(
          'work-1',
          agentResultFor(),
          gateFor(
            gateId: _gateId,
            type: 'change-scope-confinement',
            config: config,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message.toString(),
            'message',
            contains(_gateId),
          ),
        ),
      );
      expect(
        source.calls,
        isEmpty,
        reason: 'a refusal happens at provision, before any read',
      );
    }

    test('ownedPathGlobs absent', () async {
      await expectRefusal({
        'forbiddenPathGlobs': [],
        'pathSource': 'git_diff_name_only',
      });
    });

    test('ownedPathGlobs empty', () async {
      await expectRefusal({
        'ownedPathGlobs': [],
        'forbiddenPathGlobs': [],
        'pathSource': 'git_diff_name_only',
      });
    });

    test('ownedPathGlobs not a list', () async {
      await expectRefusal({
        'ownedPathGlobs': 'apps/server/**',
        'forbiddenPathGlobs': [],
        'pathSource': 'git_diff_name_only',
      });
    });

    test('ownedPathGlobs contains a non-string entry', () async {
      await expectRefusal({
        'ownedPathGlobs': [42],
        'forbiddenPathGlobs': [],
        'pathSource': 'git_diff_name_only',
      });
    });

    test('forbiddenPathGlobs absent — an explicit empty list is legal, absence '
        'is not', () async {
      await expectRefusal({
        'ownedPathGlobs': ['apps/server/**'],
        'pathSource': 'git_diff_name_only',
      });
    });

    test(
      'forbiddenPathGlobs empty IS accepted (a lane may ban nothing)',
      () async {
        final source = _FakeScopeSource(
          baseline: _baseline,
          producedHeadResult: _movedHead,
          pathsResult: _paths(['apps/server/lib/a.dart']),
        );
        final gate = ChangeScopeConfinementGate(source: source);
        final result = await gate.evaluate(
          'work-1',
          agentResultFor(),
          gateFor(
            gateId: _gateId,
            type: 'change-scope-confinement',
            config: {
              'ownedPathGlobs': ['apps/server/**'],
              'forbiddenPathGlobs': [],
              'pathSource': 'git_diff_name_only',
            },
          ),
        );
        expect(result.status, QAGateStatus.passed);
      },
    );

    test('pathSource absent', () async {
      await expectRefusal({
        'ownedPathGlobs': ['apps/server/**'],
        'forbiddenPathGlobs': [],
      });
    });

    test('pathSource has an unsupported value', () async {
      await expectRefusal({
        'ownedPathGlobs': ['apps/server/**'],
        'forbiddenPathGlobs': [],
        'pathSource': 'workspace_delta',
      });
    });
  });
}
