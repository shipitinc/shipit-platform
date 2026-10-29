import 'package:control_plane_server/src/design/design_approval_handoff.dart';
import 'package:control_plane_server/src/design/design_revision_producer.dart'
    show designRevisionIdMetadataKey;
import 'package:design_governance/design_governance.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

const String _workItemId = 'wi-handoff-test';
const String _productId = 'prod-handoff';
const String _revisionId = 'design-revision-handoff';
const String _decisionId = 'dec-handoff-test';
final DateTime _now = DateTime.utc(2026, 10, 23, 12);

/// In-memory workflow store for testing.
class _TestWorkflowStore implements WorkflowStore {
  _TestWorkflowStore({
    List<WorkItem>? initialItems,
    List<HumanDecision>? initialDecisions,
  }) : _items = {for (final i in initialItems ?? []) i.workItemId: i},
       _decisions = initialDecisions ?? [];

  final Map<String, WorkItem> _items;
  final List<HumanDecision> _decisions;

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    final item = _items[workItemId];
    if (item == null) throw WorkItemNotFoundException(workItemId);
    return item;
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() async => _items.values.toList();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    if (expectedVersion != null) {
      final existing = _items[item.workItemId];
      if (existing == null) {
        throw WorkItemNotFoundException(item.workItemId);
      }
      if (existing.version != expectedVersion) {
        throw ConcurrentModificationException(
          entityId: item.workItemId,
          expectedVersion: expectedVersion,
          actualVersion: existing.version,
        );
      }
    }
    _items[item.workItemId] = item.copyWith(
      version: item.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) async {
    final decision = _decisions
        .where((d) => d.decisionId == decisionId)
        .firstOrNull;
    if (decision == null) throw HumanDecisionNotFoundException(decisionId);
    return decision;
  }

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) async => _decisions.where((d) => d.workItemId == workItemId).toList();

  @override
  Future<void> saveHumanDecision(HumanDecision decision) async {
    _decisions.removeWhere((d) => d.decisionId == decision.decisionId);
    _decisions.add(decision);
  }

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) async => [];

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) async => null;

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) async {}

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) async {}

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) async => [];

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) async => body(this);

  void addItem(WorkItem item) => _items[item.workItemId] = item;
  void addDecision(HumanDecision decision) => _decisions.add(decision);
}

/// Wrapper around [DurableWorkflowEngine] that records transition attempts.
class _RecordingWorkflowEngine extends DurableWorkflowEngine {
  _RecordingWorkflowEngine({required super.store});

  final List<_TransitionAttempt> attempts = [];

  @override
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = const WorkflowActor(
      actorId: 'orchestrator',
      actorType: ActorType.orchestrator,
    ),
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
    String? reason,
    OperatorActionRecord? operatorAction,
    Map<String, dynamic>? metadataMerge,
  }) async {
    attempts.add(
      _TransitionAttempt(
        workItemId: workItemId,
        to: to,
        idempotencyKey: idempotencyKey,
        trigger: trigger,
        actor: actor,
      ),
    );
    return super.transition(
      workItemId: workItemId,
      to: to,
      trigger: trigger,
      actor: actor,
      context: context,
      decisionId: decisionId,
      idempotencyKey: idempotencyKey,
      reason: reason,
      operatorAction: operatorAction,
      metadataMerge: metadataMerge,
    );
  }
}

class _TransitionAttempt {
  const _TransitionAttempt({
    required this.workItemId,
    required this.to,
    required this.idempotencyKey,
    required this.trigger,
    required this.actor,
  });

  final String workItemId;
  final WorkItemState to;
  final String? idempotencyKey;
  final TransitionTrigger trigger;
  final WorkflowActor actor;
}

/// A workflow engine that fails on transition.
class _FailingWorkflowEngine extends DurableWorkflowEngine {
  _FailingWorkflowEngine({required super.store});

  var _failNext = true;

