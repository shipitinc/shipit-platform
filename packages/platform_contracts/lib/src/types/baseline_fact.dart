import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/provenance.dart';
import '../enums/baseline_section_key.dart';
import '../enums/baseline_maturity.dart';

part 'baseline_fact.g.dart';

/// A single structured, attributable baseline assertion.
///
/// Material facts carry provenance explicitly so an inferred conclusion can
/// never be mistaken for an observed fact (checkpoint 006 §provenance).
/// Evidence references point at durable evidence (repository paths/artifacts),
/// not at secret values — secret values are never ingested (§discovery safety).
///
/// Maturity is orthogonal to provenance — a fact can be OBSERVED + NOT_IMPLEMENTED,
/// HUMAN_PROVIDED + PLANNED, DERIVED + IMPLEMENTED, etc.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class BaselineFact extends Equatable {
  const BaselineFact({
    required this.factId,
    required this.section,
    required this.claim,
    required this.provenance,
    required this.maturity,
    this.evidenceRefs = const [],
    this.assumptionNote,
    this.redacted = false,
  });

  /// Stable identifier so a fact can be targeted by review/correction.
  final String factId;

  @JsonKey(fromJson: _sectionFromWire, toJson: _sectionToWire)
  final BaselineSectionKey section;

  /// Material assertion.
  final String claim;

  @JsonKey(fromJson: _provenanceFromWire, toJson: _provenanceToWire)
  final Provenance provenance;

  @JsonKey(fromJson: _maturityFromWire, toJson: _maturityToWire)
  final BaselineMaturity maturity;

  /// Durable evidence references backing the assertion. Empty only when
  /// [provenance] is assumed/unknown and the gap is recorded in [assumptionNote].
  final List<String> evidenceRefs;

  /// Why an assumption/unknown is recorded instead of an observed fact.
  final String? assumptionNote;

  /// True when the source value was secret and was replaced by a redacted
  /// placeholder during ingestion — never the value itself.
  final bool redacted;

  BaselineFact copyWith({
    BaselineSectionKey? section,
    String? claim,
    Provenance? provenance,
    BaselineMaturity? maturity,
    List<String>? evidenceRefs,
    String? assumptionNote,
    bool? redacted,
  }) => BaselineFact(
    factId: factId,
    section: section ?? this.section,
    claim: claim ?? this.claim,
    provenance: provenance ?? this.provenance,
    maturity: maturity ?? this.maturity,
    evidenceRefs: evidenceRefs ?? this.evidenceRefs,
    assumptionNote: assumptionNote ?? this.assumptionNote,
    redacted: redacted ?? this.redacted,
  );

  factory BaselineFact.fromJson(Map<String, dynamic> json) =>
      _$BaselineFactFromJson(json);

  Map<String, dynamic> toJson() => _$BaselineFactToJson(this);

  @override
  List<Object?> get props => [
    factId,
    section,
    claim,
    provenance,
    maturity,
    evidenceRefs,
    assumptionNote,
    redacted,
  ];
}

BaselineSectionKey _sectionFromWire(String value) =>
    BaselineSectionKey.fromWire(value);

String _sectionToWire(BaselineSectionKey value) => value.wire;

Provenance _provenanceFromWire(String value) => Provenance.fromWire(value);

String _provenanceToWire(Provenance value) => value.wire;

BaselineMaturity _maturityFromWire(String value) => BaselineMaturity.fromWire(value);

String _maturityToWire(BaselineMaturity value) => value.wire;
