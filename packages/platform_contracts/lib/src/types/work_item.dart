import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/workflow_state.dart';
import '../enums/work_item_category.dart';

part 'work_item.g.dart';

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
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
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
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  factory WorkItem.fromJson(Map<String, dynamic> json) =>
      _$WorkItemFromJson(json);

  Map<String, dynamic> toJson() => _$WorkItemToJson(this);

  WorkItem copyWith({
    String? workItemId,
    String? productId,
    WorkItemCategory? category,
    String? title,
    String? description,
    WorkItemState? state,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return WorkItem(
      workItemId: workItemId ?? this.workItemId,
      productId: productId ?? this.productId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      state: state ?? this.state,
      designContractId: designContractId ?? this.designContractId,
      agentSessionId: agentSessionId ?? this.agentSessionId,
      qaContractId: qaContractId ?? this.qaContractId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
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
    metadata,
    createdAt,
    updatedAt,
    completedAt,
  ];
}

WorkItemCategory _workItemCategoryFromJson(String value) =>
    WorkItemCategory.values.byName(value);

String _workItemCategoryToJson(WorkItemCategory value) => value.name;

WorkItemState _workItemStateFromJson(String value) =>
    WorkItemState.fromWire(value);

String _workItemStateToJson(WorkItemState value) => value.wire;
