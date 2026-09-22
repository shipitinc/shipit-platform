/// Durable identity/review status of a ClarificationRequest (checkpoint 006
/// §uncertainty/clarification). A stop because material information is unknown
/// is durable; the question survives process restart, and the answer resumes
/// the same Product/onboarding/baseline lineage.
enum ClarificationStatus {
  /// Open; onboarding is stopped and waiting for a human answer.
  needsAnswer('needs_answer'),

  /// Answered; onboarding may resume.
  answered('answered');

  const ClarificationStatus(this.wire);

  final String wire;

  static ClarificationStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown clarification status: $value'),
  );
}
