import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/decision_view.dart';
import '../generated/job_summary_view.dart';
import '../generated/resolve_decision_view.dart';
import '../generated/transition_view.dart';
import '../generated/work_item_detail_view.dart';
import '../services/control_plane_service.dart';
import '../services/ui_view_mappers.dart';

/// Read endpoints for durable workflow state (work items + their transitions).
class WorkflowEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Returns the jobs belonging to a work item, newest first.
  ///
  /// Read-only: the operator surface reports what the scheduler has committed
  /// and never enqueues, claims or cancels. Feeds the Run detail line that
  /// explains what is held up behind a pending decision.
  Future<List<JobSummaryView>> jobsForWorkItem(
    Session session, {
    required String workItemId,
  }) async {
    final service = ControlPlaneService(session);
    final workItem = await service.readWorkItem(workItemId);
    final jobs = await service.listJobsForWorkItem(workItemId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return jobs
        .map(
          (job) => UiViewMappers.jobSummaryView(
            job,
            blockedOnDecision: workItem.blockingHumanDecisionId != null,
          ),
        )
        .toList();
  }

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  Future<WorkItemDetailView> inspect(
    Session session, {
    required String workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final item = await service.readWorkItem(workItemId);
      final history = await service.readTransitionHistory(workItemId);
      return WorkItemDetailView(
        workItem: UiViewMappers.workItemView(item),
        transitionHistory: history
            .map(
              (e) => TransitionView(
                transitionId: e.transitionId,
                workItemId: e.workItemId,
                fromState: e.fromState.wire,
                toState: e.toState.wire,
                transitionedAt: e.occurredAt,
                reason: e.reason,
              ),
            )
            .toList(),
      );
    } catch (error, stackTrace) {
      service.logger.error('workflow.inspect.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists every decision attached to a work item, most recent first.
  Future<List<DecisionView>> listDecisions(
    Session session, {
    required String workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final item = await service.readWorkItem(workItemId);
      final decisions = await service.readDecisionsForWorkItem(workItemId);
      return decisions
          .map(
            (d) => UiViewMappers.decisionView(
              decision: d,
              workItem: item,
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      service.logger.error('workflow.decisions.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Resolves a human decision through the durable engine.
  ///
  /// This is the only legal request-side state transition. The decision,
  /// its resolution, and the resulting work item move are persisted
  /// transactionally; a repeated call is an idempotent replay, so retries
  /// after a network failure never double-apply the transition.
  Future<ResolveDecisionView> resolveDecision(
    Session session, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final workItem = await service.resolveHumanDecision(
        decisionId: decisionId,
        choice: HumanDecisionChoice.fromWire(choice),
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      final decision = await service.readDecisionsForWorkItem(
        workItem.workItemId,
      );
      return ResolveDecisionView(
        workItem: UiViewMappers.workItemView(workItem),
        decision: decision.isEmpty
            ? null
            : UiViewMappers.decisionView(
                decision: decision.firstWhere(
                  (d) => d.decisionId == decisionId,
                ),
                workItem: workItem,
              ),
      );
    } catch (error, stackTrace) {
      service.logger.error('workflow.resolve.failed', {
        'decisionId': decisionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
