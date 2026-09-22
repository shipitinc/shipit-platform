// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_brief.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignBrief _$DesignBriefFromJson(Map<String, dynamic> json) => DesignBrief(
  briefId: json['briefId'] as String,
  workItemId: json['workItemId'] as String,
  productId: json['productId'] as String,
  title: json['title'] as String,
  context: json['context'] as String,
  requirements: (json['requirements'] as List<dynamic>)
      .map((e) => DesignRequirement.fromJson(e as Map<String, dynamic>))
      .toList(),
  constraints: (json['constraints'] as List<dynamic>)
      .map((e) => DesignConstraint.fromJson(e as Map<String, dynamic>))
      .toList(),
  acceptanceCriteria: (json['acceptanceCriteria'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  referenceArtifacts: (json['referenceArtifacts'] as List<dynamic>?)
      ?.map((e) => ReferenceArtifact.fromJson(e as Map<String, dynamic>))
      .toList(),
  designSystemTokens: (json['designSystemTokens'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$DesignBriefToJson(DesignBrief instance) =>
    <String, dynamic>{
      'briefId': instance.briefId,
      'workItemId': instance.workItemId,
      'productId': instance.productId,
      'title': instance.title,
      'context': instance.context,
      'requirements': instance.requirements.map((e) => e.toJson()).toList(),
      'constraints': instance.constraints.map((e) => e.toJson()).toList(),
      'acceptanceCriteria': instance.acceptanceCriteria,
      'referenceArtifacts': ?instance.referenceArtifacts
          ?.map((e) => e.toJson())
          .toList(),
      'designSystemTokens': ?instance.designSystemTokens,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };

DesignRequirement _$DesignRequirementFromJson(Map<String, dynamic> json) =>
    DesignRequirement(
      requirementId: json['requirementId'] as String,
      description: json['description'] as String,
      priority: _$designRequirementPriorityFromJson(json['priority'] as String),
      traceabilityRef: json['traceabilityRef'] as String?,
    );

Map<String, dynamic> _$DesignRequirementToJson(DesignRequirement instance) =>
    <String, dynamic>{
      'requirementId': instance.requirementId,
      'description': instance.description,
      'priority': _$designRequirementPriorityToJson(instance.priority),
      'traceabilityRef': ?instance.traceabilityRef,
    };

DesignConstraint _$DesignConstraintFromJson(Map<String, dynamic> json) =>
    DesignConstraint(
      constraintId: json['constraintId'] as String,
      description: json['description'] as String,
      type: _$designConstraintTypeFromJson(json['type'] as String),
    );

Map<String, dynamic> _$DesignConstraintToJson(DesignConstraint instance) =>
    <String, dynamic>{
      'constraintId': instance.constraintId,
      'description': instance.description,
      'type': _$designConstraintTypeToJson(instance.type),
    };

ReferenceArtifact _$ReferenceArtifactFromJson(Map<String, dynamic> json) =>
    ReferenceArtifact(
      artifactType: json['artifactType'] as String,
      location: json['location'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ReferenceArtifactToJson(ReferenceArtifact instance) =>
    <String, dynamic>{
      'artifactType': instance.artifactType,
      'location': instance.location,
      'description': ?instance.description,
    };
