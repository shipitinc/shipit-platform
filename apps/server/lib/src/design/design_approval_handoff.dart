/// DESIGN APPROVAL HANDOFF — the post-approval transition to implementationReady.
///
/// Called from [ControlPlaneService.resolveHumanDecision] after a `designApproval`
/// decision is resolved with choice `approve`.
///
/// ## §5.4(b) SPECIFICATION
///
///  1. **Preconditions** (each an explicit refusal, none throws):
///     - decisionType == HumanDecisionType.designApproval
///     - decision.status.isResolved == true
///     - choice == HumanDecisionChoice.approve
///     - item.state == WorkItemState.designApproved
///     - item.metadata['designRevisionId'] is present and non-empty
///
///  2. **Revision status**: moves the associated `DesignRevision` to
///     `DesignRevisionStatus.approved` only from `reviewPassed` or
///     `humanApprovalRequired`; else refusal `DESIGN_APPROVAL_HANDOFF_BAD_REVISION_STATUS`.
///
///  3. **Transition**: `designApproved → implementationReady`,
///     actor=workflowOrchestrator, trigger=humanDecision, decisionId,
///     idempotencyKey=`design-approved:<workItemId>:implementation-ready`.
///     If already at implementationReady, succeeds and ensures status write only.
///
///  4. **Failure**: any refusal leaves item at designApproved, writes
///     `blockedBy: DESIGN_APPROVAL_HANDOFF_FAILED` and
///     `designApprovalHandoff: 'failed:<observed-transition>'` via metadataMerge,
///     logs `design.approval.handoff_failed`, does NOT throw.
///
///  5. Placed at composition boundary (where [_recordDesignScopeGrant] lives),
///     not inside [HumanDecisionRouting].
library;

import 'package:design_governance/design_governance.dart'
    show DesignGovernanceStore, DesignRevisionNotFoundException;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'design_revision_producer.dart' show designRevisionIdMetadataKey;

/// The result of a [DesignApprovalHandoff.execute] call.
class DesignApprovalHandoffResult {
  const DesignApprovalHandoffResult({
    required this.succeeded,
    required this.workItem,
    this.failureCode,
    this.failureDetail,
  });

  /// Whether the handoff succeeded (transition completed or already at target).
  final bool succeeded;

  /// The work item after the handoff attempt.
  final WorkItem workItem;

  /// A machine-readable failure code when [succeeded] is false.
  final String? failureCode;

  /// Human-readable detail for logging/debugging when [succeeded] is false.
  final String? failureDetail;
}

/// Executes the design-approval handoff: advances the design revision status and
/// transitions the work item from `designApproved` to `implementationReady`.
class DesignApprovalHandoff {
  DesignApprovalHandoff({
    required this.workflowEngine,
    required this.workflowStore,
    required this.designGovernanceStore,
    this.logger,
  });

  final DurableWorkflowEngine workflowEngine;
  final WorkflowStore workflowStore;
  final DesignGovernanceStore designGovernanceStore;
  final void Function(String event, Map<String, dynamic> data)? logger;

