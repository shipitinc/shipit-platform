import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// Outcome of asking [ArtifactCommitter] to make a worktree's produced artifact
/// durable on a branch.
///
/// Deliberately a small result type rather than an exception: a commit failure
/// must NOT crash the execution (the run may have succeeded), but it must be
/// visible. The caller keeps the inspected revision when nothing was committed
/// and surfaces [failureDetail] as an event when a commit was attempted and
/// failed.
@immutable
class ArtifactCommitOutcome {
  const ArtifactCommitOutcome._({
    required this.artifactPresent,
    this.revision,
    this.failureDetail,
  });

  /// No change was produced: the worktree is clean and its HEAD still equals
  /// the starting revision. The caller must keep the inspected revision and
  /// must NOT create an empty branch or commit.
  const ArtifactCommitOutcome.none() : this._(artifactPresent: false);

  /// A produced artifact was committed; [revision] is the produced commit SHA.
  ArtifactCommitOutcome.committed(String revision)
    : this._(artifactPresent: true, revision: revision);

  /// An artifact was produced but could not be committed. [failureDetail] is
  /// always surfaced by the caller; it is never swallowed.
  ArtifactCommitOutcome.failed(String failureDetail)
    : this._(artifactPresent: true, failureDetail: failureDetail);

  /// True when the worktree contained a produced artifact (a dirty tree or a
  /// HEAD ahead of the starting revision).
  final bool artifactPresent;

  /// The produced commit SHA, when [artifactPresent] and the commit succeeded.
  final String? revision;

  /// Non-null when an artifact was present but the commit could not be made.
  final String? failureDetail;

  bool get failed => failureDetail != null;
}

/// Thrown internally when a git command cannot be run to completion. Never
/// escapes [ArtifactCommitter.commit]; it is translated into
/// [ArtifactCommitOutcome.failed] so a commit failure cannot abort the run.
class ArtifactCommitException implements Exception {
  const ArtifactCommitException(this.args, this.exitCode, this.stderr);

  final List<String> args;
  final int exitCode;
  final Object stderr;

  @override
  String toString() =>
      'git ${args.join(' ')} exited $exitCode: ${stderr.toString().trim()}';
}

/// Makes a worktree's produced artifact durable.
///
/// The platform's evidence of an implementation is a git commit, not a dirty
/// worktree: a detached worktree is removed on completion and its uncommitted
/// edits die with it. [commit] therefore commits the worktree onto a named
/// branch in the execution's repository so the produced revision is reachable
/// and durable after cleanup — the revision a downstream reviewer must
/// inspect.
///
/// Mirrors [GitWorktreeWorkspaceManager]'s git discipline: every command runs
/// with a hard timeout through [Process.run], and failures are reported rather
/// than thrown at the caller. The commit is authored as the PLATFORM, not the
/// agent: a fixed identity is supplied with `-c user.name` / `-c user.email` so
/// the artifact commit is deterministic and does not depend on ambient git
/// configuration (which is absent in CI and must not silently block a commit).
class ArtifactCommitter {
  const ArtifactCommitter({
    this.git = 'git',
    this.timeout = const Duration(seconds: 60),
    this.authorName = 'shipit-platform',
    this.authorEmail = 'shipit-platform@localhost',
  });

  final String git;
  final Duration timeout;
  final String authorName;
  final String authorEmail;

  /// Commits the worktree at [worktreePath] onto `<branchPrefix>/<workItemId>`
  /// and returns the produced commit SHA.
  ///
  /// Artifact present iff `git status --porcelain` is non-empty OR `HEAD`
  /// differs from [startingRevision]. When neither holds, returns
  /// [ArtifactCommitOutcome.none] and touches nothing.
  Future<ArtifactCommitOutcome> commit({
    required String worktreePath,
    required String workItemId,
    required String startingRevision,
    required String message,
    String branchPrefix = 'shipit/impl',
  }) async {
    try {
      final status = await _capture([
        '-C',
        worktreePath,
        'status',
        '--porcelain',
      ]);
      final head = (await _capture([
        '-C',
        worktreePath,
        'rev-parse',
        'HEAD',
      ])).trim();
      final dirty = status.trim().isNotEmpty;
      final moved = head != startingRevision.trim();
      if (!dirty && !moved) {
        return const ArtifactCommitOutcome.none();
      }

      final branch = '$branchPrefix/$workItemId';
      // `checkout -B` lands the branch at HEAD without discarding the worktree's
      // local modifications, which then get staged and committed below.
      await _capture(['-C', worktreePath, 'checkout', '-B', branch]);
      await _capture(['-C', worktreePath, 'add', '-A']);

      // Re-read the tree AFTER staging. If the change was already committed by
      // the agent (HEAD moved, tree clean) there is nothing to commit and the
      // agent's own commit is the produced revision.
      final staged = await _capture([
        '-C',
        worktreePath,
        'status',
        '--porcelain',
      ]);
      if (staged.trim().isNotEmpty) {
        await _capture(['-C', worktreePath, 'commit', '-m', message]);
      }

      final revision = (await _capture([
        '-C',
        worktreePath,
        'rev-parse',
        'HEAD',
      ])).trim();
      if (revision.isEmpty) {
        return ArtifactCommitOutcome.failed(
          'rev-parse HEAD returned an empty revision after commit',
        );
      }
      return ArtifactCommitOutcome.committed(revision);
    } on Object catch (e) {
      return ArtifactCommitOutcome.failed(e.toString());
    }
  }

  Future<String> _capture(List<String> args) async {
    final fullArgs = [
      '-c',
      'user.name=$authorName',
      '-c',
      'user.email=$authorEmail',
      // Deterministic commits must not depend on ambient signing configuration.
      '-c',
      'commit.gpgsign=false',
      ...args,
    ];
    final result =
        await Process.run(
          git,
          fullArgs,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        ).timeout(
          timeout,
          onTimeout: () => throw ArtifactCommitException(
            args,
            -1,
            'git command exceeded $timeout',
          ),
        );
    if (result.exitCode != 0) {
      throw ArtifactCommitException(args, result.exitCode, result.stderr);
    }
    return result.stdout as String;
  }
}
