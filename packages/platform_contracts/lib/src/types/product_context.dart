import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'product.dart';
import 'repository_reference.dart';
import 'product_baseline.dart';
import 'clarification_request.dart';

part 'product_context.g.dart';

/// Bounded, authoritative Product context loaded for an execution boundary
/// (checkpoint 006 §ProductContext).
///
/// Given a `productId`, a brand-new orchestrator execution can load this
/// structured context with no prior chat, no long-lived session, and no
/// mutable process-global. It deliberately does NOT concatenate the repository
/// or every checkpoint into a prompt — durable pointers + structured facts.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ProductContext extends Equatable {
  const ProductContext({
    required this.product,
    this.repositories = const [],
    this.activeBaseline,
    this.allBaselines = const [],
    this.openClarifications = const [],
    this.snapshotId,
  });

  final Product product;

  /// Durable repository identities owned by this Product.
  final List<RepositoryReference> repositories;

  /// The accepted baseline revision currently authoritative (if accepted yet).
  final ProductBaseline? activeBaseline;

  /// Full versioned baseline lineage (immutable historical record), newest
  /// revision first.
  final List<ProductBaseline> allBaselines;

  /// Clarifications still awaiting a human answer on this Product.
  final List<ClarificationRequest> openClarifications;

  /// Opaque handle identifying the discovery *snapshot* used to build the
  /// baseline (a pinned read-only representation). Never the live worktree.
  final String? snapshotId;

  factory ProductContext.fromJson(Map<String, dynamic> json) =>
      _$ProductContextFromJson(json);

  Map<String, dynamic> toJson() => _$ProductContextToJson(this);

  @override
  List<Object?> get props => [
    product,
    repositories,
    activeBaseline,
    allBaselines,
    openClarifications,
    snapshotId,
  ];
}
