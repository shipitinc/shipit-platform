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
  if (instance.description case final value?) 'description': value,
  'state': _workItemStateToJson(instance.state),
  if (instance.designContractId case final value?) 'designContractId': value,
  if (instance.agentSessionId case final value?) 'agentSessionId': value,
  if (instance.qaContractId case final value?) 'qaContractId': value,
  if (instance.featureRef case final value?) 'featureRef': value,
  if (instance.requirementRef case final value?) 'requirementRef': value,
  if (instance.blockingHumanDecisionId case final value?)
    'blockingHumanDecisionId': value,
  if (instance.blockingReason case final value?) 'blockingReason': value,
  if (instance.artifactRefs?.map((e) => e.toJson()).toList() case final value?)
    'artifactRefs': value,
  if (instance.metadata case final value?) 'metadata': value,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  if (instance.completedAt?.toIso8601String() case final value?)
    'completedAt': value,
  if (instance.terminatedAt?.toIso8601String() case final value?)
    'terminatedAt': value,
  'version': instance.version,
};
