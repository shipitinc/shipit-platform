import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/design_revision_status.dart';
import '../enums/design_risk_tier.dart';
import '../enums/design_provider_type.dart';

part 'design_revision.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignRevision extends Equatable {
  const DesignRevision({
    required this.revisionId,
    required this.workItemId,
    required this.productId,
    this.parentRevisionId,
    required this.designSystemRevision,
    required this.provider,
    required this.penpotFileId,
    required this.penpotPageId,
    required this.boardIdsJson,
    required this.responsiveTargetsJson,
    required this.statesRepresentedJson,
    required this.artifactRefsJson,
    required this.designerExecutionId,
    required this.reviewExecutionIdsJson,
    required this.status,
    required this.riskTier,
    this.reviewScopeJson,
    this.carriedForwardFromRevisionId,
    this.supersededByRevisionId,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    required this.version,
  });

  final String revisionId;
  final String workItemId;
  final String productId;
  final String? parentRevisionId;
  final String designSystemRevision;
  @JsonKey(
    fromJson: _$designProviderTypeFromJson,
    toJson: _$designProviderTypeToJson,
  )
  final DesignProviderType provider;
  final String? penpotFileId;
  final String? penpotPageId;
  final String boardIdsJson;
  final String responsiveTargetsJson;
  final String statesRepresentedJson;
  final String artifactRefsJson;
  final String designerExecutionId;
  final String reviewExecutionIdsJson;
  @JsonKey(
    fromJson: _$designRevisionStatusFromJson,
    toJson: _$designRevisionStatusToJson,
  )
  final DesignRevisionStatus status;
  @JsonKey(
    fromJson: _$designRiskTierFromJson,
    toJson: _$designRiskTierToJson,
  )
  final DesignRiskTier riskTier;
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? reviewScopeJson;
  @JsonKey(includeIfNull: false)
  final String? carriedForwardFromRevisionId;
  @JsonKey(includeIfNull: false)
  final String? supersededByRevisionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  @JsonKey(includeIfNull: false)
  final DateTime? approvedAt;
  final int version;

  factory DesignRevision.fromJson(Map<String, dynamic> json) =>
      _$DesignRevisionFromJson(json);

  Map<String, dynamic> toJson() => _$DesignRevisionToJson(this);

  @override
  List<Object?> get props => [
        revisionId,
        workItemId,
        productId,
        parentRevisionId,
        designSystemRevision,
        provider,
        penpotFileId,
        penpotPageId,
        boardIdsJson,
        responsiveTargetsJson,
        statesRepresentedJson,
        artifactRefsJson,
        designerExecutionId,
        reviewExecutionIdsJson,
        status,
        riskTier,
        reviewScopeJson,
        carriedForwardFromRevisionId,
        supersededByRevisionId,
        createdAt,
        updatedAt,
        approvedAt,
        version,
      ];
}

DesignProviderType _$designProviderTypeFromJson(String value) =>
    DesignProviderType.fromWire(value);

String _$designProviderTypeToJson(DesignProviderType value) => value.wire;

DesignRevisionStatus _$designRevisionStatusFromJson(String value) =>
    DesignRevisionStatus.fromWire(value);

String _$designRevisionStatusToJson(DesignRevisionStatus value) => value.wire;

DesignRiskTier _$designRiskTierFromJson(String value) =>
    DesignRiskTier.fromWire(value);

String _$designRiskTierToJson(DesignRiskTier value) => value.wire;