  @override
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = const WorkflowActor(
      actorId: 'orchestrator',
      actorType: ActorType.orchestrator,
    ),
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
    String? reason,
    OperatorActionRecord? operatorAction,
    Map<String, dynamic>? metadataMerge,
  }) async {
    if (_failNext) {
      _failNext = false;
      throw StateError('simulated transition failure');
    }
    return super.transition(
      workItemId: workItemId,
      to: to,
      trigger: trigger,
      actor: actor,
      context: context,
      decisionId: decisionId,
      idempotencyKey: idempotencyKey,
      reason: reason,
      operatorAction: operatorAction,
      metadataMerge: metadataMerge,
    );
  }
}

/// In-memory design governance store for testing.
/// Maintains its own revision map for test control, delegates other interfaces.
class _TestDesignGovernanceStore implements DesignGovernanceStore {
  _TestDesignGovernanceStore({List<DesignRevision>? initialRevisions})
    : _revisions = {for (final r in initialRevisions ?? []) r.revisionId: r};

  final Map<String, DesignRevision> _revisions;
  final InMemoryDesignGovernanceStore _delegate =
      InMemoryDesignGovernanceStore();

  // DesignRevisionStore methods
  @override
  Future<DesignRevision> readDesignRevision(String revisionId) async {
    final revision = _revisions[revisionId];
    if (revision == null) {
      throw DesignRevisionNotFoundException(revisionId);
    }
    return revision;
  }

  @override
  Future<List<DesignRevision>> readDesignRevisionsForWorkItem(
    String workItemId,
  ) async {
    return _revisions.values.where((r) => r.workItemId == workItemId).toList();
  }

