import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// `HEAD` read unconditionally from a workspace, and whether it moved.
///
/// ## WHY THIS EXISTS RATHER THAN A `String`
///
/// `GitWorkspaceInspection.revision` (`git_workspace_inspector.dart:14`) is a
/// `String`, and its reader **throws** `GitCommandException` when git fails
/// (`:106-115`). Neither shape can express the three facts a gate has to
/// distinguish:
///
/// 1. `HEAD` is at a new revision — the run committed;
/// 2. `HEAD` is where it started — the run committed nothing;
/// 3. `HEAD` could not be read — *I could not look*, which is not the same
///    claim as (2) and must never be reported as it.
///
/// A `String?` collapses (2) and (3) into one value; a throwing reader cannot
/// return (1) or (2) at all without a `try`. [headMoved] is three-valued for
/// the same reason `WorkspaceDelta.headMoved` is (`workspace_delta_probe.dart:87-96`):
/// "not established" and "established as no" are different claims.
@immutable
class WorkspaceHead extends Equatable {
  const WorkspaceHead({
    required this.startingRevision,
    required this.headRevision,
    required this.headMoved,
  });

  /// The revision the execution started from. Null when the execution request
  /// recorded no baseline, which is why [headMoved] is nullable too.
  final String? startingRevision;

  /// `HEAD` as git reported it. Non-nullable and non-empty: the reader returns
  /// null rather than a `WorkspaceHead` it could not fill in.
  final String headRevision;

  /// Whether `HEAD` differs from [startingRevision].
  ///
  /// `true` when it does, `false` when it was read and did not, and `null`
  /// when there was no baseline to compare against — "not established", never
  /// "established as no".
  final bool? headMoved;

  @override
  List<Object?> get props => [startingRevision, headRevision, headMoved];
}
