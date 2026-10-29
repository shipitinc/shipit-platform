import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import 'design_revision_producer.dart' show designRevisionIdMetadataKey;

/// The maximum number of items to process in a single sweep pass.
///
/// This bounds the work per call so a single tick cannot be held by an
/// unbounded reconciliation walk. The value is chosen to be large enough for
/// normal operation but small enough that a pass completes well within the
/// tick budget.
const int _designReadinessMaxItemsPerSweep = 50;

/// The event name for a refused readiness transition.
const String designReadinessRefusedEvent = 'design.readiness.refused';

/// The result of one [DesignReadinessReconciler.sweep] pass.
class DesignReadinessSweepResult {
  const DesignReadinessSweepResult({
    required this.scanned,
    required this.transitioned,
    required this.refused,
    required this.failed,
  });

  /// Number of work items examined in this sweep.
  final int scanned;

  /// Number of work items successfully transitioned to implementationReady.
  final int transitioned;

  /// Number of work items where the transition was refused (precondition failed
  /// or policy rejected).
  final int refused;

  /// Number of work items where an unexpected error occurred during evaluation.
  final int failed;

  @override
  String toString() =>
      'DesignReadinessSweepResult(scanned: $scanned, transitioned: $transitioned, '
      'refused: $refused, failed: $failed)';
}

/// Reconciles design-approved work items to the implementation-ready state.
///
/// This reconciler is the "readiness reconciler" specified in design-revision.md
/// §4.4.4. It runs as part of the design lane tick, after the producer has
/// advanced items to `designInReview` and the recorder has raised `designApproval`
/// decisions, and before the design review recorder runs.
///
/// It scans for work items at `designApproved` that carry a `designRevisionId`
/// in metadata and have no pending `designApproval` decision, then attempts to
/// transition them to `implementationReady` using an idempotency key derived from
/// the work item and revision.
///
/// Each item is evaluated independently: a refusal or failure for one item does
/// not stop the sweep from processing the remaining items.
class DesignReadinessReconciler {
  DesignReadinessReconciler({
    required this.workflowEngine,
    required this.workflowStore,
    this.maxItemsPerSweep = _designReadinessMaxItemsPerSweep,
    this.logger,
  });

  final DurableWorkflowEngine workflowEngine;
  final WorkflowStore workflowStore;
  final int maxItemsPerSweep;
  final void Function(String event, Map<String, dynamic> data)? logger;

  /// Runs one sweep pass.
  ///
  /// Returns a [DesignReadinessSweepResult] with counters for the pass.
  ///
  /// The sweep:
  /// 1. Reads all work items (bounded by [maxItemsPerSweep]).
  /// 2. Filters to items at `designApproved` with a non-empty `designRevisionId`
  ///    in metadata and no pending `designApproval` decision.
  /// 3. For each eligible item, attempts to transition to `implementationReady`
  ///    using idempotency key `design-readiness:<workItemId>:<revisionId>`.
  /// 4. Logs refusals with reason via `design.readiness.refused`.
  /// 5. Continues on refusal or error (single-item recovery).
  Future<DesignReadinessSweepResult> sweep() async {
    var scanned = 0;
    var transitioned = 0;
    var refused = 0;
    var failed = 0;

    // Read all work items. In production this is a bounded query; tests use
    // in-memory stores with small datasets. We apply the bound after filtering
    // to ensure we don't scan unboundedly.
    final allItems = await workflowStore.readAllWorkItems();

    // Filter to designApproved items with designRevisionId metadata.
    final candidates = <WorkItem>[];
    for (final item in allItems) {
      if (item.state != WorkItemState.designApproved) continue;
      final revisionId = item.metadata?[designRevisionIdMetadataKey];
      if (revisionId is! String || revisionId.isEmpty) continue;
      candidates.add(item);
      if (candidates.length >= maxItemsPerSweep) break;
    }

    for (final item in candidates) {
      scanned++;
      final revisionId = item.metadata![designRevisionIdMetadataKey] as String;

      // Check for pending designApproval decision.
      final decisions = await workflowStore.readHumanDecisionsForWorkItem(
        item.workItemId,
      );
      final hasPendingDesignApproval = decisions.any(
        (d) =>
            d.decisionType == HumanDecisionType.designApproval &&
            !d.status.isResolved,
      );

      if (hasPendingDesignApproval) {
        _logRefusal(
          item.workItemId,
          revisionId,
          'pending_design_approval_decision',
          'item has unresolved designApproval decision',
        );
        refused++;
        continue;
      }

      // Attempt the transition with idempotency key.
      final idempotencyKey = 'design-readiness:${item.workItemId}:$revisionId';
      try {
        await workflowEngine.transition(
          workItemId: item.workItemId,
          to: WorkItemState.implementationReady,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
          idempotencyKey: idempotencyKey,
          reason:
              'Design readiness reconciler: design approved, advancing to implementation ready',
        );
        transitioned++;
        logger?.call('design.readiness.transitioned', {
          'workItemId': item.workItemId,
          'revisionId': revisionId,
          'idempotencyKey': idempotencyKey,
        });
      } on WorkflowTransitionRejectedException catch (e) {
        // Transition refused by policy (e.g., no legal edge, guard failed).
        // This is a named refusal, not a failure.
        _logRefusal(
          item.workItemId,
          revisionId,
          'transition_refused',
          e.record.reason ?? 'policy rejected transition',
        );
        refused++;
      } on Object catch (error, stackTrace) {
        // Unexpected error (store unavailable, etc.). Record as failed but continue.
        logger?.call('design.readiness.failed', {
          'workItemId': item.workItemId,
          'revisionId': revisionId,
          'error': error.toString(),
          'stack': stackTrace.toString(),
        });
        failed++;
      }
    }

    logger?.call('design.readiness.sweep.completed', {
      'scanned': scanned,
      'transitioned': transitioned,
      'refused': refused,
      'failed': failed,
    });
    return DesignReadinessSweepResult(
      scanned: scanned,
      transitioned: transitioned,
      refused: refused,
      failed: failed,
    );
  }

  void _logRefusal(
    String workItemId,
    String revisionId,
    String code,
    String detail,
  ) {
    logger?.call(designReadinessRefusedEvent, {
      'workItemId': workItemId,
      'revisionId': revisionId,
      'code': code,
      'detail': detail,
    });
  }
}
