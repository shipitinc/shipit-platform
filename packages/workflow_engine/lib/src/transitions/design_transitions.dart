import 'package:platform_contracts/platform_contracts.dart';

import '../validation/transition_validator.dart';

class DesignTransitions {
  static const Map<
    (DesignContractStatus, DesignContractStatus),
    List<GuardCondition<DesignContractStatus>>
  >
  _legalTransitions = {
    (DesignContractStatus.draft, DesignContractStatus.underReview): [],
    (DesignContractStatus.underReview, DesignContractStatus.approved): [],
    (DesignContractStatus.underReview, DesignContractStatus.rejected): [],
    (DesignContractStatus.underReview, DesignContractStatus.expired): [],
    (DesignContractStatus.rejected, DesignContractStatus.draft): [],
    (DesignContractStatus.expired, DesignContractStatus.draft): [],
  };

  static bool isLegalTransition(
    DesignContractStatus from,
    DesignContractStatus to,
  ) {
    return _legalTransitions.containsKey((from, to));
  }

  static List<GuardCondition<DesignContractStatus>> getGuards(
    DesignContractStatus from,
    DesignContractStatus to,
  ) {
    return _legalTransitions[(from, to)] ?? [];
  }
}
