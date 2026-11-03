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

  /// Test/override seam for the service this endpoint builds.
  ///
  /// Production behaviour is unchanged: this returns the same
  /// `ControlPlaneService(session)` the methods constructed before. It is
  /// deliberately NOT a capability override — a test substitutes the STORE,
  /// never the resolution path.
  ///
  /// `@doNotGenerate` is REQUIRED and is not decoration. Serverpod treats
  /// every public, non-`@doNotGenerate`, `Session`-first method on an
  /// `Endpoint` as a wire endpoint and fails generation unless it returns
  /// `Future` or `Stream`; this returns a plain `ControlPlaneService`, so
  /// without the annotation `serverpod generate` exits 1.
  @doNotGenerate
  ControlPlaneService serviceFor(Session session) =>
      ControlPlaneService(session);

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
        // `outcome` is carried verbatim, and it is the field that makes this
        // list honest. `work_item_transition` is an ATTEMPT log: the engine
        // appends a row and changes NOTHING when the policy refuses an edge.
        // Without this the client cannot tell a move from a refusal, and it
        // rendered 236 refused `agent_completed -> review_in_progress` attempts
        // on QA as "Independent review started" — asserting a transition that
        // never happened, to an operator, 236 times.
        //
        // `e.outcome.wire` and never a literal: the wire values are
        // `TransitionOutcome.accepted` / `.rejected`, and a hand-written string
        // here is how the two states get spelled differently on the two sides
        // of the wire.
        transitionHistory: history
            .map(
              (e) => TransitionView(
                transitionId: e.transitionId,
                workItemId: e.workItemId,
                fromState: e.fromState.wire,
                toState: e.toState.wire,
                transitionedAt: e.occurredAt,
                reason: e.reason,
                outcome: e.outcome.wire,
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
          .map((d) => UiViewMappers.decisionView(decision: d, workItem: item))
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
  /// This was, until `WorkItemActionEndpoints` landed, the only legal
  /// request-side state transition. It is now the FIRST of two: the second is
  /// the operator action surface on a work item parked in a failure state
  /// (`work_item_action_endpoints.dart` — `retryFailedWorkItem` /
  /// `stopFailedWorkItem`), which is deliberately a separate endpoint class so
  /// this comment and `ControlPlaneService`'s had to be amended rather than
  /// left quietly false.
  ///
  /// What still holds is the part that matters: there is still no third path,
  /// and neither of these writes SQL or sets `WorkItem.state` directly. Both go
  /// through `DurableWorkflowEngine` under the injected policy, both are
  /// idempotent under a client-minted key, and a repeated call replays the
  /// prior outcome instead of re-applying the transition.
  ///
  /// One class of decision is deliberately NOT routed through the engine:
  /// tickets hung off a `system:` scope id (`system:provider-health` — every
  /// `hd-provider-*`/`hd-all-down-*` infrastructure decision the
  /// provider-health monitor raises) have no `work_item` row to move and a
  /// choice vocabulary (`acknowledge`/`investigate`/`escalate`) that
  /// `HumanDecisionChoice` does not contain. Before, both facts threw inside
  /// this method — the `fromWire` parse, then the engine's `readWorkItem` —
  /// and ~28 pending infra tickets could never be answered (F-250). The
  /// service resolves those at the store and returns `workItem: null`; the
  /// wire still requires a `WorkItemView`, so the scope itself is projected
  /// with `state: 'system'` — visibly NOT a `WorkItemState`, because a scope
  /// has no lifecycle to report.
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
    final service = serviceFor(session);
    try {
      final result = await service.resolveDecision(
        decisionId: decisionId,
        choice: choice,
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      final item = result.workItem;
      final resolvedDecision = result.decision;
      return ResolveDecisionView(
        workItem: item != null
            ? UiViewMappers.workItemView(item)
            : UiViewMappers.systemScopeWorkItemView(
                scopeId: resolvedDecision.workItemId,
                requestedAt: resolvedDecision.requestedAt,
                updatedAt: resolvedDecision.updatedAt,
                resolvedAt: resolvedDecision.timestamp,
              ),
        decision: item != null
            ? UiViewMappers.decisionView(
                decision: resolvedDecision,
                workItem: item,
              )
            : UiViewMappers.scopeDecisionView(
                decision: resolvedDecision,
                scopeId: resolvedDecision.workItemId,
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
