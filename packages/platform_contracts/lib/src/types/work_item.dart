import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/workflow_state.dart';
import '../enums/work_item_category.dart';
import 'artifact_reference.dart';

part 'work_item.g.dart';

const Object _unset = Object();

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkItem extends Equatable {
  const WorkItem({
    required this.workItemId,
    required this.productId,
    required this.category,
    required this.title,
    this.description,
    required this.state,
    this.designContractId,
    this.agentSessionId,
    this.qaContractId,
    this.featureRef,
    this.requirementRef,
    this.blockingHumanDecisionId,
    this.blockingReason,
    this.artifactRefs,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.terminatedAt,
    this.version = 1,
  });

  final String workItemId;
  final String productId;
  @JsonKey(fromJson: _workItemCategoryFromJson, toJson: _workItemCategoryToJson)
  final WorkItemCategory category;
  final String title;
  final String? description;
  @JsonKey(fromJson: _workItemStateFromJson, toJson: _workItemStateToJson)
  final WorkItemState state;
  final String? designContractId;
  final String? agentSessionId;
  final String? qaContractId;
  final String? featureRef;
  final String? requirementRef;
  final String? blockingHumanDecisionId;
  final String? blockingReason;
  final List<ArtifactReference>? artifactRefs;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? terminatedAt;
  @JsonKey(defaultValue: 1)
  final int version;

  bool get isTerminal => state.isTerminal;

  factory WorkItem.fromJson(Map<String, dynamic> json) =>
      _$WorkItemFromJson(json);

  Map<String, dynamic> toJson() => _$WorkItemToJson(this);

  WorkItem copyWith({
    String? workItemId,
    String? productId,
    WorkItemCategory? category,
    String? title,
    Object? description = _unset,
    WorkItemState? state,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    Object? featureRef = _unset,
    Object? requirementRef = _unset,
    Object? blockingHumanDecisionId = _unset,
    Object? blockingReason = _unset,
    Object? artifactRefs = _unset,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    Object? terminatedAt = _unset,
    int? version,
  }) {
    return WorkItem(
      workItemId: workItemId ?? this.workItemId,
      productId: productId ?? this.productId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      state: state ?? this.state,
      designContractId: designContractId ?? this.designContractId,
      agentSessionId: agentSessionId ?? this.agentSessionId,
      qaContractId: qaContractId ?? this.qaContractId,
      featureRef: identical(featureRef, _unset)
          ? this.featureRef
          : featureRef as String?,
      requirementRef: identical(requirementRef, _unset)
          ? this.requirementRef
          : requirementRef as String?,
      blockingHumanDecisionId: identical(blockingHumanDecisionId, _unset)
          ? this.blockingHumanDecisionId
          : blockingHumanDecisionId as String?,
      blockingReason: identical(blockingReason, _unset)
          ? this.blockingReason
          : blockingReason as String?,
      artifactRefs: identical(artifactRefs, _unset)
          ? this.artifactRefs
          : artifactRefs as List<ArtifactReference>?,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      terminatedAt: identical(terminatedAt, _unset)
          ? this.terminatedAt
          : terminatedAt as DateTime?,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    workItemId,
    productId,
    category,
    title,
    description,
    state,
    designContractId,
    agentSessionId,
    qaContractId,
    featureRef,
    requirementRef,
    blockingHumanDecisionId,
    blockingReason,
    artifactRefs,
    metadata,
    createdAt,
    updatedAt,
    completedAt,
    terminatedAt,
    version,
  ];
}

WorkItemCategory _workItemCategoryFromJson(String value) =>
    WorkItemCategory.values.byName(value);

String _workItemCategoryToJson(WorkItemCategory value) => value.name;

WorkItemState _workItemStateFromJson(String value) =>
    WorkItemState.fromWire(value);

String _workItemStateToJson(WorkItemState value) => value.wire;
