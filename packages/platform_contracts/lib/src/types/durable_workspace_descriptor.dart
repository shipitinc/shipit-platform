import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// The literal discriminator that marks a workspace document as DURABLE.
///
/// ## Why this constant exists and is not optional
///
/// `OnboardingRecord.workspace` holds one JSON column and that column now
/// carries **two different shapes**: a per-execution `WorkspaceDescriptor` and
/// a product-scoped [DurableWorkspaceDescriptor]. Nothing in the JSON tells
/// them apart unless one of them says so, so the durable shape says so — with
/// a literal, never-optional, never-varying value.
///
/// The alternative shape (making the three per-execution fields nullable on the
/// existing type) was considered and refused: it would push null-handling into
/// `worker_reconciler`, `local_worker`, `onboarding_worker` and
/// `engineering_review_gate` — the artifact-resolution chain that must fail
/// closed on a missing workspace. Decision `c04f6a8d` chose the parallel type
/// for exactly that reason.
///
/// A reader that cannot tell the two apart would resolve a durable clone as if
/// it belonged to a worker execution that never owned it, which is fabricated
/// provenance — the same defect class this repository has already caught once.
const String kDurableWorkspaceKind = 'durable';

/// A product-scoped, durable, writable clone at an exact pinned commit.
///
/// ## What this is NOT, and why it is a second type
///
/// `WorkspaceDescriptor` describes a checkout owned by one WORKER EXECUTION.
/// Three of its seven required fields are meaningless for a durable clone:
/// `workerExecutionId`, `workerId` and `worktreePath`. A durable clone is
/// created by a platform operation and belongs to a PRODUCT; it is not a
/// worktree, because worktrees are forked per execution and removed when that
/// execution finishes.
///
/// Rather than making those three nullable — which would widen a safety-critical
/// type and force every per-execution consumer to grow a null branch — this is
/// its own type with its own published schema. `WorkspaceDescriptor` and
/// `schemas/workspace_descriptor.schema.json` are untouched.
///
/// ## Why there is no `cleanedAt` here
///
/// The per-execution type records a deletion as `isCleaned`. This one cannot,
/// and the omission is deliberate rather than unfinished: **who deletes a
/// product's only checkout, and when, is an open decision.** A `cleanedAt`
/// nobody writes is a capability that a reader could believe in; a field whose
/// presser has not been decided is worse than no field. See the design's
/// `OD-7.2` / `OD-7.3`. Adding it is a one-line change once a human has decided
/// what presses it.
///
/// ## Why the codec is written by hand
///
/// Every other `platform_contracts` type that needs a `part` directive gets its
/// `.g.dart` from `json_serializable`. This type deliberately has no `part`, and
/// therefore no generated file: the only generated file it would add lives
/// beside this one, and the path is not part of this change's ownership. Five
/// fields and one constant discriminator do not need a generator, and a hand
/// written [fromJson] is also the only place the `kind` literal can be enforced
/// as fail-closed rather than merely defaulted.
@immutable
class DurableWorkspaceDescriptor extends Equatable {
  const DurableWorkspaceDescriptor({
    required this.workspaceId,
    required this.productId,
    required this.repositoryPath,
    required this.startingRevision,
    required this.createdAt,
  });

  /// Stable id of this product's durable clone.
  ///
  /// Product-scoped, not execution-scoped: it names the checkout, and the same
  /// checkout is read by every later execution that implements this product.
  final String workspaceId;

  /// The one Product this clone belongs to.
  final String productId;

  /// Absolute path of the clone on durable storage.
  ///
  /// The answer to "where does this product's code live on disk", and the value
  /// an independent reviewer re-reads to re-validate [startingRevision] inside
  /// it. It must therefore be resolvable from wherever the reviewer is — which
  /// is why the clone is host-backed rather than container-local.
  final String repositoryPath;

  /// The exact committed revision this clone is pinned to.
  ///
  /// Lowercase 40-hex, the same form `OnboardingRecord.pinnedRevision` and
  /// `WorkspaceDescriptor.startingRevision` take, and the pairing
  /// `OnboardingRecord.validate` enforces. The clone is created FROM this
  /// commit and is never silently moved off it.
  final String startingRevision;

  final DateTime createdAt;

  /// Always [kDurableWorkspaceKind].
  ///
  /// A getter rather than a field: it is a constant of the TYPE, so making it a
  /// constructor parameter would be a way to write a "durable" descriptor that
  /// is not one.
  String get kind => kDurableWorkspaceKind;

  /// Reads a durable descriptor, or refuses anything that is not one.
  ///
  /// ## Why this throws instead of defaulting
  ///
  /// The discriminator is the whole safety property. A document whose `kind` is
  /// absent, non-string, or some other value is not a durable descriptor with a
  /// missing field — it is a document whose SHAPE this reader does not
  /// understand, and guessing is how a per-execution descriptor gets resolved
  /// as a durable clone (or the reverse). Decision `c04f6a8d` and review row
  /// R-10 both require a record of the wrong kind to be a fail-closed error,
  /// never a fallback.
  factory DurableWorkspaceDescriptor.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    if (rawKind != kDurableWorkspaceKind) {
      throw FormatException(
        'a durable workspace document must carry "kind": '
        '"$kDurableWorkspaceKind", and this one carries '
        '${rawKind == null ? 'no kind at all' : '"$rawKind"'}',
        json['kind'],
      );
    }
    return DurableWorkspaceDescriptor(
      workspaceId: _requiredString(json, 'workspaceId'),
      productId: _requiredString(json, 'productId'),
      repositoryPath: _requiredString(json, 'repositoryPath'),
      startingRevision: _requiredString(json, 'startingRevision'),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kDurableWorkspaceKind,
    'workspaceId': workspaceId,
    'productId': productId,
    'repositoryPath': repositoryPath,
    'startingRevision': startingRevision,
    'createdAt': createdAt.toIso8601String(),
  };

  static String _requiredString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String) {
      throw FormatException(
        'a durable workspace document needs a string "$field", and this one '
        'carries ${value == null ? 'none' : 'a ${value.runtimeType}'}',
        value,
      );
    }
    return value;
  }

  @override
  List<Object?> get props => [
    workspaceId,
    productId,
    repositoryPath,
    startingRevision,
    createdAt,
  ];

  /// Deliberately uninformative about anything that matters.
  @override
  String toString() =>
      'DurableWorkspaceDescriptor(workspaceId: $workspaceId, '
      'productId: $productId, startingRevision: $startingRevision)';
}
