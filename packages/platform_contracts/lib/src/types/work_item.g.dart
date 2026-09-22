// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkItem _$WorkItemFromJson(Map<String, dynamic> json) => WorkItem(
  workItemId: json['workItemId'] as String,
  productId: json['productId'] as String,
  category: _workItemCategoryFromJson(json['category'] as String),
  title: json['title'] as String,
  description: json['description'] as String?,
  state: _workItemStateFromJson(json['state'] as String),
  designContractId: json['designContractId'] as String?,
  agentSessionId: json['agentSessionId'] as String?,
  qaContractId: json['qaContractId'] as String?,
  featureRef: json['featureRef'] as String?,
  requirementRef: json['requirementRef'] as String?,
  blockingHumanDecisionId: json['blockingHumanDecisionId'] as String?,
  blockingReason: json['blockingReason'] as String?,
  artifactRefs: (json['artifactRefs'] as List<dynamic>?)
      ?.map((e) => ArtifactReference.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  terminatedAt: json['terminatedAt'] == null
      ? null
      : DateTime.parse(json['terminatedAt'] as String),
  version: (json['version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$WorkItemToJson(WorkItem instance) => <String, dynamic>{
  'workItemId': instance.workItemId,
  'productId': instance.productId,
  'category': _workItemCategoryToJson(instance.category),
  'title': instance.title,
  'description': ?instance.description,
  'state': _workItemStateToJson(instance.state),
  'designContractId': ?instance.designContractId,
  'agentSessionId': ?instance.agentSessionId,
  'qaContractId': ?instance.qaContractId,
  'featureRef': ?instance.featureRef,
  'requirementRef': ?instance.requirementRef,
  'blockingHumanDecisionId': ?instance.blockingHumanDecisionId,
  'blockingReason': ?instance.blockingReason,
  'artifactRefs': ?instance.artifactRefs?.map((e) => e.toJson()).toList(),
  'metadata': ?instance.metadata,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'completedAt': ?instance.completedAt?.toIso8601String(),
  'terminatedAt': ?instance.terminatedAt?.toIso8601String(),
  'version': instance.version,
};
