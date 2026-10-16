import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:test/test.dart';

import 'support/git_fixture.dart';

/// The probe's own contract, one layer below the coordinator.
///
/// `success_artifact_rule_test.dart` proves what an operator sees: which
/// executions settle `failed`. This file proves why, by pinning the reading the
/// verdict is computed from — so a change to [WorkspaceDelta] that kept every
/// coordinator-level test green would still be caught here.
///
/// ## THE BLIND SPOT THIS EXISTS BECAUSE OF
///
/// The probe read `git status --porcelain`, and on an EMPTY result returned
/// [WorkspaceDelta.unchanged] carrying `startingRevision` and `headRevision` —
/// and then compared neither to the other. `hasChanges` was
/// `changedPaths.isNotEmpty`, and `unchanged` hardcoded `changedPaths = []`, so
/// the value was true only in the one case it named.
///
/// Nothing in the type objected. `unchanged` was constructible with a
/// `headRevision` that did NOT equal `startingRevision`, so the constructor
/// accepted a value that contradicted its own doc: "The worktree is clean and
/// `HEAD` still equals the revision the execution started from. This is the
/// only value that means 'produced nothing'." The type permitted a
/// "nothing was produced" value for a workspace where HEAD had moved. The
/// defect was not that a branch was missed; it was that [WorkspaceDelta] could
/// express the contradiction and nothing rejected it.
void main() {
  const probe = GitWorkspaceDeltaProbe();

  late Directory temp;
  late GitWorkspaceFixture git;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('workspace_delta_');
    git = GitWorkspaceFixture.create(temp.path);
  });

  tearDown(() {
    git.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<WorkspaceDelta> probeIt() => probe.probe(
    workingDirectory: git.root.path,
    startingRevision: git.startingRevision,
  );

  group('hasChanges is the committer\'s predicate: dirty OR moved', () {
    test(
      'a dirty worktree changes, and HEAD is never read to prove it',
      () async {
        git.writeFile('lib/new.dart', 'int answer() => 42;\n');

        final delta = await probeIt();

        expect(delta.isReadable, isTrue);
        expect(delta.changedPaths, ['lib/new.dart']);
        expect(
          delta.hasChanges,
          isTrue,
          reason: 'dirty is proof of production',
        );
        expect(
          delta.headMoved,
          isNull,
          reason:
              'null, NOT false: the probe short-circuits on a dirty tree and never '
              'reads HEAD, so "not established" must not be reported as '
              '"established as no"',
        );
        expect(
          delta.headRevision,
          isNull,
          reason: 'the same short-circuit — one subprocess fewer per settle',
        );
      },
    );

    test('a CLEAN worktree with HEAD past the baseline changes', () async {
      // The case the reviewer's reproduction caught. An implementer that commits
      // its own work leaves NO dirty paths, so anything reading only
      // `git status --porcelain` sees nothing at all.
      git.writeFile('lib/new.dart', 'int answer() => 42;\n');
      git.commitAll('the agent commits its own work');

      expect(git.isCleanTree, isTrue, reason: 'premise');

      final delta = await probeIt();

      expect(delta.isReadable, isTrue);
      expect(
        delta.headMoved,
        isTrue,
        reason:
            'a moved HEAD is the committer\'s `moved` half, and the one half a '
            'porcelain-only reading cannot see',
      );
      expect(delta.headRevision, git.head);
      expect(delta.startingRevision, git.startingRevision);
      expect(delta.changedPaths, isEmpty);
      expect(
        delta.hasChanges,
        isTrue,
        reason:
            'the run produced a commit. Scoring it false hands this rule a '
            'permanent failure for a run that produced a real artifact.',
      );
    });

    test('a CLEAN worktree with HEAD on the baseline changes nothing', () async {
      final delta = await probeIt();

      expect(delta.isReadable, isTrue);
      expect(delta.headMoved, isFalse);
      expect(
        delta.headRevision,
        git.startingRevision,
        reason:
            'and now it EQUALS the baseline, which is the comparison this value '
            'never used to make',
      );
      expect(delta.changedPaths, isEmpty);
      expect(delta.hasChanges, isFalse);
    });

    test(
      'an unreadable delta reports no changes and does not know about HEAD',
      () async {
        final delta = await const GitWorkspaceDeltaProbe().probe(
          workingDirectory: '/definitely/not/a/repository',
          startingRevision: 'abc123',
        );

        expect(delta.isReadable, isFalse);
        expect(
          delta.hasChanges,
          isFalse,
          reason:
              '"could not look" must never be laundered into "looked and saw '
              'nothing" — the whole reason this type is three-valued',
        );
        expect(delta.headMoved, isNull);
      },
    );

    test('no baseline means unreadable, not unchanged', () async {
      // With nothing to compare against, "HEAD moved" is unanswerable, and the
      // honest answer is "I could not look" rather than "it did not move".
      final delta = await probe.probe(
        workingDirectory: git.root.path,
        startingRevision: null,
      );

      expect(delta.isReadable, isFalse);
      expect(delta.hasChanges, isFalse);
    });
  });

  group('the value cannot contradict its own constructor', () {
    test('`unchanged` carries headMoved false by construction', () {
      // Before the fix this constructor took whatever HEAD was and stored it, so
      // `WorkspaceDelta.unchanged(startingRevision: a, headRevision: b)` was a
      // perfectly legal "produced nothing" for a workspace that had moved. The
      // invariant is now in the type, so the impossible value is unconstructible
      // rather than merely untested.
      const delta = WorkspaceDelta.unchanged(
        startingRevision: 'aaa',
        headRevision: 'aaa',
      );

      expect(delta.headMoved, isFalse);
      expect(delta.hasChanges, isFalse);
    });

    test('`committed` carries headMoved true and no invented paths', () {
      const delta = WorkspaceDelta.committed(
        startingRevision: 'aaa',
        headRevision: 'bbb',
      );

      expect(delta.headMoved, isTrue);
      expect(delta.hasChanges, isTrue);
      expect(
        delta.changedPaths,
        isEmpty,
        reason:
            'git listed none, so none are claimed. A synthetic entry here would '
            'reach the failure reason as a `changedFileCount` for a run whose '
            'files git reported none of.',
      );
    });

    test('`changed` with headMoved unset still counts on its paths alone', () {
      const delta = WorkspaceDelta.changed(
        startingRevision: 'aaa',
        headRevision: null,
        changedPaths: ['lib/new.dart'],
      );

      expect(
        delta.headMoved,
        isNull,
        reason: 'omitting headMoved is a statement, not a default to false',
      );
      expect(
        delta.hasChanges,
        isTrue,
        reason:
            'and a null headMoved must never turn a dirty tree into a failure — '
            'the dirty branch is the probe\'s common path',
      );
    });
  });
}
