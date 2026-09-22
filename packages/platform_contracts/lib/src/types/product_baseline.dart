import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/baseline_section_key.dart';
import '../enums/evidence_kind.dart';
import '../enums/product_baseline_status.dart';
import 'baseline_fact.dart';

part 'product_baseline.g.dart';

/// Durable, versioned, structured Product understanding (checkpoint 006
/// §ProductBaseline). Not a single giant Markdown summary: facts are typed by
/// [BaselineSectionKey], attributable, and provenance-carrying.
///
/// Versioning: accepted revisions are immutable historical authority. New
/// material changes become a new [revision], never a silent mutation of an
/// accepted one. Human acceptance binds to an exact revision + [contentHash].
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ProductBaseline extends Equatable {
  const ProductBaseline({
    required this.baselineId,
    required this.productId,
    required this.revision,
    this.status = ProductBaselineStatus.proposed,
    required this.facts,
    required this.contentHash,
    this.supersedesBaselineId,
    this.proposedAt,
    this.reviewedAt,
    this.acceptedAt,
    this.acceptedBy,
    this.acceptedDecisionId,
    this.createdAt,
    this.updatedAt,
    this.version = 1,
    this.contentHashVersion = 1,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationKind,
  });

  final String baselineId;

  /// DIRECT scope: owning Product.
  final String productId;

  /// Monotonic revision; new material change → new revision, not mutation.
  final int revision;

  @JsonKey(fromJson: _statusFromWire, toJson: _statusToWire)
  final ProductBaselineStatus status;

  /// All structured facts across sections; grouped by [BaselineSectionKey].
  final List<BaselineFact> facts;

  /// SHA-256 over the canonical serialized fact payload. Human acceptance
  /// binds to exactly this revision + hash.
  final String contentHash;

  final String? supersedesBaselineId;

  final DateTime? proposedAt;
  final DateTime? reviewedAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;

  /// Reference to the authoritative [HumanDecision] that authorized this
  /// acceptance. The decision binds the exact [revision] + [contentHash]; this
  /// field is a pointer to that evidence, never a copy of its signature.
  final String? acceptedDecisionId;

  /// Version of the canonical content hash contract used to compute [contentHash].
  /// Hash V1: fields factId, section, claim, provenance, evidenceRefs only.
  /// Hash V2 (historical defective): includes maturity, assumptionNote,
  ///   redacted, sorted evidenceRefs, but used a non-standard SHA-256 — never
  ///   used for new approval candidates.
  /// Hash V3: standard SHA-256 over the deterministic canonical payload;
  ///   the only contract for newly created baselines.
  final int contentHashVersion;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int version;

  /// When this revision was verified. Null means unverified.
  final DateTime? verifiedAt;

  /// Identity of the worker that performed the verification.
  ///
  /// AGENTS.md §12: QA evidence is collected by workers, not agents. An agent
  /// may *produce* a baseline; it may never be the thing that attests to it.
  final String? verifiedBy;

  /// Whether the attestation is a platform verification or merely an agent's
  /// own claim. Only [EvidenceKind.platformVerifiedEvidence] is independent.
  @JsonKey(fromJson: _kindFromWireOrNull, toJson: _kindToWireOrNull)
  final EvidenceKind? verificationKind;

  /// Whether this revision was verified by something other than the agent that
  /// produced it — the precondition for asking a human to approve it.
  bool get isIndependentlyVerified =>
      verificationKind == EvidenceKind.platformVerifiedEvidence &&
      verifiedBy != null &&
      verifiedBy!.isNotEmpty &&
      verifiedAt != null;

  List<BaselineFact> factsFor(BaselineSectionKey section) =>
      facts.where((f) => f.section == section).toList();

  ProductBaseline copyWith({
    ProductBaselineStatus? status,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? updatedAt,
    int? version,
    int? contentHashVersion,
    DateTime? verifiedAt,
    String? verifiedBy,
    EvidenceKind? verificationKind,
    List<BaselineFact>? facts,
  }) => ProductBaseline(
    baselineId: baselineId,
    productId: productId,
    revision: revision,
    status: status ?? this.status,
    facts: facts ?? this.facts,
    contentHash: contentHash,
    contentHashVersion: contentHashVersion ?? this.contentHashVersion,
    supersedesBaselineId: supersedesBaselineId,
    proposedAt: proposedAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    acceptedBy: acceptedBy ?? this.acceptedBy,
    acceptedDecisionId: acceptedDecisionId ?? this.acceptedDecisionId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    verifiedBy: verifiedBy ?? this.verifiedBy,
    verificationKind: verificationKind ?? this.verificationKind,
  );

  List<String> get sections =>
      facts.map((f) => f.section.wire).toSet().toList();

  factory ProductBaseline.fromJson(Map<String, dynamic> json) =>
      _$ProductBaselineFromJson(json);

  Map<String, dynamic> toJson() => _$ProductBaselineToJson(this);

  @override
  List<Object?> get props => [
    baselineId,
    productId,
    revision,
    status,
    facts,
    contentHash,
    contentHashVersion,
    supersedesBaselineId,
    proposedAt,
    reviewedAt,
    acceptedAt,
    acceptedBy,
    acceptedDecisionId,
    createdAt,
    updatedAt,
    version,
    verifiedAt,
    verifiedBy,
    verificationKind,
  ];
}

ProductBaselineStatus _statusFromWire(String value) =>
    ProductBaselineStatus.fromWire(value);

String _statusToWire(ProductBaselineStatus value) => value.wire;

EvidenceKind? _kindFromWireOrNull(String? value) =>
    value == null ? null : EvidenceKind.fromWire(value);

String? _kindToWireOrNull(EvidenceKind? kind) => kind?.wire;
