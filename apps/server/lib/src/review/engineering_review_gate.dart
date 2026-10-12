import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import '../triage/lane_i_tick_hook.dart';

/// Resolves the workload an engineering reviewer must operate on: the revision
/// the IMPLEMENTER actually produced, never the triage/construction-time source.
///
/// Selection is ANCHORED ON IDENTITY, not on recency. [WorkerExecution] carries
/// no role field, so "the implementer's execution" cannot be read off it
/// directly. It is resolved instead through the one identifier that does join
/// the two durable records: the coordinator stamps the producing execution id
/// onto the work item's metadata as `producerActorId`
/// (`ExecutionCoordinator._completeSuccess`), and `LocalWorker` records that
/// very same id on the worker execution as `agentExecutionId`
/// (`LocalWorker._finish`, fed by `AgentExecutionRequest.executionId`, which is
/// `'agx-$workerExecutionId'`). The implementer's artifact therefore belongs to
/// the one execution whose `agentExecutionId` equals `producerActorId`.
///
/// Recency would be wrong here. `LocalWorker` commits an artifact for EVERY
/// non-reviewer role (`ArtifactCommitter`, branch `shipit/impl/<workItemId>`),
/// so a LATER triage run — which in this deployment works in its own scratch
/// repository, not the product repository — is exactly as much a candidate as
/// the implementer's run. "Latest" would hand a reviewer the triage commit as
/// if it were the implementation under review: the wrong-revision dispatch this
/// resolver exists to prevent.
///
/// The produced artifact is recorded as `repositoryPath` plus the artifact
/// commit's `endingRevision`. An `endingRevision` equal to
/// `requestedStartingRevision` (or null) means no commit was produced, and a
/// reviewer execution is never a source of artifacts.
///
/// Returns `null` whenever the artifact cannot be identified with certainty: no
/// `producerActorId`, no execution carrying it, an ambiguous match, a reviewer
/// execution, or an execution that produced no artifact. That is deliberate and
/// fail-closed: the scheduler then does not dispatch at all and reports the job
/// in `SchedulerTickResult.blockedArtifactMissing`, where
/// [engineeringReviewMissingArtifact] turns it into a blocking human decision.
WorkloadResolver engineeringReviewWorkloadResolver({
  required WorkerStore workerStore,
  required String runtimeTypeId,
}) {
  return (job, item) async {
    // The anchor is the only trustworthy statement of WHO produced the work
    // item. Without it there is nothing to anchor to, and nothing may be
    // guessed at.
    final producerActorId = item.metadata?['producerActorId'];
    if (producerActorId is! String || producerActorId.isEmpty) return null;

    final matches = <WorkerExecution>[];
    for (final execution in await workerStore.listWorkerExecutions()) {
      if (execution.workItemId != item.workItemId) continue;
      if (execution.agentExecutionId != producerActorId) continue;
      if (execution.requiredCapabilities.contains(
        WorkerCapability.engineeringReview,
      )) {
        continue;
      }
      matches.add(execution);
    }
    // Exactly one producer. Two executions carrying the same agent execution id
    // cannot be told apart from this data, so refusing beats picking one and
    // dispatching a reviewer at a revision nobody vouched for.
    if (matches.length != 1) return null;

    final producer = matches.single;
    final produced = producer.endingRevision;
    if (produced == null || produced == producer.requestedStartingRevision) {
      return null;
    }
    return SchedulerWorkload(
      repositoryPath: producer.repositoryPath,
      startingRevision: produced,
      timeoutSeconds: 300,
      runtimeTypeId: runtimeTypeId,
    );
  };
}

