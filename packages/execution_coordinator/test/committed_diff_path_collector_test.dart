import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/git_fixture.dart';

/// The committed-range path reader, one layer below any gate that will use it.
///
/// No gate uses it yet — the evaluators land in a later slice. What this file
/// has to establish is that the reader **cannot** be the two broken substitutes
/// it exists to replace, and that is a property of the reader rather than of
/// any caller, so it is testable now.
///
/// ## WHAT IS ACTUALLY BEING FALSIFIED HERE
///
/// 1. **The cap is gone.** [WorkspaceDelta.changedPaths] truncates to 5
///    (`workspace_delta_probe.dart:160`, `:213-214`). A confinement gate reading
///    a prefix passes a change whose SIXTH path is prohibited. The test below
///    commits seven paths and puts the prohibited one last.
/// 2. **Untracked files are in the set.** `git diff` never lists them.
/// 3. **A failed enumeration is a FAIL, never an empty list** — proven
///    separately for each of the two enumerations, because "either" is a claim
///    about both and a test that only exercises the first proves nothing about
///    the second.
void main() {
  const collector = CommittedDiffPathCollector();

  late Directory temp;
  late GitWorkspaceFixture git;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('committed_diff_');
    git = GitWorkspaceFixture.create(temp.path);
  });

  tearDown(() {
    git.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Collects the committed range [start]..[end] against the fixture.
  Future<CommittedDiffPaths> collect(String start, String end) =>
      collector.collect(
        workingDirectory: git.root.path,
        startingRevision: start,
        producedRevision: end,
      );

  group('THE CAP IS GONE — more than five paths', () {
    test('a committed change of SEVEN paths is reported whole, with the '
        'seventh — the prohibited one — present', () async {
      // Six benign paths and one that is not owned. The cap is 5, so under
      // the capped reader this assertion fails on two counts: the set is
      // short, and the only path that matters is the one that was dropped.
      const paths = <String>[
        'lib/a.dart',
        'lib/b.dart',
        'lib/c.dart',
        'lib/d.dart',
        'lib/e.dart',
        'lib/f.dart',
        'docs/forbidden.md',
      ];
      for (final p in paths) {
        git.writeFile(p, '// $p\n');
      }

      final start = git.head;
      final produced = git.commitAll('seven paths');

      final result = await collect(start, produced);

      // Non-vacuity on the premise: the range must really hold seven paths, or
      // the assertion below proves nothing.
      final porcelain = git.porcelainLines;
      expect(porcelain, isEmpty, reason: 'the commit really was committed');
      expect(paths.length, greaterThan(5), reason: 'pins the >5 premise');

      expect(
        result.paths.length,
        greaterThan(5),
        reason:
            'a reader that truncates to 5 reports 5 here; the whole point is '
            'that the sixth and seventh paths are unexamined and therefore '
            'unjudged by a confinement gate',
      );
      expect(
        result.paths,
        containsAll(paths),
        reason: 'every committed path, in full, including the last',
      );
      expect(
        result.paths,
        contains('docs/forbidden.md'),
        reason:
            'THE row the capped reader fails: under reportedPathCap = 5 the '
            'prohibited path is the one that gets cut, so the gate passes',
      );
    });

    test(
      'the cap is not merely larger than 5 — a hundred paths come back whole',
      () async {
        // A cap raised from 5 to 10 would satisfy the seven-path test above and
        // still be a defect. Only a reader with no cap at all survives this.
        for (var i = 0; i < 100; i++) {
          git.writeFile('bulk/file_$i.dart', '// $i\n');
        }
        final start = git.head;
        final produced = git.commitAll('one hundred paths');

        final result = await collect(start, produced);

        expect(result.paths.length, 100);
        expect(result.paths.first, 'bulk/file_0.dart');
        expect(result.paths.last, 'bulk/file_99.dart');
      },
    );
  });

  group('UNTRACKED FILES ARE IN THE SET', () {
    test('a brand-new file left untracked is enumerated, which git diff never '
        'reports', () async {
      final start = git.head;
      git.writeFile('lib/tracked_edit.dart', '// edited\n');
      final produced = git.commitAll('one committed path');
      // Never staged, never committed. This is the file a confinement gate
      // exists to catch: `git diff --name-only <start>..<produced>` cannot
      // see it, so without the second enumeration it is invisible.
      git.createUntrackedFile('docs/brand_new_forbidden.md', '# forbidden\n');

      // Premise, asserted rather than assumed: the file really is untracked,
      // so it could only have reached the result through the second
      // enumeration. Two empty lists comparing equal is the trap here, so the
      // positive assertion below is checked for non-emptiness too.
      expect(
        git.porcelainLines,
        contains('?? docs/'),
        reason:
            'the file must really be untracked — otherwise this test would '
            'pass through the committed-range enumeration alone and would '
            'prove nothing about `ls-files`. (`--porcelain` collapses an '
            'entirely untracked directory to `docs/`, so that is the shape '
            'the premise takes, not a different file.)',
      );

      final result = await collect(start, produced);

      expect(
        result.paths,
        isNotEmpty,
        reason:
            'F-179: never assert on two '
            'possibly-empty lists without proving both sides read something',
      );
      expect(
        result.paths,
        contains('docs/brand_new_forbidden.md'),
        reason:
            'untracked files must be enumerated; this is the failure mode the '
            'design calls "a brand-new prohibited file is invisible and the '
            'gate passes"',
      );
      expect(result.paths.length, 2);
    });

    test(
      'a gitignored file is NOT enumerated, because it is not a change to judge',
      () async {
        git.writeFile('.gitignore', 'build/\n');
        final start = git.head;
        final produced = git.commitAll('gitignore');

        git.createUntrackedFile('build/output.txt', 'artifact\n');

        final result = await collect(start, produced);

        expect(
          result.paths,
          isNot(contains('build/output.txt')),
          reason:
              '--exclude-standard is what makes this a change set and not a '
              'dump of every byte on the disk',
        );
        expect(result.paths, ['.gitignore']);
      },
    );

    test(
      'a committed range plus untracked files is the union of both sources',
      () async {
        for (var i = 0; i < 3; i++) {
          git.writeFile('committed_$i.dart', '// $i\n');
        }
        git.writeFile('.gitignore', 'ignored/\n');
        final start = git.head;
        final produced = git.commitAll('three plus gitignore');
        git.createUntrackedFile('untracked_0.dart', '// u\n');
        git.createUntrackedFile('ignored/never.txt', '// nope\n');

        final result = await collect(start, produced);

        expect(result.paths, [
          '.gitignore',
          'committed_0.dart',
          'committed_1.dart',
          'committed_2.dart',
          'untracked_0.dart',
        ]);
      },
    );
  });

  group('ORDERING IS A TOTAL ORDER', () {
    test(
      'paths come back sorted by code unit, whatever order the sources emitted',
      () async {
        // Written in deliberately reverse-ish order so a reader that passed
        // git's output through verbatim would fail this.
        git.writeFile('zeta.dart', '// z\n');
        git.writeFile('alpha.dart', '// a\n');
        git.writeFile('Mu.dart', '// M\n');
        git.writeFile('beta.dart', '// b\n');
        final start = git.head;
        final produced = git.commitAll('mixed case');
        git.createUntrackedFile('omega.dart', '// o\n');
        git.createUntrackedFile('Gamma.dart', '// G\n');

        final result = await collect(start, produced);

        expect(result.paths, [
          'Gamma.dart',
          'Mu.dart',
          'alpha.dart',
          'beta.dart',
          'omega.dart',
          'zeta.dart',
        ]);
        expect(result.paths, result.paths.toList()..sort());
      },
    );

    test(
      'the returned list is unmodifiable, so a caller cannot disturb the order',
      () async {
        git.writeFile('a.dart', '// a\n');
        final start = git.head;
        final produced = git.commitAll('one');

        final result = await collect(start, produced);

        expect(
          () => result.paths.add('injected.dart'),
          throwsUnsupportedError,
          reason:
              'the ordering is an invariant of the value type; a caller that '
              'mutates it would reintroduce the unsorted-set defect one layer up',
        );
      },
    );
  });

  group(
    'AN EMPTY RESULT MEANS "GIT SAID THERE ARE NONE", NOT "I COULD NOT LOOK"',
    () {
      test(
        'a committed change that reverted itself enumerates to genuinely empty',
        () async {
          final start = git.head;
          // Change a file, commit it, then restore the original bytes and
          // commit again. <start>..<produced> then has no net content change,
          // which is the only way to ask git for a genuinely EMPTY answer
          // rather than one a reader truncated to nothing.
          git.writeFile(
            'lib/calculator.dart',
            'int add(int a, int b) => a + b;\n// touched\n',
          );
          final moved = git.commitAll('touch');
          git.writeFile(
            'lib/calculator.dart',
            'int add(int a, int b) => a + b;\n',
          );
          final produced = git.commitAll('restore original content');

          final result = await collect(start, produced);

          expect(
            result.paths,
            isEmpty,
            reason:
                'this is the ONE case where an empty list is the right answer, and '
                'it is right only because a failed enumeration throws instead of '
                'returning empty',
          );
          expect(git.isCleanTree, isTrue);
          expect(moved, isNot(produced));
        },
      );
    },
  );

  group('EITHER ENUMERATION FAILING IS A FAIL, NEVER AN EMPTY LIST', () {
    test('a bad starting revision FAILS on the committed range', () async {
      git.writeFile('a.dart', '// a\n');
      final produced = git.commitAll('one');

      await expectLater(
        collect('not-a-revision-at-all', produced),
        throwsA(
          isA<CommittedDiffPathCollectionException>()
              .having(
                (e) => e.enumeration,
                'enumeration',
                CommittedDiffEnumeration.committedRange,
              )
              .having((e) => e.exitCode, 'exitCode', isNotNull),
        ),
        reason:
            'git answers an unresolvable revision with a non-zero exit; '
            'returning an empty list here would report "nothing was out of '
            'bounds" for a range that was never read',
      );
    });

    test('a bad produced revision FAILS on the committed range', () async {
      git.writeFile('a.dart', '// a\n');
      final start = git.commitAll('one');

      await expectLater(
        collect(start, 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'),
        throwsA(
          isA<CommittedDiffPathCollectionException>().having(
            (e) => e.enumeration,
            'enumeration',
            CommittedDiffEnumeration.committedRange,
          ),
        ),
      );
    });

    test('a directory that is not a git repository FAILS', () async {
      final plain = Directory('${temp.path}/not-a-repo')..createSync();
      File('${plain.path}/loose.txt').writeAsStringSync('x\n');

      await expectLater(
        collector.collect(
          workingDirectory: plain.path,
          startingRevision: 'abc',
          producedRevision: 'def',
        ),
        throwsA(
          isA<CommittedDiffPathCollectionException>().having(
            (e) => e.enumeration,
            'enumeration',
            CommittedDiffEnumeration.committedRange,
          ),
        ),
        reason:
            'not a worktree is "could not look", and it must never arrive as '
            'the empty path list that would let a confinement gate pass',
      );
    });

    test(
      'a missing starting revision FAILS before spawning anything',
      () async {
        git.writeFile('a.dart', '// a\n');
        final produced = git.commitAll('one');

        await expectLater(
          collect('   ', produced),
          throwsA(
            isA<CommittedDiffPathCollectionException>().having(
              (e) => e.reason,
              'reason',
              contains('no starting revision'),
            ),
          ),
        );
      },
    );

    test(
      'a missing produced revision FAILS before spawning anything',
      () async {
        final start = git.head;

        await expectLater(
          collect(start, ''),
          throwsA(
            isA<CommittedDiffPathCollectionException>().having(
              (e) => e.reason,
              'reason',
              contains('no produced revision'),
            ),
          ),
        );
      },
    );

    // The two stub-git tests below are the ones that make "EITHER" mean
    // something. The cases above all fail on the FIRST enumeration, because
    // fail-fast stops there — so on their own they would pass just as happily
    // if the second enumeration were deleted, or returned a hardcoded `[]`.
    // Each stub fails exactly one subcommand and succeeds on the other, which
    // is the only way to reach the second branch and prove it is a FAIL too.
    test(
      'a git binary that exits non-zero on `diff` FAILS, even though '
      '`ls-files` would have succeeded',
      () async {
        final stubDir = Directory('${temp.path}/stub_diff')
          ..createSync(recursive: true);
        final stub = File('${stubDir.path}/git')
          ..writeAsStringSync('''
#!/bin/sh
# Succeed for everything except `diff`, which exits non-zero with stderr.
for arg in "\$@"; do
  if [ "\$arg" = "diff" ]; then
    echo "stub: diff refused" >&2
    exit 128
  fi
done
exit 0
''');
        Process.runSync('chmod', ['+x', stub.path]);

        final failing = CommittedDiffPathCollector(git: stub.path);

        await expectLater(
          failing.collect(
            workingDirectory: git.root.path,
            startingRevision: git.head,
            producedRevision: git.head,
          ),
          throwsA(
            isA<CommittedDiffPathCollectionException>()
                .having(
                  (e) => e.enumeration,
                  'enumeration',
                  CommittedDiffEnumeration.committedRange,
                )
                .having((e) => e.exitCode, 'exitCode', 128)
                .having((e) => e.stderr, 'stderr', contains('diff refused')),
          ),
        );
      },
      skip: Platform.isWindows ? 'the git stub is a POSIX shell script' : null,
    );

    test(
      'a git binary that exits non-zero on `ls-files` FAILS, which is the '
      'branch no other test in this file reaches',
      () async {
        final stubDir = Directory('${temp.path}/stub_lsfiles')
          ..createSync(recursive: true);
        final stub = File('${stubDir.path}/git')
          ..writeAsStringSync('''
#!/bin/sh
# Succeed for `diff` (empty output = no committed change) and fail for
# `ls-files`, so the SECOND enumeration is the only one that fails.
for arg in "\$@"; do
  if [ "\$arg" = "ls-files" ]; then
    echo "stub: ls-files refused" >&2
    exit 3
  fi
done
exit 0
''');
        Process.runSync('chmod', ['+x', stub.path]);

        final failing = CommittedDiffPathCollector(git: stub.path);

        await expectLater(
          failing.collect(
            workingDirectory: git.root.path,
            startingRevision: git.head,
            producedRevision: git.head,
          ),
          throwsA(
            isA<CommittedDiffPathCollectionException>()
                .having(
                  (e) => e.enumeration,
                  'enumeration',
                  CommittedDiffEnumeration.untrackedWorktree,
                )
                .having((e) => e.exitCode, 'exitCode', 3)
                .having(
                  (e) => e.stderr,
                  'stderr',
                  contains('ls-files refused'),
                ),
          ),
          reason:
              'the first enumeration succeeded with a genuinely empty result. '
              'Only the FAIL-on-the-second rule stands between that empty list '
              'and a confinement gate that passes on an unreadable workspace',
        );
      },
      skip: Platform.isWindows ? 'the git stub is a POSIX shell script' : null,
    );

    test(
      'a git binary that cannot be spawned at all FAILS rather than returning '
      'an empty list',
      () async {
        final missing = CommittedDiffPathCollector(
          git: '${temp.path}/definitely-not-git',
        );

        await expectLater(
          missing.collect(
            workingDirectory: git.root.path,
            startingRevision: git.head,
            producedRevision: git.head,
          ),
          throwsA(
            isA<CommittedDiffPathCollectionException>()
                .having(
                  (e) => e.enumeration,
                  'enumeration',
                  CommittedDiffEnumeration.committedRange,
                )
                .having((e) => e.exitCode, 'exitCode', isNull),
          ),
        );
      },
    );

    test(
      'a wedged git is bounded by the declared timeout and still FAILS',
      () async {
        final stubDir = Directory('${temp.path}/stub_wedge')
          ..createSync(recursive: true);
        final stub = File('${stubDir.path}/git')
          ..writeAsStringSync('#!/bin/sh\nsleep 30\n');
        Process.runSync('chmod', ['+x', stub.path]);

        final wedged = CommittedDiffPathCollector(
          git: stub.path,
          timeout: const Duration(milliseconds: 400),
        );

        final elapsed = Stopwatch()..start();
        await expectLater(
          wedged.collect(
            workingDirectory: git.root.path,
            startingRevision: git.head,
            producedRevision: git.head,
          ),
          throwsA(isA<CommittedDiffPathCollectionException>()),
        );
        elapsed.stop();

        expect(
          elapsed.elapsed,
          lessThan(const Duration(seconds: 20)),
          reason:
              'the declared bound must fire well before the 30s stub finishes '
              '(waited ${elapsed.elapsed}); without the bound the call would '
              'return a value obtained after the stub gave up, not a FAIL',
        );
      },
      skip: Platform.isWindows ? 'the git stub is a POSIX shell script' : null,
    );
  });

  group('PROVENANCE OF THE RESULT', () {
    test('the result names the range it was collected over', () async {
      git.writeFile('a.dart', '// a\n');
      final start = git.head;
      final produced = git.commitAll('one');

      final result = await collect(start, produced);

      expect(result.startingRevision, start);
      expect(result.producedRevision, produced);
      expect(result.paths, ['a.dart']);
    });

    test('a rename is reported as its destination only, and that asymmetry is '
        'recorded rather than hidden', () async {
      // `--name-only` on a rename reports the DESTINATION only, so the old
      // path is not in the set. Worth pinning: a gate reading only the new
      // name never learns that a file left OWNED_PATHS entirely.
      final start = git.head;
      final move = Process.runSync('git', [
        '-C',
        git.root.path,
        'mv',
        'lib/calculator.dart',
        'lib/renamed.dart',
      ]);
      expect(move.exitCode, 0, reason: 'the rename fixture must be real');
      final produced = git.commitAll('rename');

      final result = await collect(start, produced);

      expect(result.paths, ['lib/renamed.dart']);
      expect(
        result.paths,
        isNot(contains('lib/calculator.dart')),
        reason:
            'pins a real limit of the command the design specifies: the '
            'rename SOURCE is not enumerated. A deletion IS reported, so a '
            'path leaving OWNED_PATHS is not lost silently, but this is a '
            'known gap in `diff --name-only` and is named so a later slice '
            'does not discover it as a surprise',
      );
    });

    test(
      'a DELETED path is enumerated, so a path leaving OWNED_PATHS is seen',
      () async {
        final start = git.head;
        File('${git.root.path}/lib/calculator.dart').deleteSync();
        final produced = git.commitAll('delete');

        final result = await collect(start, produced);

        expect(result.paths, ['lib/calculator.dart']);
      },
    );
  });
}
