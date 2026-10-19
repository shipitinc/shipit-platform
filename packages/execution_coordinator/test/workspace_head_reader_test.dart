import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/git_fixture.dart';

/// The unconditional `HEAD` re-read, and the three facts it has to keep apart.
///
/// ## THE HOLE THIS CLOSES, AND WHY IT NEEDS ITS OWN TEST
///
/// `GitWorkspaceDeltaProbe` **short-circuits on a dirty tree and never reads
/// `HEAD`** (`workspace_delta_probe.dart:199-217`), returning `headRevision:
/// null, headMoved: null` (`:210-216`). That is sound for a probe — a dirty tree
/// already proves production — and wrong for anything whose subject is "does a
/// commit exist at a recorded revision".
///
/// The run that exposes it is the best-behaved run in the repository: an
/// implementation that **commits its work and leaves one untracked file**. The
/// tree was dirty when the probe first looked, so the probe declined to read
/// `HEAD` and reported "not established". A gate built on that answer reads
/// "nothing was produced" and permanently fails a correct run.
///
/// [WorkspaceHeadReader] therefore reads `HEAD` unconditionally, and the tests
/// below pin the case the probe cannot answer.
void main() {
  const reader = WorkspaceHeadReader();

  late Directory temp;
  late GitWorkspaceFixture git;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('workspace_head_');
    git = GitWorkspaceFixture.create(temp.path);
  });

  tearDown(() {
    git.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<WorkspaceHead?> read({String? startingRevision}) => reader.read(
    workingDirectory: git.root.path,
    startingRevision: startingRevision ?? git.startingRevision,
  );

  group('HEAD IS READ UNCONDITIONALLY', () {
    test('HEAD unmoved and tree clean reports headMoved: false', () async {
      final head = await read();

      expect(head, isNotNull);
      expect(head!.headRevision, git.startingRevision);
      expect(head.headMoved, isFalse, reason: 'established as no, not null');
    });

    test('HEAD moved by a commit reports headMoved: true', () async {
      git.writeFile('lib/new.dart', 'int answer() => 42;\n');
      final produced = git.commitAll('implement');

      final head = await read();

      expect(head!.headRevision, produced);
      expect(head.headMoved, isTrue);
      expect(head.startingRevision, git.startingRevision);
    });

    test('THE CASE THE PROBE CANNOT ANSWER: a committed run that left an '
        'untracked file still reports headMoved: true', () async {
      git.writeFile('lib/new.dart', 'int answer() => 42;\n');
      final produced = git.commitAll('implement');
      git.createUntrackedFile('scratch/notes.md', '# notes\n');

      // Premise, asserted rather than assumed: the worktree really is dirty,
      // which is precisely the state that makes the delta probe decline to
      // read HEAD.
      expect(git.porcelainLines, contains('?? scratch/'));
      final delta = const GitWorkspaceDeltaProbe().probe(
        workingDirectory: git.root.path,
        startingRevision: git.startingRevision,
      );

      final head = await read();

      expect(head!.headRevision, produced);
      expect(
        head.headMoved,
        isTrue,
        reason:
            'the run DID commit. Falsifying this row permanently fails a '
            'correctly-committing implementation, which is how a gate '
            'becomes one whose operators learn to waive it',
      );

      // The two readers disagree on the same worktree in the same instant —
      // which is the point: the delta probe's answer is not wrong, it just
      // cannot be this question's answer.
      final deltaValue = await delta;
      expect(deltaValue.headMoved, isNull, reason: 'the probe short-circuits');
      expect(deltaValue.isReadable, isTrue);
    });

    test(
      'a dirty tree with NO commit reports headMoved: false, not true',
      () async {
        git.writeFile('lib/new.dart', 'int answer() => 42;\n');

        final head = await read();

        expect(
          head!.headMoved,
          isFalse,
          reason:
              'uncommitted work is not a commit. The gate that consumes this '
              'needs "established as no" to be distinguishable from "not '
              'established", which is why the field is three-valued',
        );
      },
    );
  });

  group('"COULD NOT ESTABLISH" IS NULL, AND IS NEVER "HEAD DID NOT MOVE"', () {
    test('a directory that is not a git repository returns null', () async {
      final plain = Directory('${temp.path}/plain')..createSync();
      File('${plain.path}/loose.txt').writeAsStringSync('x\n');

      final head = await reader.read(
        workingDirectory: plain.path,
        startingRevision: 'abc',
      );

      expect(
        head,
        isNull,
        reason:
            '"I could not look" must not be laundered into "I looked and saw '
            'nothing" — a gate that collapses them reports a tooling fault as '
            'an agent that did nothing, and settles it as a permanent failure',
      );
    });

    test('a missing git binary returns null', () async {
      final broken = WorkspaceHeadReader(
        git: '${temp.path}/definitely-not-git',
      );

      final head = await broken.read(
        workingDirectory: git.root.path,
        startingRevision: git.startingRevision,
      );

      expect(head, isNull);
    });

    test(
      'an unborn repository — commits exist, HEAD does not — returns null',
      () async {
        final unborn = GitWorkspaceFixture.create('${temp.path}/unborn_base');
        final empty = Directory('${temp.path}/unborn')
          ..createSync(recursive: true);
        Process.runSync('git', ['init', '--quiet', empty.path]);

        final head = await reader.read(
          workingDirectory: empty.path,
          startingRevision: 'abc',
        );

        expect(head, isNull);
        expect(unborn.root.path, isNotEmpty);
      },
    );

    test('a no-baseline read cannot establish movement and says so', () async {
      // `headMoved` is nullable, and this is the case that earns the null:
      // with nothing to compare against, "did HEAD move" is unanswerable, and
      // answering `false` would be reporting "established as no" for a
      // question that was never asked.
      final head = await reader.read(
        workingDirectory: git.root.path,
        startingRevision: null,
      );

      expect(head, isNotNull);
      expect(head!.headRevision, git.startingRevision);
      expect(head.headMoved, isNull, reason: 'not established');
      expect(head.startingRevision, isNull);
    });

    test('a whitespace-only baseline is treated as no baseline', () async {
      final head = await reader.read(
        workingDirectory: git.root.path,
        startingRevision: '   ',
      );

      expect(head!.headMoved, isNull);
    });
  });

  group('READ-ONLY', () {
    test('the read takes no lock and leaves the worktree untouched', () async {
      final before = git.porcelainLines;
      final beforeHead = git.head;

      await read();

      expect(git.head, beforeHead);
      expect(git.porcelainLines, before);
    });
  });
}
