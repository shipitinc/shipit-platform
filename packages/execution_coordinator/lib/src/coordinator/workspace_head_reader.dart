import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

/// Reads `HEAD` from a workspace unconditionally and says whether it moved.
///
/// ## WHY THE RE-READ IS UNCONDITIONAL
///
/// `GitWorkspaceDeltaProbe` short-circuits on a dirty tree and **never reads
/// `HEAD`** (`workspace_delta_probe.dart:199-217`), returning
/// `WorkspaceDelta.changed` with `headRevision: null, headMoved: null` (`:210-216`).
/// That is a sound optimisation for a probe whose subject is "did anything
/// change at all", because a dirty tree is already proof of production.
///
/// It is the wrong shape for anything whose subject is "does a commit exist at
/// a recorded revision". An implementation that commits its work **and** leaves
/// any untracked file — which is most runs — has a clean `git status` result on
/// the *second* read but a dirty one on the first, so the probe declines to
/// look and reports `headMoved: null`. A gate built on that answer treats "I
/// did not look" as "nothing was produced" and permanently fails a correctly
/// committing run.
///
/// So this reader always looks. It does not consult the worktree's cleanliness,
/// does not cache, and does not short-circuit on anything.
///
/// ## THREE-VALUED, AND WHY A THROWING READER CANNOT BE USED INSTEAD
///
/// `GitWorkspaceInspector` reads `git rev-parse HEAD` unconditionally too, but
/// it **throws** `GitCommandException` on failure (`git_workspace_inspector.dart:106-115`)
/// and returns a `revision` that is a non-nullable `String` (`:14`) which cannot
/// express "unreadable". Callers are pushed into a `try`, and a caller who omits
/// it either crashes the settle path or substitutes a value of its own.
///
/// This reader returns `null` for exactly one condition — *could not establish*
/// — and never returns a `WorkspaceHead` it could not fill in. See
/// [WorkspaceHead] for why that has to be three facts and not two.
class WorkspaceHeadReader {
  const WorkspaceHeadReader({
    this.git = 'git',
    this.timeout = const Duration(seconds: 30),
  });

  final String git;
  final Duration timeout;

  /// Runs `git rev-parse HEAD` in [workingDirectory] and compares the answer to
  /// [startingRevision].
  ///
  /// Returns `null` when `HEAD` could not be established — no git, not a
  /// worktree, an unborn repository, a timeout. A `null` here means **"I could
  /// not look"**, which is not the claim "nothing was produced", and a caller
  /// that treats it as one is the defect this reader exists to prevent.
  Future<WorkspaceHead?> read({
    required String workingDirectory,
    required String? startingRevision,
  }) async {
    final baseline = startingRevision?.trim();
    final head = await _capture([
      '-C',
      workingDirectory,
      '--no-optional-locks',
      'rev-parse',
      'HEAD',
    ]);
    if (head == null || head.trim().isEmpty) return null;

    final headRevision = head.trim();

    // Three-valued. With no baseline there is nothing to compare against, so
    // the honest answer is "not established" (null) rather than false — the
    // same distinction `WorkspaceDelta.headMoved` draws, and for the same
    // reason: reporting "HEAD did not move" for a commit nobody looked for is
    // the same laundering as reporting a clean tree for a tree nobody read.
    // A caller gating on `headMoved == true` is unaffected either way, because
    // null is not true.
    final bool? headMoved = (baseline == null || baseline.isEmpty)
        ? null
        : headRevision != baseline;

    return WorkspaceHead(
      startingRevision: baseline,
      headRevision: headRevision,
      headMoved: headMoved,
    );
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
      // A missing `git`, an unspawnable path, a timeout, a wedged filesystem.
      // Folded into one value rather than propagated: this reader answers a
      // question, and "could not answer" is an answer it is specified to give.
      return null;
    }
  }
}