/// Builds a tick handler for engineering review jobs. When the reviewer
/// execution reaches a terminal state, this raises a blocking
/// `engineeringReview` HumanDecision to move `reviewInProgress` to
/// `waitingForHumanDecision`.
TickJobHandler engineeringReviewTickHandler({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required void Function(String message, Map<String, dynamic> context)? logger,
}) {
  return (Job job) async {
    final workItemId = job.workItemId;
    final item = await workflowEngine.loadWorkItem(workItemId);
    if (item.state == WorkItemState.waitingForHumanDecision) {
      logger?.call(
        'engineering-review-gate-already-blocked',
        {'jobId': job.jobId, 'workItemId': workItemId},
      );
      return;
    }
    if (item.state != WorkItemState.reviewInProgress) {
      logger?.call(
        'engineering-review-gate-skip-non-reviewing-state',
        {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'state': item.state.name,
        },
      );
      return;
    }

    final executionId = job.executionReference?.agentExecutionId;
    if (executionId == null || executionId.isEmpty) {
      logger?.call(
        'engineering-review-gate-missing-execution',
        {'jobId': job.jobId, 'workItemId': workItemId},
      );
      return;
    }

    final execution = await executionStore.readExecutionOrNull(executionId);
    if (execution == null || !execution.isTerminal) {
      final statusName = execution?.status.name ?? 'null';
      logger?.call(
        'engineering-review-gate-execution-not-terminal',
        {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'executionId': executionId,
          'status': statusName,
        },
      );
      return;
    }

    final reviewerResult = await executionStore.readResult(executionId);

    EngineeringReviewResult? reviewResult;
    // Default to the WIRE value of `changesRequired` (`changes_required`), never
    // a hand-typed literal: `ReviewVerdict.fromWire` is strict, and the string
    // 'changesRequired' is not a wire value, so a literal here would silently
    // fall through the fallback below and mis-type the verdict.
    String verdictWire = ReviewVerdict.changesRequired.wire;
    if (reviewerResult != null) {
      try {
        final sr = reviewerResult.structuredResult;
        final v = sr['verdict'];
        if (v is String && v.isNotEmpty) {
          verdictWire = v;
        }
        final r = sr['engineeringReviewResult'];
        if (r is Map<String, dynamic>) {
          try {
            reviewResult = EngineeringReviewResult.fromJson(
              Map<String, dynamic>.from(r),
            );
          } on Object catch (e) {
            logger?.call(
              'engineering-review-gate-embedded-result-unparseable',
              {
                'jobId': job.jobId,
                'workItemId': workItemId,
                'executionId': executionId,
                'error': '$e',
              },
            );
          }
        }
      } on Object catch (e) {
        logger?.call('engineering-review-gate-structured-result-unreadable', {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'executionId': executionId,
          'error': '$e',
        });
      }
      if (reviewResult == null) {
        final findings = <DesignFinding>[];
        try {
          final sr = reviewerResult.structuredResult;
          final f = sr['findings'];
          if (f is List) {
            for (final x in f) {
              if (x is Map<String, dynamic>) {
                try {
                  findings.add(
                    DesignFinding.fromJson(Map<String, dynamic>.from(x)),
                  );
                } on Object catch (e) {
                  logger?.call('engineering-review-gate-finding-unparseable', {
                    'jobId': job.jobId,
                    'workItemId': workItemId,
                    'executionId': executionId,
                    'error': '$e',
                  });
                }
              }
            }
          }
        } on Object catch (e) {
          logger?.call('engineering-review-gate-findings-unreadable', {
            'jobId': job.jobId,
            'workItemId': workItemId,
            'executionId': executionId,
            'error': '$e',
          });
        }
        final verdict = () {
          try {
            return ReviewVerdict.fromWire(verdictWire);
          } on Object catch (e) {
            logger?.call('engineering-review-gate-unknown-verdict', {
              'jobId': job.jobId,
              'workItemId': workItemId,
              'executionId': executionId,
              'verdictWire': verdictWire,
              'error': '$e',
            });
            return ReviewVerdict.changesRequired;
          }
        }();
        reviewResult = EngineeringReviewResult(
          reviewExecutionId: executionId,
          workItemId: workItemId,
          verdict: verdict,
          findings: findings,
          assessedDimensions: const [],
          createdAt: reviewerResult.completedAt,
          version: 1,
          reviewerRole: AgentRole.engineeringReviewer,
        );
      }
    } else {
      logger?.call('engineering-review-gate-missing-reviewer-result', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'executionId': executionId,
      });
      final verdict = ReviewVerdict.changesRequired;
      reviewResult = EngineeringReviewResult(
        reviewExecutionId: executionId,
        workItemId: workItemId,
        verdict: verdict,
        findings: const [],
        assessedDimensions: const [],
        createdAt: DateTime.now(),
        version: 1,
        reviewerRole: AgentRole.engineeringReviewer,
      );
    }

    // NO literal fallback. `_ActorIsNotSelfGuard` (`packages/workflow_engine`)
    // compares the reviewing actor's id against this producer id; a constant
    // placeholder can never collide with a real reviewer execution, so a
    // fallback would make the guard vacuous and no-self-approval unenforced.
    // The coordinator stamps the PRODUCING execution id onto the work item's
    // metadata when implementation completes
    // (`ExecutionCoordinator._completeSuccess`). Without it we cannot assert
    // independence, so log and leave the item in `reviewInProgress`.
    final producerActorId = item.metadata?['producerActorId'] as String?;
    if (producerActorId == null || producerActorId.isEmpty) {
      logger?.call('engineering-review-gate-missing-producer-actor', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'executionId': executionId,
      });
      return;
    }

    final question = reviewResult.verdict.isPassing
        ? 'Approve engineering review?'
        : 'Engineering review requires changes. Approve, reject, or request rework?';
    final recommendation = reviewResult.verdict.isPassing
        ? 'APPROVE'
        : 'CHANGES_REQUIRED';

    // Identify the REVIEWING actor by its own execution id — the producer
    // stamp above is the implementer's execution id, so the two sides of
    // `actorIsNotSelf()` are now both real and genuinely independent.
    final actor = WorkflowActor(
      actorId: executionId,
      actorType: ActorType.engineeringReviewer,
    );

    await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: HumanDecisionType.engineeringReview,
      question: question,
      options: const [
        HumanDecisionOption(optionId: 'approve', label: 'Approve'),
        HumanDecisionOption(optionId: 'reject', label: 'Reject'),
        HumanDecisionOption(optionId: 'rework', label: 'Rework'),
      ],
      recommendation: recommendation,
      blocking: true,
      metadata: {
        'engineeringReviewResult': reviewResult.toJson(),
        'reviewExecutionId': executionId,
        'reviewVerdict': reviewResult.verdict.wire,
      },
      actor: actor,
      extraContext: {
        'producerActorId': producerActorId,
        'reviewExecutionId': executionId,
        'reviewVerdict': reviewResult.verdict.wire,
      },
    );
  };
}