  @override
  Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(
    String workItemId,
  ) async {
    try {
      return _revisions.values.firstWhere(
        (r) =>
            r.workItemId == workItemId &&
            r.status == DesignRevisionStatus.approved,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<DesignRevision?> readLatestDesignRevisionForWorkItem(
    String workItemId,
  ) async {
    final revisions = _revisions.values
        .where((r) => r.workItemId == workItemId)
        .toList();
    if (revisions.isEmpty) return null;
    revisions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return revisions.first;
  }

  @override
  Future<void> saveDesignRevision(
    DesignRevision revision, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final existing = _revisions[revision.revisionId];
      if (existing == null) {
        throw DesignRevisionNotFoundException(revision.revisionId);
      }
      if (existing.version != expectedVersion) {
        throw DesignGovernanceConcurrentModificationException(
          entityId: revision.revisionId,
          expectedVersion: expectedVersion,
          actualVersion: existing.version,
        );
      }
    }
    _revisions[revision.revisionId] = DesignRevision(
      revisionId: revision.revisionId,
      workItemId: revision.workItemId,
      productId: revision.productId,
      parentRevisionId: revision.parentRevisionId,
      designSystemRevision: revision.designSystemRevision,
      provider: revision.provider,
      penpotFileId: revision.penpotFileId,
      penpotPageId: revision.penpotPageId,
      boardIdsJson: revision.boardIdsJson,
      responsiveTargetsJson: revision.responsiveTargetsJson,
      statesRepresentedJson: revision.statesRepresentedJson,
      artifactRefsJson: revision.artifactRefsJson,
      designerExecutionId: revision.designerExecutionId,
      reviewExecutionIdsJson: revision.reviewExecutionIdsJson,
      status: revision.status,
      riskTier: revision.riskTier,
      reviewScopeJson: revision.reviewScopeJson,
      carriedForwardFromRevisionId: revision.carriedForwardFromRevisionId,
      supersededByRevisionId: revision.supersededByRevisionId,
      createdAt: revision.createdAt,
      updatedAt: DateTime.now().toUtc(),
      approvedAt: revision.approvedAt,
      version: revision.version + 1,
      declaredOwnedPaths: revision.declaredOwnedPaths,
    );
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

    return lineage.reversed.toList();
  }

  @override
  Future<DesignRevision?> findDesignRevisionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) async {
    return null;
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(DesignGovernanceStore store) body,
  ) async {
    return body(this);
  }

  // DesignReviewResultStore methods - delegate to _delegate
  @override
  Future<DesignReviewResult> readDesignReviewResult(
    String reviewResultId,
  ) async {
    return _delegate.readDesignReviewResult(reviewResultId);
  }

  @override
  Future<List<DesignReviewResult>> readDesignReviewResultsForRevision(
    String revisionId,
  ) async {
    return _delegate.readDesignReviewResultsForRevision(revisionId);
  }

  @override
  Future<DesignReviewResult?> readDesignReviewResultForExecution(
    String revisionId,
    String reviewExecutionId,
  ) async {
    return _delegate.readDesignReviewResultForExecution(
      revisionId,
      reviewExecutionId,
    );
  }

  @override
  Future<void> saveDesignReviewResult(
    DesignReviewResult result, {
    int? expectedVersion,
  }) async {
    return _delegate.saveDesignReviewResult(
      result,
      expectedVersion: expectedVersion,
    );
  }

  @override
  Future<DesignReviewResult?> findDesignReviewResultByIdempotencyKey(
    String revisionId,
    String idempotencyKey,
  ) async {
    return _delegate.findDesignReviewResultByIdempotencyKey(
      revisionId,
      idempotencyKey,
    );
  }

  // DesignFindingStore methods - delegate to _delegate
  @override
  Future<DesignFinding> readDesignFinding(String findingId) async {
    return _delegate.readDesignFinding(findingId);
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForRevision(
    String revisionId,
  ) async {
    return _delegate.readDesignFindingsForRevision(revisionId);
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForReviewExecution(
    String reviewExecutionId,
  ) async {
    return _delegate.readDesignFindingsForReviewExecution(reviewExecutionId);
  }

  @override
  Future<List<DesignFinding>> readUnresolvedFindingsForRevision(
    String revisionId,
  ) async {
    return _delegate.readUnresolvedFindingsForRevision(revisionId);
  }

  @override
  Future<List<DesignFinding>> readFindingsResolvedByRevision(
    String revisionId,
  ) async {
    return _delegate.readFindingsResolvedByRevision(revisionId);
  }

  @override
  Future<void> saveDesignFinding(
    DesignFinding finding, {
    int? expectedVersion,
  }) async {
    return _delegate.saveDesignFinding(
      finding,
      expectedVersion: expectedVersion,
    );
  }

  @override
  Future<DesignFinding?> findDesignFindingByIdempotencyKey(
    String revisionId,
    String idempotencyKey,
  ) async {
    return _delegate.findDesignFindingByIdempotencyKey(
      revisionId,
      idempotencyKey,
    );
  }

  // DesignRevisionEventStore methods - delegate to _delegate
  @override
  Future<void> appendEvent(DesignRevisionEvent event) async {
    return _delegate.appendEvent(event);
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsForRevision(
    String designRevisionId,
  ) async {
    return _delegate.readEventsForRevision(designRevisionId);
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsAfterSequence(
    String designRevisionId,
    int sequence,
  ) async {
    return _delegate.readEventsAfterSequence(designRevisionId, sequence);
  }

  @override
  Future<DesignRevisionEvent?> readLastEventForRevision(
    String designRevisionId,
  ) async {
    return _delegate.readLastEventForRevision(designRevisionId);
  }

  void addRevision(DesignRevision revision) =>
      _revisions[revision.revisionId] = revision;
}

DesignRevision _createRevision({
  required String revisionId,
  required String workItemId,
  required DesignRevisionStatus status,
}) {
  return DesignRevision(
    revisionId: revisionId,
    workItemId: workItemId,
    productId: _productId,
    designSystemRevision: 'dsr-1',
    provider: DesignProviderType.penpot,
    penpotFileId: 'pf-1',
    penpotPageId: 'pp-1',
    boardIdsJson: '[]',
    responsiveTargetsJson: '[]',
    statesRepresentedJson: '[]',
    artifactRefsJson: '[]',
    designerExecutionId: 'agx-designer-1',
    reviewExecutionIdsJson: '[]',
    status: status,
    riskTier: DesignRiskTier.low,
    createdAt: _now,
    updatedAt: _now,
    version: 1,
  );
}

HumanDecision _createDecision({
  required String decisionId,
  required String workItemId,
  required HumanDecisionType decisionType,
  required HumanDecisionStatus status,
  required HumanDecisionChoice? choice,
}) {
  return HumanDecision(
    decisionId: decisionId,
    workItemId: workItemId,
    decisionType: decisionType,
    status: status,
    question: 'Approve this design?',
    options: const [
      HumanDecisionOption(
        optionId: 'approve',
        label: 'Approve',
        description: 'Approve the design',
        recommended: true,
      ),
      HumanDecisionOption(
        optionId: 'reject',
        label: 'Reject',
        description: 'Reject the design',
        recommended: false,
      ),
    ],
    recommendation: 'approve',
    blocking: true,
    requestedAt: _now,
    updatedAt: _now,
    choice: choice,
    decider: choice != null ? 'human-reviewer' : null,
    rationale: choice != null ? 'Looks good' : null,
    timestamp: choice != null ? _now : null,
    signature: choice != null
        ? DecisionSignature(
            algorithm: 'ed25519',
            publicKey: 'test-pub-key',
            signature: 'test-sig',
            signedAt: _now,
          )
        : null,
    resolvedOptionId: choice?.wire,
  );
}

WorkItem _createWorkItem({
  required WorkItemState state,
  Map<String, dynamic>? metadata,
}) {
  return WorkItem(
    workItemId: _workItemId,
    productId: _productId,
    category: WorkItemCategory.feature,
    title: 'Design the login screen',
    state: state,
    metadata: metadata,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  group('DesignApprovalHandoff', () {
    late _TestWorkflowStore workflowStore;
    late DurableWorkflowEngine workflowEngine;
    late _TestDesignGovernanceStore designGovernanceStore;
    late List<(String, Map<String, dynamic>)> loggedEvents;

    setUp(() {
      loggedEvents = [];
      workflowStore = _TestWorkflowStore();
      workflowEngine = _RecordingWorkflowEngine(store: workflowStore);
      designGovernanceStore = _TestDesignGovernanceStore();
    });

    DesignApprovalHandoff createHandoff() => DesignApprovalHandoff(
      workflowEngine: workflowEngine,
      workflowStore: workflowStore,
      designGovernanceStore: designGovernanceStore,
      logger: (event, data) => loggedEvents.add((event, data)),
    );

    group('Precondition checks', () {
      test('refuses when decisionType is not designApproval', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.engineeringReview,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'WRONG_DECISION_TYPE');
        expect(
          result.workItem.state,
          WorkItemState.designApproved,
        ); // unchanged
        // No blockedBy metadata for precondition refusals
        expect(result.workItem.metadata?['blockedBy'], isNull);
      });

      test('refuses when decision is not resolved', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.pending,
          choice: null,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'DECISION_NOT_RESOLVED');
        expect(result.workItem.state, WorkItemState.designApproved);
      });

      test('refuses when choice is not approve', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.reject,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.reject,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'CHOICE_NOT_APPROVE');
        expect(result.workItem.state, WorkItemState.designApproved);
      });

      test('refuses when item is not at designApproved', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designInReview, // not designApproved
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'ITEM_NOT_DESIGN_APPROVED');
        expect(result.workItem.state, WorkItemState.designInReview);
      });

      test('refuses when designRevisionId is missing from metadata', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {}, // missing designRevisionId
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'MISSING_DESIGN_REVISION_ID');
        expect(result.workItem.state, WorkItemState.designApproved);
      });

