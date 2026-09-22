/// Exceptions for design governance stores.
class DesignRevisionNotFoundException implements Exception {
  DesignRevisionNotFoundException(this.revisionId);

  final String revisionId;

  @override
  String toString() => 'Design revision not found: $revisionId';
}

class DesignReviewResultNotFoundException implements Exception {
  DesignReviewResultNotFoundException(this.reviewResultId);

  final String reviewResultId;

  @override
  String toString() => 'Design review result not found: $reviewResultId';
}

class DesignFindingNotFoundException implements Exception {
  DesignFindingNotFoundException(this.findingId);

  final String findingId;

  @override
  String toString() => 'Design finding not found: $findingId';
}

class DesignRevisionEventNotFoundException implements Exception {
  DesignRevisionEventNotFoundException(this.eventId);

  final String eventId;

  @override
  String toString() => 'Design revision event not found: $eventId';
}

class DesignGovernanceConcurrentModificationException implements Exception {
  DesignGovernanceConcurrentModificationException({
    required this.entityId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String entityId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of $entityId (expected version $expectedVersion, actual $actualVersion)';
}

class DesignGovernanceIndependenceViolationException implements Exception {
  DesignGovernanceIndependenceViolationException({
    required this.revisionId,
    required this.executionId,
  });

  final String revisionId;
  final String executionId;

  @override
  String toString() =>
      'Independence violation: execution $executionId cannot review its own design revision $revisionId';
}

class DesignGovernanceImmutabilityViolationException implements Exception {
  DesignGovernanceImmutabilityViolationException({
    required this.revisionId,
  });

  final String revisionId;

  @override
  String toString() => 'Immutability violation: approved design revision $revisionId cannot be modified';
}

class DesignGovernanceSupersessionIntegrityViolationException implements Exception {
  DesignGovernanceSupersessionIntegrityViolationException({
    required this.workItemId,
    required this.message,
  });

  final String workItemId;
  final String message;

  @override
  String toString() =>
      'Supersession integrity violation for work item $workItemId: $message';
}