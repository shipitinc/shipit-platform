import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_store_base.dart';

/// Store interface for [DesignReviewResult] persistence with CAS.
abstract interface class DesignReviewResultStore extends DesignGovernanceStoreBase {
  /// Reads a design review result by its ID (which is the reviewExecutionId).
  Future<DesignReviewResult> readDesignReviewResult(String reviewResultId);

  /// Reads all design review results for a revision.
  Future<List<DesignReviewResult>> readDesignReviewResultsForRevision(String revisionId);

  /// Reads the design review result for a specific review execution.
  Future<DesignReviewResult?> readDesignReviewResultForExecution(
    String revisionId,
    String reviewExecutionId,
  );

  /// Persists a design review result with compare-and-swap on [expectedVersion].
  /// When [expectedVersion] is provided, the write fails with
  /// [DesignGovernanceConcurrentModificationException] on mismatch.
  Future<void> saveDesignReviewResult(DesignReviewResult result, {int? expectedVersion});

  /// Finds a design review result by idempotency key for idempotent creation.
  Future<DesignReviewResult?> findDesignReviewResultByIdempotencyKey(String revisionId, String idempotencyKey);
}