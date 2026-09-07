// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qa_pass_criteria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QAPassCriteria _$QAPassCriteriaFromJson(Map<String, dynamic> json) =>
    QAPassCriteria(
      allRequiredGatesMustPass:
          json['allRequiredGatesMustPass'] as bool? ?? true,
      optionalGateFailuresAllowed:
          (json['optionalGateFailuresAllowed'] as num?)?.toInt() ?? 0,
      waiverRequiresHumanDecision:
          json['waiverRequiresHumanDecision'] as bool? ?? true,
    );

Map<String, dynamic> _$QAPassCriteriaToJson(QAPassCriteria instance) =>
    <String, dynamic>{
      'allRequiredGatesMustPass': instance.allRequiredGatesMustPass,
      'optionalGateFailuresAllowed': instance.optionalGateFailuresAllowed,
      'waiverRequiresHumanDecision': instance.waiverRequiresHumanDecision,
    };
