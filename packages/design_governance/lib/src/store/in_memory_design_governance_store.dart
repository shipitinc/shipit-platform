import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_exceptions.dart';
import 'design_governance_store.dart';

/// A non-durable in-memory implementation of all design governance store interfaces.
/// Suitable for unit tests and single-instance usage.
class InMemoryDesignGovernanceStore
    implements DesignGovernanceStore {
  final Map<String, DesignRevision> _revisions = {};
  final Map<String, DesignReviewResult> _reviewResults = {};
  final Map<String, DesignFinding> _findings = {};
  final Map<String, DesignRevisionEvent> _events = {};
  final Map<String, String> _idempotencyKeys = {}; // composite key -> entity ID

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(DesignGovernanceStore store) body,
  ) async => body(this);

  // DesignRevisionStore

  @override
  Future<DesignRevision> readDesignRevision(String revisionId) async {
    final revision = _revisions[revisionId];
    if (revision == null) {
      throw DesignRevisionNotFoundException(revisionId);
    }
    return revision;
  }

  @override
  Future<List<DesignRevision>> readDesignRevisionsForWorkItem(String workItemId) async {
    return _revisions.values.where((r) => r.workItemId == workItemId).toList();
  }

  @override
  Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(String workItemId) async {
    try {
      return _revisions.values.firstWhere(
        (r) => r.workItemId == workItemId && r.status == DesignRevisionStatus.approved,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<DesignRevision?> readLatestDesignRevisionForWorkItem(String workItemId) async {
    final revisions = _revisions.values.where((r) => r.workItemId == workItemId).toList();
    if (revisions.isEmpty) return null;
    revisions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return revisions.first;
  }

  @override
  Future<void> saveDesignRevision(DesignRevision revision, {int? expectedVersion}) async {
    _checkVersion(revision.revisionId, expectedVersion);
    _revisions[revision.revisionId] = revision;
  }

  @override
  Future<List<DesignRevision>> getLineage(String revisionId) async {
    final lineage = <DesignRevision>[];
    var currentId = revisionId;

    while (currentId.isNotEmpty) {
      final revision = _revisions[currentId];
      if (revision == null) break;
      lineage.add(revision);
      currentId = revision.parentRevisionId ?? '';
    }

    return lineage.reversed.toList(); // root to leaf
  }

  @override
  Future<DesignRevision?> findDesignRevisionByIdempotencyKey(String workItemId, String idempotencyKey) async {
    final key = 'rev:$workItemId:$idempotencyKey';
    final entityId = _idempotencyKeys[key];
    if (entityId != null) {
      return _revisions[entityId];
    }
    return null;
  }

  // DesignReviewResultStore

  @override
  Future<DesignReviewResult> readDesignReviewResult(String reviewResultId) async {
    final result = _reviewResults[reviewResultId];
    if (result == null) {
      throw DesignReviewResultNotFoundException(reviewResultId);
    }
    return result;
  }

  @override
  Future<List<DesignReviewResult>> readDesignReviewResultsForRevision(String revisionId) async {
    return _reviewResults.values.where((r) => r.revisionId == revisionId).toList();
  }

  @override
  Future<DesignReviewResult?> readDesignReviewResultForExecution(
    String revisionId,
    String reviewExecutionId,
  ) async {
    try {
      return _reviewResults.values.firstWhere(
        (r) => r.revisionId == revisionId && r.reviewExecutionId == reviewExecutionId,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> saveDesignReviewResult(DesignReviewResult result, {int? expectedVersion}) async {
    _checkVersion(result.reviewExecutionId, expectedVersion);
    _reviewResults[result.reviewExecutionId] = result;
  }

  @override
  Future<DesignReviewResult?> findDesignReviewResultByIdempotencyKey(String revisionId, String idempotencyKey) async {
    final key = 'rr:$revisionId:$idempotencyKey';
    final entityId = _idempotencyKeys[key];
    if (entityId != null) {
      return _reviewResults[entityId];
    }
    return null;
  }

  // DesignFindingStore

  @override
  Future<DesignFinding> readDesignFinding(String findingId) async {
    final finding = _findings[findingId];
    if (finding == null) {
      throw DesignFindingNotFoundException(findingId);
    }
    return finding;
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForRevision(String revisionId) async {
    return _findings.values.where((f) => f.revisionId == revisionId).toList();
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForReviewExecution(String reviewExecutionId) async {
    return _findings.values.where((f) => f.reviewExecutionId == reviewExecutionId).toList();
  }

  @override
  Future<List<DesignFinding>> readUnresolvedFindingsForRevision(String revisionId) async {
    return _findings.values
        .where((f) => f.revisionId == revisionId && f.resolvedByRevisionId == null)
        .toList();
  }

  @override
  Future<List<DesignFinding>> readFindingsResolvedByRevision(String revisionId) async {
    return _findings.values.where((f) => f.resolvedByRevisionId == revisionId).toList();
  }

  @override
  Future<void> saveDesignFinding(DesignFinding finding, {int? expectedVersion}) async {
    _checkVersion(finding.findingId, expectedVersion);
    _findings[finding.findingId] = finding;
  }

  @override
  Future<DesignFinding?> findDesignFindingByIdempotencyKey(String revisionId, String idempotencyKey) async {
    final key = 'fd:$revisionId:$idempotencyKey';
    final entityId = _idempotencyKeys[key];
    if (entityId != null) {
      return _findings[entityId];
    }
    return null;
  }

  // DesignRevisionEventStore

  @override
  Future<void> appendEvent(DesignRevisionEvent event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsForRevision(String designRevisionId) async {
    final events = _events.values
        .where((e) => e.designRevisionId == designRevisionId)
        .toList();
    events.sort((a, b) => a.sequence.compareTo(b.sequence));
    return events;
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsAfterSequence(
    String designRevisionId,
    int sequence,
  ) async {
    final events = _events.values
        .where((e) => e.designRevisionId == designRevisionId && e.sequence > sequence)
        .toList();
    events.sort((a, b) => a.sequence.compareTo(b.sequence));
    return events;
  }

  @override
  Future<DesignRevisionEvent?> readLastEventForRevision(String designRevisionId) async {
    final events = _events.values.where((e) => e.designRevisionId == designRevisionId).toList();
    if (events.isEmpty) return null;
    events.sort((a, b) => b.sequence.compareTo(a.sequence));
    return events.first;
  }

  void _checkVersion(String entityId, int? expectedVersion) {
    if (expectedVersion == null) return;
    
    // Check version from stored entity
    int? currentVersion;
    if (_revisions.containsKey(entityId)) {
      currentVersion = _revisions[entityId]!.version;
    } else if (_reviewResults.containsKey(entityId)) {
      currentVersion = _reviewResults[entityId]!.version;
    } else if (_findings.containsKey(entityId)) {
      currentVersion = _findings[entityId]!.version;
    }
    
    final actualVersion = currentVersion ?? 0;
    if (actualVersion != expectedVersion) {
      throw DesignGovernanceConcurrentModificationException(
        entityId: entityId,
        expectedVersion: expectedVersion,
        actualVersion: actualVersion,
      );
    }
  }
}