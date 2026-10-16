import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// The platform's own, git-observed account of what an execution left behind in
/// its workspace.
///
/// Deliberately three-valued. "Nothing was produced" and "I could not look" are
/// very different facts and collapsing them would let a tooling fault be
/// reported to an operator as an agent that did nothing — and would then be
/// settled as the permanent failure this whole rule exists to produce.
@immutable
class WorkspaceDelta {
  /// The worktree is clean and `HEAD` still equals the revision the execution
  /// started from. This is the only value that means "produced nothing".
  const WorkspaceDelta.unchanged({
    required this.startingRevision,
    required this.headRevision,
  }) : isReadable = true,
       changedPaths = const [],
       unreadableReason = null;

  /// The worktree carries changes relative to [startingRevision].
  const WorkspaceDelta.changed({
    required this.startingRevision,
    required this.headRevision,
    required this.changedPaths,
  }) : isReadable = true,
       unreadableReason = null;

  /// The delta could not be established — no baseline revision, no git, a path
  /// that is not a worktree, or a command that failed.
  const WorkspaceDelta.unreadable(String this.unreadableReason)
    : isReadable = false,
      startingRevision = null,
      headRevision = null,
      changedPaths = const <String>[];

  /// Whether the probe produced a usable answer at all.
  final bool isReadable;

  /// The revision the execution started from, when known.
  final String? startingRevision;

  /// `HEAD` at settle time, when known.
  final String? headRevision;

  /// Paths carrying a change, from `git status --porcelain`. May be a prefix of
  /// the full set; it exists to make a failure reason name something concrete.
  final List<String> changedPaths;

  /// Why the probe could not answer, when [isReadable] is false.
  final String? unreadableReason;

  /// Whether the workspace shows any change at all.
  ///
  /// Only meaningful when [isReadable]; an unreadable delta never reports true,
  /// because "I could not look" must not be laundered into "I looked and saw
  /// nothing".
  bool get hasChanges => isReadable && changedPaths.isNotEmpty;
}

/// Establishes whether an execution changed anything in its workspace.
abstract class WorkspaceDeltaProbe {
  Future<WorkspaceDelta> probe({
    required String workingDirectory,
    required String? startingRevision,
  });
}

/// Reads the delta with git, read-only.
///
/// ## WHY THIS PREDICATE AND NOT `git diff --name-status`
///
/// `GitWorkspaceInspector` (worker_runtime) enumerates changes with
/// `git diff --name-status <rev>`, which does NOT list untracked files. Copying
/// it would be a trap: an implementer that creates a brand-new file and leaves
/// it untracked reports a clean diff, and this rule would then permanently fail
/// a run that produced a real artifact.
///
/// What decides whether an implementation counts as produced is
/// `ArtifactCommitter.commit` (worker_runtime), and it asks a different
/// question:
///
/// ```text
/// git status --porcelain        -> non-empty   (dirty: INCLUDES untracked)
/// git rev-parse HEAD            -> != startingRevision  (moved: agent committed)
///
/// if (!dirty && !moved) -> ArtifactCommitOutcome.none()   // nothing to commit
/// ```
///
/// That flag becomes the worker execution's `endingRevision`, and
/// `producedCommitFor` (`packages/scheduler/lib/src/implementation_inflow.dart`)
/// then reports `CommitProduced` exactly when `endingRevision != requestedStartingRevision`.
///
/// So this probe asks the committer's question, one step earlier in the same
/// worktree — before the commit exists — which makes the answer identical rather
/// than merely similar. Mirroring the inspector instead would have made the two
/// components disagree about the same run, which is the failure mode
/// `producedCommitFor`'s own doc warns about when it refuses an ambiguous
/// producer.
class GitWorkspaceDeltaProbe implements WorkspaceDeltaProbe {
  const GitWorkspaceDeltaProbe({
    this.git = 'git',
    this.timeout = const Duration(seconds: 30),
    this.reportedPathCap = 5,
  });

  final String git;
  final Duration timeout;

  /// How many paths a failure reason may name before it stops being a sentence.
  final int reportedPathCap;

  @override
  Future<WorkspaceDelta> probe({
    required String workingDirectory,
    required String? startingRevision,
  }) async {
    final baseline = startingRevision?.trim();
    if (baseline == null || baseline.isEmpty) {
      // No baseline means nothing to compare against. `ArtifactCommitter` takes
      // its starting revision as a required argument for the same reason, so
      // this is not a shape production runs in — it is an honest "cannot tell".
      return const WorkspaceDelta.unreadable(
        'the execution request recorded no starting revision, so there is no '
        'baseline to compare the workspace against',
      );
    }

    final status = await _capture([
      '-C',
      workingDirectory,
      '--no-optional-locks',
      'status',
      '--porcelain',
    ]);
    if (status == null) {
      return const WorkspaceDelta.unreadable(
        'the workspace could not be inspected with git, so whether the run '
        'produced anything is unknown',
      );
    }

    final paths = _porcelainPaths(status);
    if (paths.isNotEmpty) {
      // A dirty tree is already proof of production, so `HEAD` is not needed.
      // Short-circuiting here also halves the subprocesses this probe spends,
      // which matters because it runs on the completion path of every
      // implementation execution — and one subprocess per spawn is load a
      // wall-clock-sensitive suite elsewhere has to run under.
      //
      // `HEAD` is deliberately not read even when the repository is unborn: a
      // tree with changes against no commit is still changes, and reading it
      // could only ever turn this branch into `unreadable`.
      return WorkspaceDelta.changed(
        startingRevision: baseline,
        headRevision: null,
        changedPaths: paths.length > reportedPathCap
            ? paths.take(reportedPathCap).toList()
            : paths,
      );
    }

    final head = await _capture([
      '-C',
      workingDirectory,
      '--no-optional-locks',
      'rev-parse',
      'HEAD',
    ]);
    if (head == null || head.trim().isEmpty) {
      return const WorkspaceDelta.unreadable(
        'the workspace has no resolvable HEAD, so whether the run produced '
        'anything is unknown',
      );
    }

    final headRevision = head.trim();
    return WorkspaceDelta.unchanged(
      startingRevision: baseline,
      headRevision: headRevision,
    );
  }

  /// Extracts the path from each `git status --porcelain` line.
  ///
  /// Renames read `R  old -> new`, so the arrow form is split on the separator
  /// and the destination kept: it is the path that exists in the worktree now.
  static List<String> _porcelainPaths(String porcelain) {
    final paths = <String>[];
    for (final line in porcelain.split('\n')) {
      if (line.trim().isEmpty) continue;
      final path = line.length <= 3 ? line.trim() : line.substring(3).trim();
      if (path.isEmpty) continue;
      final arrow = path.indexOf(' -> ');
      paths.add(arrow == -1 ? path : path.substring(arrow + 4));
    }
    return paths;
  }

  Future<String?> _capture(List<String> args) async {
    try {
      final result = await Process.run(
        git,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      if (result.exitCode != 0) return null;
      return result.stdout as String;
    } on Object {
      // A missing `git`, a wedged filesystem, a timeout. Never propagated: this
      // probe answers a question, and "could not answer" is an answer.
      return null;
    }
  }
}
