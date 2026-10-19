import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

/// Which of the collector's two enumerations failed.
enum CommittedDiffEnumeration {
  /// `git diff --name-only <startingRevision>..<producedRevision>`.
  committedRange,

  /// `git ls-files --others --exclude-standard`.
  untrackedWorktree,
}

/// A committed-range path enumeration could not be read.
///
/// ## WHY THIS THROWS RATHER THAN RETURNING A SHORTER LIST
///
/// `WorkspaceDelta` records an unreadable read as a *value*
/// (`WorkspaceDelta.unreadable`), which is right for it: the caller compares
/// `isReadable` and stops. This collector's contract is the opposite — §3.0
/// rule 4 of the design that specifies it, and the reason the reader exists at
/// all, is that a failed enumeration must be a FAIL and never an empty list.
///
/// Throwing is what makes that structural. There is no `CommittedDiffPaths` to
/// carry an empty path list produced by a failure, so the vacuous-pass shape —
/// a gate that enumerates nothing, reads "nothing is out of bounds", and passes
/// — cannot be constructed at all rather than merely being discouraged.
///
/// [enumeration] names which of the two failed, because "either enumeration
/// failing is a FAIL" is a claim about both and a test has to be able to target
/// each one.
class CommittedDiffPathCollectionException implements Exception {
  const CommittedDiffPathCollectionException({
    required this.enumeration,
    required this.workingDirectory,
    required this.reason,
    this.args = const [],
    this.exitCode,
    this.stderr = '',
  });

  final CommittedDiffEnumeration enumeration;
  final String workingDirectory;

  /// Why the enumeration could not be read, in terms an operator can act on.
  final String reason;

  /// The git arguments that failed, verbatim.
  final List<String> args;

  /// git's exit code, when it ran and exited non-zero; null when it could not
  /// be run at all (missing binary, timeout, unspawnable).
  final int? exitCode;

  /// git's stderr, when it produced any.
  final String stderr;

  @override
  String toString() {
    final what = switch (enumeration) {
      CommittedDiffEnumeration.committedRange => 'the committed range',
      CommittedDiffEnumeration.untrackedWorktree =>
        'the untracked worktree files',
    };
    final detail = args.isEmpty ? '' : ' [git ${args.join(' ')}]';
    final code = exitCode == null ? '' : ' (git exited $exitCode)';
    return 'could not enumerate $what in $workingDirectory$detail$code: '
        '$reason';
  }
}

/// Enumerates every path an execution's committed change touched, **uncapped**.
///
/// ## WHY A NEW READER AND NOT AN EXISTING ONE
///
/// Three readers in this repository can answer a question close to this one.
/// Each is verified here inadequate **for a confinement gate specifically** —
/// a defect that matters for a delta probe (a spurious failure) is the opposite
/// defect for a gate (a silent pass), so "it mostly works" is not the bar.
///
/// | Reader | Why it cannot be this gate's reader |
/// |---|---|
/// | `WorkspaceDelta.changedPaths` | **Truncated to 5.** `GitWorkspaceDeltaProbe` takes `paths.take(reportedPathCap)` (`workspace_delta_probe.dart:160`, `:213-214`) and the field is documented as *"May be a prefix of the full set"* (`:98-99`). A prefix has no bound: the sixth path is unexamined. The cap exists to keep a failure *reason* a sentence; a gate must judge every path. |
/// | `WorkspaceDelta.changedPaths` on a committed run | **`const []`.** `WorkspaceDelta.committed` hard-codes it (`workspace_delta_probe.dart:61-67`). On **exactly the runs the provenance gate passes** — committed, tree clean, `HEAD` moved — the confinement gate would enumerate nothing and pass vacuously. |
/// | `GitWorkspaceInspector.changedFiles` | Genuinely uncapped and it does read `HEAD`, but it enumerates `git diff --name-status <start>` (`git_workspace_inspector.dart:57-64`) — **start-to-worktree, not `<start>..<produced>`** — and **`git diff` never lists untracked files**. For a probe that is a spurious failure; for a confinement gate a brand-new prohibited file is invisible and the gate passes. |
///
/// ## WHY TWO ENUMERATIONS
///
/// `git diff --name-only <start>..<produced>` is the assertion's actual subject:
/// the committed range. `git ls-files --others --exclude-standard` adds
/// everything still untracked at settle time, which `git diff` will never report
/// — and an untracked **new** file is precisely what a confinement gate must
/// catch.
///
/// The second enumeration is **over-inclusive by design**: it reports every
/// untracked file in the worktree, not only the ones this run created, so a
/// workspace arriving with pre-existing untracked files produces a FAIL on
/// paths this run never touched. That is accepted deliberately, because the
/// opposite error lets a prohibited new file through unseen. It is stated here
/// so it is not later "fixed" as a bug.
///
/// ## READ-ONLY
///
/// Every command is a read: `diff` and `ls-files` write nothing. `--no-optional-locks`
/// keeps a read from taking the index lock, matching `GitWorkspaceDeltaProbe`.
class CommittedDiffPathCollector {
  const CommittedDiffPathCollector({
    this.git = 'git',
    this.timeout = const Duration(seconds: 30),
  });

