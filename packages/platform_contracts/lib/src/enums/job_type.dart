/// The bounded set of job kinds the scheduler can launch. Only what the
/// platform's bounded agent execution currently needs exists; there are NO
/// OpenCode-specific job types and no automatic reviewer/design/QA/deploy
/// chains (those arrive in later slices with their own gate policies).
enum JobType {
  /// Drive one bounded implementer execution for a runnable work item.
  implementFeature('implement_feature'),

  /// Produce a design revision in Penpot for a work item.
  designRevision('design_revision'),

  /// Independently review a design revision produced by a different worker.
  designReview('design_review');

  const JobType(this.wire);

  final String wire;

  static JobType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown job type: $value'),
  );
}