      test('refuses when designRevisionId is empty string', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: ''},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'MISSING_DESIGN_REVISION_ID');
        expect(result.workItem.state, WorkItemState.designApproved);
      });
    });

    group('Revision status transition', () {
      test(
        'refuses when revision status cannot transition to approved (draft)',
        () async {
          // Arrange
          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.designApproved,
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.draft,
            ),
          );

          // Act
          final handoff = createHandoff();
          final result = await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert
          expect(result.succeeded, isFalse);
          expect(
            result.failureCode,
            'DESIGN_APPROVAL_HANDOFF_BAD_REVISION_STATUS',
          );
          expect(result.workItem.state, WorkItemState.designApproved);
          // Revision status unchanged
          final revision = await designGovernanceStore.readDesignRevision(
            _revisionId,
          );
          expect(revision.status, DesignRevisionStatus.draft);
        },
      );

      test(
        'refuses when revision status cannot transition to approved (inReview)',
        () async {
          // Arrange
          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.designApproved,
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.inReview,
            ),
          );

          // Act
          final handoff = createHandoff();
          final result = await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert
          expect(result.succeeded, isFalse);
          expect(
            result.failureCode,
            'DESIGN_APPROVAL_HANDOFF_BAD_REVISION_STATUS',
          );
        },
      );

      test(
        'refuses when revision status cannot transition to approved (changesRequired)',
        () async {
          // Arrange
          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.designApproved,
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.changesRequired,
            ),
          );

          // Act
          final handoff = createHandoff();
          final result = await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert
          expect(result.succeeded, isFalse);
          expect(
            result.failureCode,
            'DESIGN_APPROVAL_HANDOFF_BAD_REVISION_STATUS',
          );
        },
      );

      test('succeeds when revision status is reviewPassed', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );
        designGovernanceStore.addRevision(
          _createRevision(
            revisionId: _revisionId,
            workItemId: _workItemId,
            status: DesignRevisionStatus.reviewPassed,
          ),
        );

        // Act
        final handoff = createHandoff();
        await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert - transition is refused by workflow engine (edge may not exist),
        // but revision status should be updated to approved
        final revision = await designGovernanceStore.readDesignRevision(
          _revisionId,
        );
        expect(revision.status, DesignRevisionStatus.approved);
        expect(revision.approvedAt, isNotNull);
      });

      test('succeeds when revision status is humanApprovalRequired', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );
        designGovernanceStore.addRevision(
          _createRevision(
            revisionId: _revisionId,
            workItemId: _workItemId,
            status: DesignRevisionStatus.humanApprovalRequired,
          ),
        );

        // Act
        final handoff = createHandoff();
        await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        final revision = await designGovernanceStore.readDesignRevision(
          _revisionId,
        );
        expect(revision.status, DesignRevisionStatus.approved);
        expect(revision.approvedAt, isNotNull);
      });

      test('refuses when revision not found in store', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: 'non-existent-revision'},
          ),
        );
        // No revision added to store

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        expect(result.failureCode, 'DESIGN_REVISION_NOT_FOUND');
      });
    });

    group('Transition to implementationReady', () {
      test(
        'succeeds when already at implementationReady (idempotent)',
        () async {
          // Arrange
          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.implementationReady, // already at target
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.reviewPassed,
            ),
          );

          // Act
          final handoff = createHandoff();
          final result = await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert
          expect(result.succeeded, isTrue);
          expect(result.workItem.state, WorkItemState.implementationReady);
          expect(
            (workflowEngine as _RecordingWorkflowEngine).attempts,
            isEmpty,
          ); // no transition attempted
          // Revision should be updated to approved
          final revision = await designGovernanceStore.readDesignRevision(
            _revisionId,
          );
          expect(revision.status, DesignRevisionStatus.approved);
        },
      );

      test(
        'attempts transition with correct idempotency key and actor',
        () async {
          // Arrange
          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.designApproved,
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.reviewPassed,
            ),
          );

          // Act
          final handoff = createHandoff();
          await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert - transition attempted with correct parameters
          final recordingEngine = workflowEngine as _RecordingWorkflowEngine;
          expect(recordingEngine.attempts, hasLength(1));
          final attempt = recordingEngine.attempts.single;
          expect(attempt.workItemId, _workItemId);
          expect(attempt.to, WorkItemState.implementationReady);
          expect(
            attempt.idempotencyKey,
            'design-approved:$_workItemId:implementation-ready',
          );
          expect(attempt.trigger, TransitionTrigger.humanDecision);
          expect(attempt.actor.actorType, ActorType.orchestrator);
          expect(attempt.actor.actorId, 'orchestrator');
        },
      );

      test('succeeds and updates revision when transition completes', () async {
        // Arrange - the edge now exists, so transition should succeed
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );
        designGovernanceStore.addRevision(
          _createRevision(
            revisionId: _revisionId,
            workItemId: _workItemId,
            status: DesignRevisionStatus.reviewPassed,
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert - handoff succeeds, revision updated, transition attempted
        expect(result.succeeded, isTrue);
        expect(result.workItem.state, WorkItemState.implementationReady);
        final recordingEngine = workflowEngine as _RecordingWorkflowEngine;
        expect(recordingEngine.attempts, hasLength(1));
        final attempt = recordingEngine.attempts.single;
        expect(attempt.workItemId, _workItemId);
        expect(attempt.to, WorkItemState.implementationReady);
        expect(
          attempt.idempotencyKey,
          'design-approved:$_workItemId:implementation-ready',
        );
        // Revision should be updated to approved
        final revision = await designGovernanceStore.readDesignRevision(
          _revisionId,
        );
        expect(revision.status, DesignRevisionStatus.approved);
        expect(revision.approvedAt, isNotNull);
      });

      test(
        'does not throw on unexpected error, logs and records failure',
        () async {
          // Arrange - use a failing workflow engine
          workflowEngine = _FailingWorkflowEngine(store: workflowStore);

          final decision = _createDecision(
            decisionId: _decisionId,
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
          );
          workflowStore.addDecision(decision);
          workflowStore.addItem(
            _createWorkItem(
              state: WorkItemState.designApproved,
              metadata: {designRevisionIdMetadataKey: _revisionId},
            ),
          );
          designGovernanceStore.addRevision(
            _createRevision(
              revisionId: _revisionId,
              workItemId: _workItemId,
              status: DesignRevisionStatus.reviewPassed,
            ),
          );

          // Act
          final handoff = createHandoff();
          final result = await handoff.execute(
            decision: decision,
            choice: HumanDecisionChoice.approve,
            item: await workflowStore.readWorkItem(_workItemId),
          );

          // Assert - no exception thrown
          expect(result.succeeded, isFalse);
          expect(result.failureCode, 'UNEXPECTED_ERROR');
          // Failure metadata recorded
          final updatedItem = await workflowStore.readWorkItem(_workItemId);
          expect(
            updatedItem.metadata?['blockedBy'],
            'DESIGN_APPROVAL_HANDOFF_FAILED',
          );
          expect(
            updatedItem.metadata?['designApprovalHandoff'],
            'failed:design_approved->implementationReady',
          );
          // Error logged
          final failedLogs = loggedEvents
              .where((e) => e.$1 == 'design.approval.handoff_failed')
              .toList();
          expect(failedLogs, hasLength(1));
        },
      );
    });

    group('Logging', () {
      test('logs handoff_succeeded when transition completes', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.implementationReady, // already at target
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );
        designGovernanceStore.addRevision(
          _createRevision(
            revisionId: _revisionId,
            workItemId: _workItemId,
            status: DesignRevisionStatus.reviewPassed,
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isTrue);
        final successLogs = loggedEvents
            .where(
              (e) => e.$1 == 'design.approval.handoff_succeeded_already_ready',
            )
            .toList();
        expect(successLogs, hasLength(1));
        expect(successLogs.single.$2['workItemId'], _workItemId);
        expect(successLogs.single.$2['revisionId'], _revisionId);
        expect(successLogs.single.$2['decisionId'], _decisionId);
      });

      test('logs handoff_refused for precondition failures', () async {
        // Arrange
        final decision = _createDecision(
          decisionId: _decisionId,
          workItemId: _workItemId,
          decisionType: HumanDecisionType.engineeringReview, // wrong type
          status: HumanDecisionStatus.resolved,
          choice: HumanDecisionChoice.approve,
        );
        workflowStore.addDecision(decision);
        workflowStore.addItem(
          _createWorkItem(
            state: WorkItemState.designApproved,
            metadata: {designRevisionIdMetadataKey: _revisionId},
          ),
        );

        // Act
        final handoff = createHandoff();
        final result = await handoff.execute(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: await workflowStore.readWorkItem(_workItemId),
        );

        // Assert
        expect(result.succeeded, isFalse);
        final refusedLogs = loggedEvents
            .where((e) => e.$1 == 'design.approval.handoff_refused')
            .toList();
        expect(refusedLogs, hasLength(1));
        expect(refusedLogs.single.$2['code'], 'WRONG_DECISION_TYPE');
      });
    });
  });
}
