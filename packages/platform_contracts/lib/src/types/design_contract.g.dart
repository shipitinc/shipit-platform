// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_contract.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignContract _$DesignContractFromJson(Map<String, dynamic> json) =>
    DesignContract(
      contractId: json['contractId'] as String,
      workItemId: json['workItemId'] as String,
      requiredArtifacts: (json['requiredArtifacts'] as List<dynamic>)
          .map((e) => RequiredArtifact.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviewers: (json['reviewers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      approvalThreshold: (json['approvalThreshold'] as num).toInt(),
      status: _designContractStatusFromJson(json['status'] as String),
      submittedArtifacts: (json['submittedArtifacts'] as List<dynamic>?)
          ?.map((e) => SubmittedArtifact.fromJson(e as Map<String, dynamic>))
          .toList(),
      decisions: (json['decisions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DesignContractToJson(DesignContract instance) =>
    <String, dynamic>{
      'contractId': instance.contractId,
      'workItemId': instance.workItemId,
      'requiredArtifacts': instance.requiredArtifacts
          .map((e) => e.toJson())
          .toList(),
      'reviewers': instance.reviewers,
      'approvalThreshold': instance.approvalThreshold,
      'status': _designContractStatusToJson(instance.status),
      'submittedArtifacts': instance.submittedArtifacts
          ?.map((e) => e.toJson())
          .toList(),
      'decisions': instance.decisions,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'metadata': instance.metadata,
    };

RequiredArtifact _$RequiredArtifactFromJson(Map<String, dynamic> json) =>
    RequiredArtifact(
      artifactType: json['artifactType'] as String,
      description: json['description'] as String,
      required: json['required'] as bool,
      validationSchema: json['validationSchema'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RequiredArtifactToJson(RequiredArtifact instance) =>
    <String, dynamic>{
      'artifactType': instance.artifactType,
      'description': instance.description,
      'required': instance.required,
      'validationSchema': instance.validationSchema,
    };

SubmittedArtifact _$SubmittedArtifactFromJson(Map<String, dynamic> json) =>
    SubmittedArtifact(
      artifactType: json['artifactType'] as String,
      contentHash: json['contentHash'] as String,
      submittedBy: json['submittedBy'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      location: json['location'] as String?,
    );

Map<String, dynamic> _$SubmittedArtifactToJson(SubmittedArtifact instance) =>
    <String, dynamic>{
      'artifactType': instance.artifactType,
      'contentHash': instance.contentHash,
      'submittedBy': instance.submittedBy,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'location': instance.location,
    };