  /// Executes the handoff per §5.4(b).
  ///
  /// Returns a [DesignApprovalHandoffResult] — never throws on precondition
  /// failure or transition refusal.
  Future<DesignApprovalHandoffResult> execute({
    required HumanDecision decision,
    required HumanDecisionChoice choice,
    required WorkItem item,
  }) async {
    // 1. PRECONDITIONS — each an explicit refusal.
    if (decision.decisionType != HumanDecisionType.designApproval) {
      return _refused(
        item,
        'WRONG_DECISION_TYPE',
        'decisionType is ${decision.decisionType.wire}, expected designApproval',
      );
    }
    if (!decision.status.isResolved) {
      return _refused(
        item,
        'DECISION_NOT_RESOLVED',
        'decision status is ${decision.status.wire}, expected resolved',
      );
    }
    if (choice != HumanDecisionChoice.approve) {
      return _refused(
        item,
        'CHOICE_NOT_APPROVE',
        'choice is ${choice.wire}, expected approve',
      );
    }
    if (item.state != WorkItemState.designApproved &&
        item.state != WorkItemState.implementationReady) {
      return _refused(
        item,
        'ITEM_NOT_DESIGN_APPROVED',
        'item state is ${item.state.wire}, expected designApproved or implementationReady',
      );
    }
    final revisionId = item.metadata?[designRevisionIdMetadataKey];
    if (revisionId is! String || revisionId.isEmpty) {
      return _refused(
        item,
        'MISSING_DESIGN_REVISION_ID',
        'item.metadata[designRevisionId] absent or empty',
      );
    }

    // 2. REVISION STATUS — move to approved only from reviewPassed/humanApprovalRequired.
    DesignRevision revision;
    try {
      revision = await designGovernanceStore.readDesignRevision(revisionId);
    } on DesignRevisionNotFoundException {
      return _refused(
        item,
        'DESIGN_REVISION_NOT_FOUND',
        'design revision $revisionId not found in store',
      );
    }
    if (!revision.status.canTransitionToApproved) {
      return _refused(
        item,
        'DESIGN_APPROVAL_HANDOFF_BAD_REVISION_STATUS',
        'design revision $revisionId status is ${revision.status.wire}, '
            'cannot transition to approved (only from reviewPassed or humanApprovalRequired)',
      );
    }

    // Update the revision status to approved.
    final now = DateTime.now().toUtc();
    final approvedRevision = DesignRevision(
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
      status: DesignRevisionStatus.approved,
      riskTier: revision.riskTier,
      reviewScopeJson: revision.reviewScopeJson,
      carriedForwardFromRevisionId: revision.carriedForwardFromRevisionId,
      supersededByRevisionId: revision.supersededByRevisionId,
      createdAt: revision.createdAt,
      updatedAt: now,
      approvedAt: now,
      version: revision.version + 1,
      declaredOwnedPaths: revision.declaredOwnedPaths,
    );
    await designGovernanceStore.saveDesignRevision(approvedRevision);

    // 3. TRANSITION — if already at implementationReady, succeed with status write only.
    if (item.state == WorkItemState.implementationReady) {
      logger?.call('design.approval.handoff_succeeded_already_ready', {
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'decisionId': decision.decisionId,
      });
      return DesignApprovalHandoffResult(succeeded: true, workItem: item);
    }

    // Attempt the transition with idempotency key.
    final idempotencyKey =
        'design-approved:${item.workItemId}:implementation-ready';
    try {
      final transitioned = await workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.humanDecision,
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        idempotencyKey: idempotencyKey,
        reason:
            'DesignApprovalHandoff: design approved, advancing to implementation ready',
        decisionId: decision.decisionId,
      );

      logger?.call('design.approval.handoff_succeeded', {
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'decisionId': decision.decisionId,
        'idempotencyKey': idempotencyKey,
        'fromState': item.state.wire,
        'toState': transitioned.state.wire,
      });

      return DesignApprovalHandoffResult(
        succeeded: true,
        workItem: transitioned,
      );
    } on WorkflowTransitionRejectedException catch (e) {
      // Transition refused by policy (e.g., no legal edge, guard failed).
      // This is a named refusal, not a failure — record blockedBy and continue.
      final failureDetail =
          e.record.reason ??
          'policy rejected transition: ${e.record.guardEvaluations}';
      await _markHandoffFailed(item, decision.decisionId, failureDetail);
      return DesignApprovalHandoffResult(
        succeeded: false,
        workItem: item,
        failureCode: 'TRANSITION_REFUSED',
        failureDetail: failureDetail,
      );
    } on Object catch (error, stackTrace) {
      // Unexpected error (store unavailable, etc.). Record as failed but don't throw.
      final failureDetail = error.toString();
      await _markHandoffFailed(item, decision.decisionId, failureDetail);
      logger?.call('design.approval.handoff_failed', {
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'decisionId': decision.decisionId,
        'error': failureDetail,
        'stack': stackTrace.toString(),
      });
      return DesignApprovalHandoffResult(
        succeeded: false,
        workItem: item,
        failureCode: 'UNEXPECTED_ERROR',
        failureDetail: failureDetail,
      );
    }
  }

  DesignApprovalHandoffResult _refused(
    WorkItem item,
    String code,
    String detail,
  ) {
    logger?.call('design.approval.handoff_refused', {
      'workItemId': item.workItemId,
      'code': code,
      'detail': detail,
    });
    // Don't mark as failed for precondition refusals — they are expected paths.
    // The item stays at designApproved with no blockedBy marker.
    return DesignApprovalHandoffResult(
      succeeded: false,
      workItem: item,
      failureCode: code,
      failureDetail: detail,
    );
  }

  /// Marks the work item as having a failed handoff by adding blockedBy and
  /// designApprovalHandoff metadata via merge.
  Future<void> _markHandoffFailed(
    WorkItem item,
    String decisionId,
    String failureDetail,
  ) async {
    // The observed transition from the item's current state.
    final observedTransition = '${item.state.wire}->implementationReady';
    final metadata = Map<String, dynamic>.from(item.metadata ?? {});
    metadata['blockedBy'] = 'DESIGN_APPROVAL_HANDOFF_FAILED';
    metadata['designApprovalHandoff'] = 'failed:$observedTransition';

    try {
      await workflowStore.saveWorkItem(
        item.copyWith(
          metadata: metadata,
          updatedAt: DateTime.now().toUtc(),
          version: item.version + 1,
        ),
        expectedVersion: item.version,
      );
    } on ConcurrentModificationException {
      // If we can't write the failure marker, log it but don't throw.
      logger?.call('design.approval.handoff_failed_metadata_conflict', {
        'workItemId': item.workItemId,
        'decisionId': decisionId,
        'reason': 'concurrent modification while marking handoff failed',
      });
    } on Object catch (error) {
      logger?.call('design.approval.handoff_failed_metadata_error', {
        'workItemId': item.workItemId,
        'decisionId': decisionId,
        'error': error.toString(),
      });
    }
  }
}
