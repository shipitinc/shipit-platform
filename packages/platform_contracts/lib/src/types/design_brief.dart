import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'design_brief.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignBrief extends Equatable {
  const DesignBrief({
    required this.briefId,
    required this.workItemId,
    required this.productId,
    required this.title,
    required this.context,
    required this.requirements,
    required this.constraints,
    required this.acceptanceCriteria,
    this.referenceArtifacts,
    this.designSystemTokens,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String briefId;
  final String workItemId;
  final String productId;
  final String title;
  final String context;
  final List<DesignRequirement> requirements;
  final List<DesignConstraint> constraints;
  final List<String> acceptanceCriteria;
  @JsonKey(includeIfNull: false)
  final List<ReferenceArtifact>? referenceArtifacts;
  @JsonKey(includeIfNull: false)
  final List<String>? designSystemTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  factory DesignBrief.fromJson(Map<String, dynamic> json) =>
      _$DesignBriefFromJson(json);

  Map<String, dynamic> toJson() => _$DesignBriefToJson(this);

  @override
  List<Object?> get props => [
        briefId,
        workItemId,
        productId,
        title,
        context,
        requirements,
        constraints,
        acceptanceCriteria,
        referenceArtifacts,
        designSystemTokens,
        createdAt,
        updatedAt,
        version,
      ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DesignRequirement extends Equatable {
  const DesignRequirement({
    required this.requirementId,
    required this.description,
    required this.priority,
    this.traceabilityRef,
  });

  final String requirementId;
  final String description;
  @JsonKey(
    fromJson: _$designRequirementPriorityFromJson,
    toJson: _$designRequirementPriorityToJson,
  )
  final DesignRequirementPriority priority;
  @JsonKey(includeIfNull: false)
  final String? traceabilityRef;

  factory DesignRequirement.fromJson(Map<String, dynamic> json) =>
      _$DesignRequirementFromJson(json);

  Map<String, dynamic> toJson() => _$DesignRequirementToJson(this);

  @override
  List<Object?> get props => [
        requirementId,
        description,
        priority,
        traceabilityRef,
      ];
}

enum DesignRequirementPriority {
  must('must'),
  should('should'),
  could('could'),
  wont('wont');

  const DesignRequirementPriority(this.wire);

  final String wire;

  static DesignRequirementPriority fromWire(String value) => values.firstWhere(
    (priority) => priority.wire == value,
    orElse: () => throw FormatException('Unknown design requirement priority: $value'),
  );
}

DesignRequirementPriority _$designRequirementPriorityFromJson(String value) =>
    DesignRequirementPriority.fromWire(value);

String _$designRequirementPriorityToJson(DesignRequirementPriority value) =>
    value.wire;

@JsonSerializable(explicitToJson: true)
@immutable
class DesignConstraint extends Equatable {
  const DesignConstraint({
    required this.constraintId,
    required this.description,
    required this.type,
  });

  final String constraintId;
  final String description;
  @JsonKey(
    fromJson: _$designConstraintTypeFromJson,
    toJson: _$designConstraintTypeToJson,
  )
  final DesignConstraintType type;

  factory DesignConstraint.fromJson(Map<String, dynamic> json) =>
      _$DesignConstraintFromJson(json);

  Map<String, dynamic> toJson() => _$DesignConstraintToJson(this);

  @override
  List<Object?> get props => [
        constraintId,
        description,
        type,
      ];
}

enum DesignConstraintType {
  technical('technical'),
  brand('brand'),
  accessibility('accessibility'),
  regulatory('regulatory'),
  platform('platform'),
  designSystem('design_system');

  const DesignConstraintType(this.wire);

  final String wire;

  static DesignConstraintType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown design constraint type: $value'),
  );
}

DesignConstraintType _$designConstraintTypeFromJson(String value) =>
    DesignConstraintType.fromWire(value);

String _$designConstraintTypeToJson(DesignConstraintType value) => value.wire;

@JsonSerializable(explicitToJson: true)
@immutable
class ReferenceArtifact extends Equatable {
  const ReferenceArtifact({
    required this.artifactType,
    required this.location,
    this.description,
  });

  final String artifactType;
  final String location;
  @JsonKey(includeIfNull: false)
  final String? description;

  factory ReferenceArtifact.fromJson(Map<String, dynamic> json) =>
      _$ReferenceArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$ReferenceArtifactToJson(this);

  @override
  List<Object?> get props => [
        artifactType,
        location,
        description,
      ];
}