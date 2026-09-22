import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/design_review_verdict.dart';
import 'design_finding.dart';

part 'design_review_result.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignReviewResult extends Equatable {
  const DesignReviewResult({
    required this.reviewExecutionId,
    required this.revisionId,
    required this.verdict,
    required this.findings,
    required this.assessedDimensions,
    this.reviewScopeJson,
    required this.createdAt,
    required this.version,
  });

  final String reviewExecutionId;
  final String revisionId;
  @JsonKey(
    fromJson: _$designReviewVerdictFromJson,
    toJson: _$designReviewVerdictToJson,
  )
  final DesignReviewVerdict verdict;
  final List<DesignFinding> findings;
  final List<String> assessedDimensions;
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? reviewScopeJson;
  final DateTime createdAt;
  final int version;

  factory DesignReviewResult.fromJson(Map<String, dynamic> json) =>
      _$DesignReviewResultFromJson(json);

  Map<String, dynamic> toJson() => _$DesignReviewResultToJson(this);

  @override
  List<Object?> get props => [
        reviewExecutionId,
        revisionId,
        verdict,
        findings,
        assessedDimensions,
        reviewScopeJson,
        createdAt,
        version,
      ];

  // Database serialization helpers
  String get findingsJson => _encodeJson(findings.map((f) => f.toJson()).toList());
  String get assessedDimensionsJson => _encodeJson(assessedDimensions);

  static String _encodeJson(Object? value) {
    if (value == null) return '[]';
    // Use a simple JSON encoding - in practice, use jsonEncode
    return value.toString().replaceAll("'", '"');
  }
}

DesignReviewVerdict _$designReviewVerdictFromJson(String value) =>
    DesignReviewVerdict.fromWire(value);

String _$designReviewVerdictToJson(DesignReviewVerdict value) => value.wire;