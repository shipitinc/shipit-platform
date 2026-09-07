import 'package:platform_contracts/platform_contracts.dart';

import '../validation/transition_validator.dart';

class QATransitions {
  static const Map<(QAStatus, QAStatus), List<GuardCondition<QAStatus>>>
  _legalTransitions = {
    (QAStatus.pending, QAStatus.inProgress): [],
    (QAStatus.inProgress, QAStatus.passed): [],
    (QAStatus.inProgress, QAStatus.failed): [],
    (QAStatus.inProgress, QAStatus.waived): [],
    (QAStatus.failed, QAStatus.inProgress): [],
    (QAStatus.failed, QAStatus.waived): [],
  };

  static bool isLegalTransition(QAStatus from, QAStatus to) {
    return _legalTransitions.containsKey((from, to));
  }

  static List<GuardCondition<QAStatus>> getGuards(QAStatus from, QAStatus to) {
    return _legalTransitions[(from, to)] ?? [];
  }
}