  final String git;
  final Duration timeout;

  /// Reads both enumerations and returns their union.
  ///
  /// Throws [CommittedDiffPathCollectionException] if **either** fails. Never
  /// returns a short list in place of a failed read, and never caps.
  Future<CommittedDiffPaths> collect({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async {
    final start = startingRevision.trim();
    final produced = producedRevision.trim();
    if (start.isEmpty) {
      throw CommittedDiffPathCollectionException(
        enumeration: CommittedDiffEnumeration.committedRange,
        workingDirectory: workingDirectory,
        reason:
            'no starting revision was supplied, so there is no range to '
            'enumerate',
      );
    }
    if (produced.isEmpty) {
      throw CommittedDiffPathCollectionException(
        enumeration: CommittedDiffEnumeration.committedRange,
        workingDirectory: workingDirectory,
        reason:
            'no produced revision was supplied, so there is no range to '
            'enumerate',
      );
    }

    final rangeArgs = <String>[
      '-C',
      workingDirectory,
      '--no-optional-locks',
      'diff',
      '--name-only',
      '$start..$produced',
    ];
    final committed = await _capture(
      CommittedDiffEnumeration.committedRange,
      workingDirectory,
      rangeArgs,
    );

    final untrackedArgs = <String>[
      '-C',
      workingDirectory,
      '--no-optional-locks',
      'ls-files',
      '--others',
      '--exclude-standard',
    ];
    final untracked = await _capture(
      CommittedDiffEnumeration.untrackedWorktree,
      workingDirectory,
      untrackedArgs,
    );

    return CommittedDiffPaths(
      startingRevision: start,
      producedRevision: produced,
      paths: <String>[...committed, ...untracked],
    );
  }

  /// Runs one enumeration, or throws naming which one failed.
  ///
  /// Fail-fast by design: the first failure already means the collector cannot
  /// answer, and spending the second subprocess would buy nothing a caller can
  /// act on. Every failure mode is folded into the same exception — a non-zero
  /// exit, an unspawnable binary, a timeout — because the caller must not be
  /// able to tell them apart by accident and treat one as "no paths".
  Future<List<String>> _capture(
    CommittedDiffEnumeration enumeration,
    String workingDirectory,
    List<String> args,
  ) async {
    try {
      final result = await Process.run(
        git,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      if (result.exitCode != 0) {
        throw CommittedDiffPathCollectionException(
          enumeration: enumeration,
          workingDirectory: workingDirectory,
          args: args,
          exitCode: result.exitCode,
          stderr: '${result.stderr}'.trim(),
          reason: 'git exited ${result.exitCode}',
        );
      }
      return _lines('${result.stdout}');
    } on CommittedDiffPathCollectionException {
      rethrow;
    } on Object catch (e) {
      // A missing `git`, an unspawnable path, a timeout. Never returned as an
      // empty list: "could not look" and "looked and saw nothing" are different
      // claims, and only one of them may be represented by an empty list.
      throw CommittedDiffPathCollectionException(
        enumeration: enumeration,
        workingDirectory: workingDirectory,
        args: args,
        reason: 'git could not be run: $e',
      );
    }
  }

  static List<String> _lines(String stdout) => stdout
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}
