// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baseline_fact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaselineFact _$BaselineFactFromJson(Map<String, dynamic> json) => BaselineFact(
  factId: json['factId'] as String,
  section: _sectionFromWire(json['section'] as String),
  claim: json['claim'] as String,
  provenance: _provenanceFromWire(json['provenance'] as String),
  maturity: _maturityFromWire(json['maturity'] as String),
  evidenceRefs:
      (json['evidenceRefs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  assumptionNote: json['assumptionNote'] as String?,
  redacted: json['redacted'] as bool? ?? false,
);

Map<String, dynamic> _$BaselineFactToJson(BaselineFact instance) =>
    <String, dynamic>{
      'factId': instance.factId,
      'section': _sectionToWire(instance.section),
      'claim': instance.claim,
      'provenance': _provenanceToWire(instance.provenance),
      'maturity': _maturityToWire(instance.maturity),
      'evidenceRefs': instance.evidenceRefs,
      'assumptionNote': ?instance.assumptionNote,
      'redacted': instance.redacted,
    };
