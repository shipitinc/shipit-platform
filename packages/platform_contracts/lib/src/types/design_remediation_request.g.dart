// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_remediation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignRemediationRequest _$DesignRemediationRequestFromJson(
  Map<String, dynamic> json,
) => DesignRemediationRequest(
  defectId: json['defectId'] as String,
  productId: json['productId'] as String,
  defectTitle: json['defectTitle'] as String,
  triageSummary: json['triageSummary'] as String,
  evidenceRefs: (json['evidenceRefs'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  designFlawDescription: json['designFlawDescription'] as String,
  classification: _defectClassificationFromJson(
    json['classification'] as String,
  ),
  triageResultId: json['triageResultId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DesignRemediationRequestToJson(
  DesignRemediationRequest instance,
) => <String, dynamic>{
  'defectId': instance.defectId,
  'productId': instance.productId,
  'defectTitle': instance.defectTitle,
  'triageSummary': instance.triageSummary,
  'evidenceRefs': instance.evidenceRefs,
  'designFlawDescription': instance.designFlawDescription,
  'classification': _defectClassificationToJson(instance.classification),
  'triageResultId': instance.triageResultId,
  'createdAt': instance.createdAt.toIso8601String(),
};
