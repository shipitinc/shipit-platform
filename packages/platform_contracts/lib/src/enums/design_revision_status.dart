enum DesignRevisionStatus {
  draft('draft'),
  inReview('in_review'),
  changesRequired('changes_required'),
  reviewPassed('review_passed'),
  humanApprovalRequired('human_approval_required'),
  approved('approved'),
  superseded('superseded');

  const DesignRevisionStatus(this.wire);

  final String wire;

  static DesignRevisionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw FormatException('Unknown design revision status: $value'),
  );

  bool get isTerminal => this == DesignRevisionStatus.approved ||
      this == DesignRevisionStatus.superseded;

  bool get canTransitionToApproved => switch (this) {
    DesignRevisionStatus.reviewPassed => true,
    DesignRevisionStatus.humanApprovalRequired => true,
    _ => false,
  };
}