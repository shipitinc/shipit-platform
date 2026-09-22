import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_store_base.dart';

/// Store interface for [DesignFinding] persistence with CAS and resolution linkage.
abstract interface class DesignFindingStore extends DesignGovernanceStoreBase {
  /// Reads a design finding by its ID.
  Future<DesignFinding> readDesignFinding(String findingId);

  /// Reads all design findings for a revision.
  Future<List<DesignFinding>> readDesignFindingsForRevision(String revisionId);

  /// Reads all design findings for a specific review execution.
  Future<List<DesignFinding>> readDesignFindingsForReviewExecution(String reviewExecutionId);

  /// Reads all unresolved design findings for a revision.
  Future<List<DesignFinding>> readUnresolvedFindingsForRevision(String revisionId);

  /// Reads design findings resolved by a specific revision.
  Future<List<DesignFinding>> readFindingsResolvedByRevision(String revisionId);

  /// Persists a design finding with compare-and-swap on [expectedVersion].
  /// When [expectedVersion] is provided, the write fails with
  /// [DesignGovernanceConcurrentModificationException] on mismatch.
  Future<void> saveDesignFinding(DesignFinding finding, {int? expectedVersion});

  /// Finds a design finding by idempotency key for idempotent creation.
  Future<DesignFinding?> findDesignFindingByIdempotencyKey(String revisionId, String idempotencyKey);
}