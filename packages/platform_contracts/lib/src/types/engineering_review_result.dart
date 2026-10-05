import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';
import 'review_result_base.dart';
import 'design_finding.dart';

part 'engineering_review_result.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class EngineeringReviewResult extends Equatable {
  const EngineeringReviewResult({
    required this.reviewExecutionId,
    required this.workItemId,
    required this.verdict,
    required this.findings,
    required this.assessedDimensions,
    this.reviewScopeJson,
    required this.createdAt,
    required this.version,
    required this.reviewerRole,
  });

  final String reviewExecutionId;
  final String workItemId;
  @JsonKey(fromJson: _reviewVerdictFromJson, toJson: _reviewVerdictToJson)
  final ReviewVerdict verdict;
  final List<DesignFinding> findings;
  final List<String> assessedDimensions;
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? reviewScopeJson;
  final DateTime createdAt;
  final int version;
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole reviewerRole;

  factory EngineeringReviewResult.fromJson(Map<String, dynamic> json) =>
      _$EngineeringReviewResultFromJson(json);

  Map<String, dynamic> toJson() => _$EngineeringReviewResultToJson(this);

  @override
  List<Object?> get props => [
        reviewExecutionId,
        workItemId,
        verdict,
        findings,
        assessedDimensions,
        reviewScopeJson,
        createdAt,
        version,
        reviewerRole,
      ];

  String get findingsJson => _encodeJson(findings.map((f) => f.toJson()).toList());
  String get assessedDimensionsJson => _encodeJson(assessedDimensions);

  static String _encodeJson(Object? value) {
    if (value == null) return '[]';
    return value.toString().replaceAll("'", '"');
  }
}

ReviewVerdict _reviewVerdictFromJson(String value) => ReviewVerdict.fromWire(value);
String _reviewVerdictToJson(ReviewVerdict value) => value.wire;

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);
String _agentRoleToJson(AgentRole value) => value.wire;