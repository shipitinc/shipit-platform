import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'qa_pass_criteria.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAPassCriteria extends Equatable {
  const QAPassCriteria({
    this.allRequiredGatesMustPass = true,
    this.optionalGateFailuresAllowed = 0,
    this.waiverRequiresHumanDecision = true,
  });

  final bool allRequiredGatesMustPass;
  final int optionalGateFailuresAllowed;
  final bool waiverRequiresHumanDecision;

  factory QAPassCriteria.fromJson(Map<String, dynamic> json) =>
      _$QAPassCriteriaFromJson(json);

  Map<String, dynamic> toJson() => _$QAPassCriteriaToJson(this);

  @override
  List<Object?> get props => [
    allRequiredGatesMustPass,
    optionalGateFailuresAllowed,
    waiverRequiresHumanDecision,
  ];
}
