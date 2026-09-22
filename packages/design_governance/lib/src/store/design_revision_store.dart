import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_store_base.dart';

/// Store interface for [DesignRevision] persistence with CAS, lineage traversal,
/// and supersession integrity.
abstract interface class DesignRevisionStore extends DesignGovernanceStoreBase {
  /// Reads a design revision by its ID.
  Future<DesignRevision> readDesignRevision(String revisionId);

  /// Reads all design revisions for a work item.
  Future<List<DesignRevision>> readDesignRevisionsForWorkItem(String workItemId);

  /// Reads the currently approved design revision for a work item, if any.
  Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(String workItemId);

  /// Reads the latest design revision for a work item (by createdAt).
  Future<DesignRevision?> readLatestDesignRevisionForWorkItem(String workItemId);

  /// Persists a design revision with compare-and-swap on [expectedVersion].
  /// When [expectedVersion] is provided, the write fails with
  /// [DesignGovernanceConcurrentModificationException] on mismatch.
  Future<void> saveDesignRevision(DesignRevision revision, {int? expectedVersion});

  /// Traverses the parent lineage from [revisionId] up to the root.
  /// Returns list from root to [revisionId] (inclusive).
  Future<List<DesignRevision>> getLineage(String revisionId);

  /// Finds a design revision by idempotency key for idempotent creation.
  Future<DesignRevision?> findDesignRevisionByIdempotencyKey(String workItemId, String idempotencyKey);
}