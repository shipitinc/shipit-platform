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
  ///
  /// Both halves are decided here, so the name carries exactly one meaning:
  /// [headMoved] is false by construction, and a caller cannot construct a value
  /// that claims "unchanged" while also claiming HEAD moved.
  const WorkspaceDelta.unchanged({
    required this.startingRevision,
    required this.headRevision,
  }) : isReadable = true,
       headMoved = false,
       changedPaths = const [],
       unreadableReason = null;

  /// The worktree carries changes relative to [startingRevision].
  ///
  /// [headRevision] is null and [headMoved] is null when the probe answered from
  /// the worktree alone without reading `HEAD` — see [GitWorkspaceDeltaProbe]
  /// for why it short-circuits. A dirty tree is already proof of production, so
  /// the missing facts are never load-bearing; they are null rather than false
  /// because "not established" and "established as no" are different claims.
  const WorkspaceDelta.changed({
    required this.startingRevision,
    required this.headRevision,
    required this.changedPaths,
    this.headMoved,
  }) : isReadable = true,
       unreadableReason = null;

  /// The worktree is clean but `HEAD` is no longer [startingRevision]: the
  /// execution committed its own work.
  ///
  /// ## WHY THIS IS A SEPARATE VALUE AND NOT A `changed` WITH A FAKE PATH
  ///
  /// `changedPaths` is documented as paths from `git status --porcelain`, and it
  /// is read by the failure reason, which reports `changedPaths.length` as
  /// `changedFileCount`. Putting a synthetic entry in it to make
  /// `hasChanges` come out true would make the type lie about where a fact came
  /// from, and would report a file count for a run whose files git listed none
  /// of. So the moved case says what it is instead.
  ///
  /// This is `ArtifactCommitter`'s `moved` half. An implementer that commits
  /// its own work has produced the artifact, and that component's own comment
  /// says so: "If the change was already committed by the agent (HEAD moved,
  /// tree clean) there is nothing to commit and the agent's own commit is the
  /// produced revision."
  const WorkspaceDelta.committed({
    required this.startingRevision,
    required this.headRevision,
  }) : isReadable = true,
       headMoved = true,
       changedPaths = const [],
       unreadableReason = null;

  /// The delta could not be established — no baseline revision, no git, a path
  /// that is not a worktree, or a command that failed.
  const WorkspaceDelta.unreadable(String this.unreadableReason)
    : isReadable = false,
      startingRevision = null,
      headRevision = null,
      headMoved = null,
      changedPaths = const <String>[];

  /// Whether the probe produced a usable answer at all.
  final bool isReadable;

  /// The revision the execution started from, when known.
  final String? startingRevision;

  /// `HEAD` at settle time, when known.
  final String? headRevision;

  /// Whether `HEAD` differs from [startingRevision].
  ///
  /// `true` when it does, `false` when it was read and did not, and `null` when
  /// it was never read — the probe stops at a dirty tree, and an unreadable
  /// delta read nothing either.
  ///
  /// Three-valued for the reason [isReadable] is: reporting "HEAD did not move"
  /// for a commit nobody made is the same laundering as reporting a clean tree
  /// for a tree nobody looked at.
  final bool? headMoved;

  /// Paths carrying a change, from `git status --porcelain`. May be a prefix of
  /// the full set; it exists to make a failure reason name something concrete.
  final List<String> changedPaths;

  /// Why the probe could not answer, when [isReadable] is false.
  final String? unreadableReason;

  /// Whether the workspace shows any change at all.
  ///
  /// This is the committer's predicate, verbatim: `dirty || moved`. Only
  /// meaningful when [isReadable]; an unreadable delta never reports true,
  /// because "I could not look" must not be laundered into "I looked and saw
  /// nothing". [headMoved] is tested as "known to have moved" rather than as a
  /// boolean, so a null cannot be read as a false that would turn a dirty tree
  /// into a failure.
  bool get hasChanges =>
      isReadable && (changedPaths.isNotEmpty || (headMoved ?? false));
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

    // A clean tree is NOT "produced nothing" — it is only that when `HEAD` is
    // still where the execution started. This comparison is the whole of the
    // committer's `moved` half, and omitting it is not a subtle narrowing: an
    // implementer that commits its own work leaves a clean tree, so a probe that
    // stops here scores a run that produced a real commit as having produced
    // nothing, and this rule turns that into a PERMANENT failure handed to a
    // human. `ArtifactCommitter`, asked about this same worktree in this same
    // instant, answers "committed" — and a reviewer would then be dispatched to
    // check an artifact this rule had just declared absent.
    if (headRevision != baseline) {
      return WorkspaceDelta.committed(
        startingRevision: baseline,
        headRevision: headRevision,
      );
    }

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
