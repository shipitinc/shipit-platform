import 'package:platform_contracts/platform_contracts.dart';

/// Maps a resolved human decision to the defect status it unlocks.
///
/// All human-gated defect transitions resolve from specific defect states.
/// The routing table is the only place a (decisionType, choice) is translated
/// into a target defect status.
class DefectDecisionRouting {
  const DefectDecisionRouting._();

  static DefectStatus? targetFor(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    DefectStatus currentStatus,
  ) {
    return switch ((decisionType, choice, currentStatus)) {
      // Clarification answered -> resume triaging
      (HumanDecisionType.defectClarification, HumanDecisionChoice.approve, _) =>
        DefectStatus.triaging,
      (HumanDecisionType.defectClarification, HumanDecisionChoice.reject, _) =>
        DefectStatus.closed,
      (HumanDecisionType.defectClarification, HumanDecisionChoice.rework, _) =>
        DefectStatus.triaging,

      // Fix verification
      (HumanDecisionType.defectFixVerification, HumanDecisionChoice.fixed,
       DefectStatus.fixReadyForVerification) =>
        DefectStatus.resolved,
      (HumanDecisionType.defectFixVerification, HumanDecisionChoice.stillBroken,
       DefectStatus.fixReadyForVerification) =>
        DefectStatus.reported,
      (HumanDecisionType.defectFixVerification, HumanDecisionChoice.partiallyFixed,
       DefectStatus.fixReadyForVerification) =>
        DefectStatus.confirmed,
      (HumanDecisionType.defectFixVerification, HumanDecisionChoice.approve,
       DefectStatus.resolved) =>
        DefectStatus.closed,
      _ => null,
    };
  }

  /// True when [target] is the status this (type, choice, currentStatus) routing unlocks.
  static bool routesTo(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    DefectStatus currentStatus,
    DefectStatus target,
  ) {
    return targetFor(decisionType, choice, currentStatus) == target;
  }
}