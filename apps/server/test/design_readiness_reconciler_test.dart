import 'package:control_plane_server/src/design/design_readiness_reconciler.dart';
import 'package:control_plane_server/src/design/design_revision_producer.dart'
    show designRevisionIdMetadataKey;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

const String _workItemId = 'wi-readiness-test';
const String _productId = 'prod-readiness';
const String _revisionId = 'design-revision-readiness';
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
  });

  final String workItemId;
  final WorkItemState to;
  final String? idempotencyKey;
}

/// A workflow engine that fails on the first transition attempt.
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

void main() {
  group('DesignReadinessReconciler', () {
    late _TestWorkflowStore workflowStore;
    late _RecordingWorkflowEngine workflowEngine;
    late List<(String, Map<String, dynamic>)> loggedEvents;

    setUp(() {
      loggedEvents = [];
      workflowStore = _TestWorkflowStore();
      workflowEngine = _RecordingWorkflowEngine(store: workflowStore);
    });

    DesignReadinessReconciler createReconciler() => DesignReadinessReconciler(
      workflowEngine: workflowEngine,
      workflowStore: workflowStore,
      maxItemsPerSweep: 50,
      logger: (event, data) => loggedEvents.add((event, data)),
    );

    test(
      'sweep transitions eligible designApproved items to implementationReady',
      () async {
        // Arrange: item at designApproved with designRevisionId, no pending decision.
        workflowStore.addItem(
          WorkItem(
            workItemId: _workItemId,
            productId: _productId,
            category: WorkItemCategory.feature,
            title: 'Design the login screen',
            state: WorkItemState.designApproved,
            metadata: {
              designRevisionIdMetadataKey: _revisionId,
            },
            createdAt: _now,
            updatedAt: _now,
          ),
        );

        // Act
        final reconciler = createReconciler();
        final result = await reconciler.sweep();

        // Assert - transition now succeeds because designApproved -> implementationReady
        // edge exists in the workflow engine.
        expect(result.scanned, 1);
        expect(result.transitioned, 1);
        expect(result.refused, 0);
        expect(result.failed, 0);

        final item = await workflowStore.readWorkItem(_workItemId);
        expect(
          item.state,
          WorkItemState.implementationReady,
        ); // transitioned successfully

        // Verify idempotency key was used in the attempt
        expect(workflowEngine.attempts, hasLength(1));
        expect(
          workflowEngine.attempts.single.idempotencyKey,
          'design-readiness:$_workItemId:$_revisionId',
        );
        expect(
          workflowEngine.attempts.single.to,
          WorkItemState.implementationReady,
        );

        // Verify no refusal logged
        final refusalLogs = loggedEvents
            .where((e) => e.$1 == 'design.readiness.refused')
            .toList();
        expect(refusalLogs, isEmpty);

        // Verify sweep completion logged
        expect(
          loggedEvents.any((e) => e.$1 == 'design.readiness.sweep.completed'),
          isTrue,
        );
      },
    );

    test('sweep refuses items with pending designApproval decision', () async {
      // Arrange: item at designApproved with designRevisionId AND pending designApproval.
      workflowStore.addItem(
        WorkItem(
          workItemId: _workItemId,
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design the login screen',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: _revisionId,
          },
          createdAt: _now,
          updatedAt: _now,
          blockingHumanDecisionId: 'dec-1',
        ),
      );
      workflowStore.addDecision(
        HumanDecision(
          decisionId: 'dec-1',
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.pending,
          options: const [],
          requestedAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert
      expect(result.scanned, 1);
      expect(result.transitioned, 0);
      expect(result.refused, 1);
      expect(result.failed, 0);

      final item = await workflowStore.readWorkItem(_workItemId);
      expect(item.state, WorkItemState.designApproved); // unchanged

      // Verify refusal logged
      final refusalLogs = loggedEvents
          .where((e) => e.$1 == 'design.readiness.refused')
          .toList();
      expect(refusalLogs, hasLength(1));
      expect(refusalLogs.single.$2['code'], 'pending_design_approval_decision');

      // Verify sweep completion logged
      expect(
        loggedEvents.any((e) => e.$1 == 'design.readiness.sweep.completed'),
        isTrue,
      );
    });

    test('sweep skips items without designRevisionId metadata', () async {
      // Arrange: item at designApproved but no designRevisionId.
      workflowStore.addItem(
        WorkItem(
          workItemId: _workItemId,
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design the login screen',
          state: WorkItemState.designApproved,
          metadata: {},
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert
      expect(result.scanned, 0);
      expect(result.transitioned, 0);
      expect(result.refused, 0);
      expect(result.failed, 0);
    });

    test('sweep skips items not at designApproved state', () async {
      // Arrange: item at designInReview with designRevisionId.
      workflowStore.addItem(
        WorkItem(
          workItemId: _workItemId,
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design the login screen',
          state: WorkItemState.designInReview,
          metadata: {
            designRevisionIdMetadataKey: _revisionId,
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert
      expect(result.scanned, 0);
      expect(result.transitioned, 0);
      expect(result.refused, 0);
      expect(result.failed, 0);
    });

    test('sweep respects maxItemsPerSweep bound', () async {
      // Arrange: 60 items, all eligible (no pending decisions).
      for (var i = 1; i <= 60; i++) {
        workflowStore.addItem(
          WorkItem(
            workItemId: '$_workItemId-$i',
            productId: _productId,
            category: WorkItemCategory.feature,
            title: 'Design item $i',
            state: WorkItemState.designApproved,
            metadata: {
              designRevisionIdMetadataKey: '$_revisionId-$i',
            },
            createdAt: _now,
            updatedAt: _now,
          ),
        );
      }

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert - only 50 items should be scanned (the bound), all transitioned
      expect(result.scanned, 50);
      expect(result.transitioned, 50);
      expect(result.refused, 0);
      expect(result.failed, 0);
    });

    test('sweep continues on refusal (single-item recovery)', () async {
      // Arrange: two items - one with pending decision (refused), one without (transitions).
      workflowStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-1',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 1',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-1',
          },
          createdAt: _now,
          updatedAt: _now,
          blockingHumanDecisionId: 'dec-1',
        ),
      );
      workflowStore.addDecision(
        HumanDecision(
          decisionId: 'dec-1',
          workItemId: '$_workItemId-1',
          decisionType: HumanDecisionType.designApproval,
          status: HumanDecisionStatus.pending,
          options: const [],
          requestedAt: _now,
          updatedAt: _now,
        ),
      );

      workflowStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-2',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 2',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-2',
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert - both items scanned, one refused (pending decision), one transitioned
      expect(result.scanned, 2);
      expect(result.transitioned, 1);
      expect(result.refused, 1);
      expect(result.failed, 0);

      // Verify item1 unchanged (refused due to pending decision)
      final item1 = await workflowStore.readWorkItem('$_workItemId-1');
      expect(item1.state, WorkItemState.designApproved);
      // Verify item2 transitioned
      final item2 = await workflowStore.readWorkItem('$_workItemId-2');
      expect(item2.state, WorkItemState.implementationReady);
    });

    test('sweep continues on failure (single-item recovery)', () async {
      // Arrange: a reconciler with a failing engine for one item.
      final failingStore = _TestWorkflowStore();
      final failingEngine = _FailingWorkflowEngine(store: failingStore);
      final reconciler = DesignReadinessReconciler(
        workflowEngine: failingEngine,
        workflowStore: failingStore,
        maxItemsPerSweep: 50,
        logger: (event, data) => loggedEvents.add((event, data)),
      );

      failingStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-1',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 1',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-1',
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      failingStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-2',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 2',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-2',
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final result = await reconciler.sweep();

      // Assert - both scanned, first fails (engine throws), second transitioned
      expect(result.scanned, 2);
      expect(result.transitioned, 1);
      expect(result.refused, 0);
      expect(result.failed, 1);

      // Verify failure logged
      final failureLogs = loggedEvents
          .where((e) => e.$1 == 'design.readiness.failed')
          .toList();
      expect(failureLogs, hasLength(1));
    });

    test('sweep does not re-scan items already at implementationReady', () async {
      // Arrange: one item at designApproved, one already at implementationReady.
      workflowStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-1',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 1',
          state: WorkItemState.designApproved,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-1',
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      workflowStore.addItem(
        WorkItem(
          workItemId: '$_workItemId-2',
          productId: _productId,
          category: WorkItemCategory.feature,
          title: 'Design item 2',
          state: WorkItemState.implementationReady,
          metadata: {
            designRevisionIdMetadataKey: '$_revisionId-2',
          },
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      // Act
      final reconciler = createReconciler();
      final result = await reconciler.sweep();

      // Assert - only item 1 scanned, item 2 skipped
      expect(result.scanned, 1);
      expect(result.transitioned, 1);
      expect(result.refused, 0);
      expect(result.failed, 0);

      final item1 = await workflowStore.readWorkItem('$_workItemId-1');
      expect(item1.state, WorkItemState.implementationReady);
      final item2 = await workflowStore.readWorkItem('$_workItemId-2');
      expect(item2.state, WorkItemState.implementationReady);
    });
  });
}
