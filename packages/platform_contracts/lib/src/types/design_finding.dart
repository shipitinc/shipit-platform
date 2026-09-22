import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/design_finding_category.dart';
import '../enums/design_finding_severity.dart';

part 'design_finding.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignFinding extends Equatable {
  const DesignFinding({
    required this.findingId,
    required this.revisionId,
    required this.reviewExecutionId,
    required this.category,
    required this.severity,
    required this.dimension,
    required this.evidence,
    required this.requiredCorrection,
    required this.affectedSurface,
    required this.createdAt,
    this.resolvedByRevisionId,
    required this.version,
  });

  final String findingId;
  final String revisionId;
  final String reviewExecutionId;
  @JsonKey(
    fromJson: _$designFindingCategoryFromJson,
    toJson: _$designFindingCategoryToJson,
  )
  final DesignFindingCategory category;
  @JsonKey(
    fromJson: _$designFindingSeverityFromJson,
    toJson: _$designFindingSeverityToJson,
  )
  final DesignFindingSeverity severity;
  final String dimension;
  final String evidence;
  final String requiredCorrection;
  final String affectedSurface;
  final DateTime createdAt;
  @JsonKey(includeIfNull: false)
  final String? resolvedByRevisionId;
  final int version;

  factory DesignFinding.fromJson(Map<String, dynamic> json) =>
      _$DesignFindingFromJson(json);

  Map<String, dynamic> toJson() => _$DesignFindingToJson(this);

  @override
  List<Object?> get props => [
        findingId,
        revisionId,
        reviewExecutionId,
        category,
        severity,
        dimension,
        evidence,
        requiredCorrection,
        affectedSurface,
        createdAt,
        resolvedByRevisionId,
        version,
      ];
}

DesignFindingCategory _$designFindingCategoryFromJson(String value) =>
    DesignFindingCategory.fromWire(value);

String _$designFindingCategoryToJson(DesignFindingCategory value) => value.wire;

DesignFindingSeverity _$designFindingSeverityFromJson(String value) =>
    DesignFindingSeverity.fromWire(value);

String _$designFindingSeverityToJson(DesignFindingSeverity value) => value.wire;