/// Fail-closed handling for an engineering-review job the scheduler refused to
/// dispatch because no produced artifact could be resolved.
///
/// The scheduler never runs a reviewer against the triage tree: with no artifact
/// its workload resolver returns `null` and the job surfaces in
/// `SchedulerTickResult.blockedArtifactMissing`. This turns that into a blocking
/// `engineeringReview` HumanDecision instead of silently advancing.
///
/// `agentCompleted` has NO edge to `waitingForHumanDecision`
/// (`work_item_transitions.dart`); the only path runs through `reviewInProgress`.
/// So this performs the same entry transition a running reviewer would
/// (`agentCompleted -> reviewInProgress`, orchestrator actor, carrying the
/// implementer's `agentResult` the `agentResultValid()` guard requires), then
/// raises the decision. No transition edge is added.
///
/// Idempotent: a retry finds the item already parked and returns.
Future<void> engineeringReviewMissingArtifact({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required Job job,
  required void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final workItemId = job.workItemId;
  final item = await workflowEngine.loadWorkItem(workItemId);

  if (item.state == WorkItemState.waitingForHumanDecision) {
    logger?.call('engineering-review-missing-artifact-already-parked', {
      'jobId': job.jobId,
      'workItemId': workItemId,
    });
    return;
  }

  if (item.state == WorkItemState.agentCompleted) {
    final implementer = await executionStore.latestExecutionForWorkItem(
      workItemId,
    );
    final implementerResult = implementer == null
        ? null
        : await executionStore.readResult(implementer.executionId);
    if (implementerResult == null) {
      // `agentResultValid()` needs the implementer's completed result; without
      // it the entry transition is refused. Forcing it would fabricate the very
      // evidence that guard exists to check, so this is a visible block.
      logger?.call(
        'engineering-review-missing-artifact-no-implementer-result',
        {
          'jobId': job.jobId,
          'workItemId': workItemId,
        },
      );
      return;
    }
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.reviewInProgress,
      trigger: TransitionTrigger.agentResult,
      actor: WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      context: {
        'agentAvailable': true,
        'capabilitiesMatch': true,
        'agentResult': implementerResult,
      },
    );
  } else if (item.state != WorkItemState.reviewInProgress) {
    logger?.call('engineering-review-missing-artifact-unexpected-state', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'state': item.state.name,
    });
    return;
  }

  // Same no-literal-fallback rule as the verdict path: the producer id is the
  // implementer's execution id, and `actorIsNotSelf()` needs both sides real.
  final producerActorId = item.metadata?['producerActorId'] as String?;

  await workflowEngine.requestHumanDecision(
    workItemId: workItemId,
    decisionType: HumanDecisionType.engineeringReview,
    question:
        'Engineering review cannot proceed: no implementation artifact was '
        'produced for this work item (no commit was found to review).',
    options: const [
      HumanDecisionOption(optionId: 'rework', label: 'Rework'),
      HumanDecisionOption(optionId: 'reject', label: 'Reject'),
    ],
    recommendation: 'REWORK',
    blocking: true,
    metadata: const {'missingArtifact': true},
    actor: WorkflowActor(
      actorId: 'orchestrator',
      actorType: ActorType.orchestrator,
    ),
    extraContext: {'producerActorId': producerActorId ?? ''},
  );

  logger?.call('engineering-review-missing-artifact.parked', {
    'jobId': job.jobId,
    'workItemId': workItemId,
  });
}
