import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Every path an execution's committed range touched, plus everything still
/// untracked in the workspace when the reader settled.
///
/// ## WHY THIS IS A VALUE TYPE AND NOT A NULLABLE FIELD
///
/// `paths` is **never an empty list standing for "I could not look"**. The
/// defect that makes this type necessary is a reader that reports a failed
/// enumeration as an empty set — which on exactly the runs a change was
/// committed is indistinguishable from a change that touched nothing, so a
/// confinement gate reads "no paths out of bounds" and passes vacuously.
///
/// The empty set is therefore only ever constructible from a successful read
/// that git answered with nothing. A failed read throws
/// `CommittedDiffPathCollectionException` instead of producing a value, so
/// "no paths" and "could not enumerate paths" cannot share a representation.
/// See `packages/execution_coordinator/lib/src/coordinator/committed_diff_path_collector.dart`,
/// which is the only thing that constructs this in production.
///
/// ## THE ORDERING IS A TOTAL ORDER, ENFORCED HERE
///
/// [paths] is sorted and de-duplicated by the constructor, so the invariant
/// holds for every construction path — git, a test fixture, or an in-memory
/// store — rather than depending on which enumerator produced which element.
///
/// That is deliberate. The ordering must be a **total order**: `String.compareTo`
/// compares UTF-16 code units and always returns an `int`, so it is transitive,
/// antisymmetric and total, and two distinct paths never compare equal. No
/// element can be "incomparable" with another, which is what a comparator keyed
/// on a nullable field (a timestamp, an id that may be absent in an in-memory
/// store) fails to guarantee. A comparator that is total against a database and
/// not total against an in-memory store is a defect, and enforcing the sort at
/// construction makes that defect unrepresentable rather than merely avoided.
///
/// It also makes the result independent of the order git happened to emit.
/// `git diff --name-only` walks the tree and `git ls-files --others` walks the
/// working directory; both are deterministic for a given state, but neither is
/// an ordering two different stores would agree on.
@immutable
class CommittedDiffPaths extends Equatable {
  /// Sorts and de-duplicates [paths]; see the class doc for why the ordering
  /// is established here rather than by the caller.
  CommittedDiffPaths({
    required this.startingRevision,
    required this.producedRevision,
    required List<String> paths,
  }) : paths = List.unmodifiable(_sortedDistinct(paths));

  /// The revision the execution started from — the left edge of the range.
  final String startingRevision;

  /// The revision the execution produced — the right edge of the range.
  final String producedRevision;

  /// The UNCAPPED union of `git diff --name-only <start>..<produced>` and
  /// `git ls-files --others --exclude-standard`.
  ///
  /// UNCAPPED is load-bearing: a reader that takes a prefix has no bound, so
  /// the sixth path is unexamined — and in a confinement gate the sixth path is
  /// exactly where a prohibited file hides. `WorkspaceDelta.changedPaths` caps
  /// at 5 for the separate and legitimate reason that it exists to make a
  /// failure *message* name something concrete
  /// (`workspace_delta_probe.dart:160`, `:213-214`); that reason does not
  /// transfer to a gate that must judge every path.
  ///
  /// May legitimately be empty — a clean, fully committed change genuinely
  /// touches nothing — and that is exactly why an empty list must not be the
  /// representation of a failed read.
  final List<String> paths;

  static List<String> _sortedDistinct(List<String> paths) {
    final distinct = paths.toSet().toList()..sort();
    return distinct;
  }

  @override
  List<Object?> get props => [startingRevision, producedRevision, paths];
}
