import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/workflow_state.dart';

part 'design_contract.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignContract extends Equatable {
  const DesignContract({
    required this.contractId,
    required this.workItemId,
    required this.requiredArtifacts,
    required this.reviewers,
    required this.approvalThreshold,
    required this.status,
    this.submittedArtifacts,
    this.decisions,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.metadata,
  });

  final String contractId;
  final String workItemId;
  final List<RequiredArtifact> requiredArtifacts;
  final List<String> reviewers;
  final int approvalThreshold;
  @JsonKey(
    fromJson: _designContractStatusFromJson,
    toJson: _designContractStatusToJson,
  )
  final DesignContractStatus status;
  final List<SubmittedArtifact>? submittedArtifacts;
  final List<String>? decisions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;

  factory DesignContract.fromJson(Map<String, dynamic> json) =>
      _$DesignContractFromJson(json);

  Map<String, dynamic> toJson() => _$DesignContractToJson(this);

  @override
  List<Object?> get props => [
    contractId,
    workItemId,
    requiredArtifacts,
    reviewers,
    approvalThreshold,
    status,
    submittedArtifacts,
    decisions,
    createdAt,
    updatedAt,
    expiresAt,
    metadata,
  ];
}

DesignContractStatus _designContractStatusFromJson(String value) =>
    switch (value) {
      'under_review' => DesignContractStatus.underReview,
      _ => DesignContractStatus.values.byName(value),
    };

String _designContractStatusToJson(DesignContractStatus value) =>
    switch (value) {
      DesignContractStatus.underReview => 'under_review',
      _ => value.name,
    };

@JsonSerializable(explicitToJson: true)
@immutable
class RequiredArtifact extends Equatable {
  const RequiredArtifact({
    required this.artifactType,
    required this.description,
    required this.required,
    this.validationSchema,
  });

  final String artifactType;
  final String description;
  final bool required;
  final Map<String, dynamic>? validationSchema;

  factory RequiredArtifact.fromJson(Map<String, dynamic> json) =>
      _$RequiredArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$RequiredArtifactToJson(this);

  @override
  List<Object?> get props => [
    artifactType,
    description,
    required,
    validationSchema,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class SubmittedArtifact extends Equatable {
  const SubmittedArtifact({
    required this.artifactType,
    required this.contentHash,
    required this.submittedBy,
    required this.submittedAt,
    this.location,
  });

  final String artifactType;
  final String contentHash;
  final String submittedBy;
  final DateTime submittedAt;
  final String? location;

  factory SubmittedArtifact.fromJson(Map<String, dynamic> json) =>
      _$SubmittedArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$SubmittedArtifactToJson(this);

  @override
  List<Object?> get props => [
    artifactType,
    contentHash,
    submittedBy,
    submittedAt,
    location,
  ];
}
