import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import '../triage/lane_i_tick_hook.dart';

/// Resolves the workload an engineering reviewer must operate on: the revision
/// the IMPLEMENTER actually produced, never the triage/construction-time source.
///
/// ## IT CALLS THE INFLOW'S DISCRIMINATOR; IT DOES NOT RE-STATE IT
///
/// The answer is [producedCommitFor] — the scheduler's own function, over the
/// same durable rows, called from here rather than transcribed. Two rules for
/// "did this run produce something reviewable" is how a real commit gets sent
/// to the build queue while a reviewer gets sent to a revision nobody
/// committed, and the dependency needed to prevent it runs the right way round:
/// `apps/server` already depends on `packages/scheduler`, so sharing this
/// function inverts nothing.
///
/// What this function still owns — and what no shared function can assert — is
/// the MAPPING from that verdict to review's action: a workload when a commit
/// exists, `null` otherwise. `apps/server/test/inflow_vs_review_route_test.dart`
/// executes both mappings over the same rows and fails if they ever disagree.
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
/// `producerActorId`, no execution carrying it, an ambiguous match, or an
/// execution that produced no artifact. That is deliberate and fail-closed: the
/// scheduler then does not dispatch at all and reports the job in
/// `SchedulerTickResult.blockedArtifactMissing`, where
/// [engineeringReviewMissingArtifact] decides what happens next.
WorkloadResolver engineeringReviewWorkloadResolver({
  required WorkerStore workerStore,
  required String runtimeTypeId,
}) {
  return (job, item) async {
    final produced = await producedCommitFor(workerStore, item);
    switch (produced) {
      case CommitProduced(:final repositoryPath, :final commit):
        return SchedulerWorkload(
          repositoryPath: repositoryPath,
          startingRevision: commit,
          timeoutSeconds: 300,
          runtimeTypeId: runtimeTypeId,
        );
      case NoCommitProduced():
        return null;
    }
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

/// Whether the implementation lane's completion inflow will move [item] off
/// `agentCompleted` this tick, and — when it will not — why this gate is the
/// one that has to act.
typedef _InflowStandDown = ({bool owns, String why});

Future<_InflowStandDown> _implementationInflowOwns(
  WorkItem item,
  WorkerStore workerStore,
) async {
  try {
    final produced = await producedCommitFor(workerStore, item);
    final reWorkAttempt = DurableWorkflowEngine.readTriageAttempt(item) ?? 0;
    if (produced.isProduced) {
      return (
        owns: false,
        why:
            'the producer did leave a commit, so this item is not the '
            'inflow\'s case and there is still a real question for a human '
            'here',
      );
    }
    if (reWorkAttempt >= maxImplementationInflows) {
      return (
        owns: false,
        why:
            'the re-work discriminator already reads $reWorkAttempt, at or '
            'above the bound of $maxImplementationInflows automatic entries, '
            'so the implementation lane will not route it either and nobody '
            'else is left to act',
      );
    }
    return (owns: true, why: 'the implementation inflow will route it');
  } on Object catch (error) {
    // Every read above throws by design on unreadable durable state. A handler
    // that throws takes the whole `review` section of the tick with it, so the
    // fault is caught here and resolved to the CONSERVATIVE answer: park.
    return (
      owns: false,
      why:
          'this item\'s producer could not be read ($error), so it is not '
          'possible to say the implementation lane would take it. Parking is '
          'the side of the choice that cannot strand the item',
    );
  }
}

/// Fail-closed handling for an engineering-review job the scheduler refused to
/// dispatch because no produced artifact could be resolved.
///
/// The scheduler never runs a reviewer against the triage tree: with no artifact
/// its workload resolver returns `null` and the job surfaces in
/// `SchedulerTickResult.blockedArtifactMissing`. This is where that becomes
/// either a blocking `engineeringReview` HumanDecision or NOTHING AT ALL, and
/// which one it is depends on whether anything else can move the item.
///
/// ## WHY THIS STANDS DOWN FOR A NO-ARTIFACT PRODUCER
///
/// `agentCompleted` is `sched-impl`'s inflow source. When the producer left no
/// commit there is nothing to review, and `producedCommitFor` — the SAME
/// function this gate's own workload resolver calls — says so. Parking the item
/// at `waitingForHumanDecision` in that case does not fail closed, it fails
/// AWAY: it hands a question to a person whose only available answers (rework /
/// reject) are the wrong ones, for a defect that the implementation lane can
/// simply do.
///
/// It also made the outcome depend on `await` ordering. Inside one tick the
/// review tick's `blockedArtifactMissing` handler ran before
/// `implScheduler.tick()`, so the park won whenever it could reach the write at
/// all, and the inflow lost whenever the platform had recorded agent executions
/// to read. It won or lost on tick order, not on the work.
///
/// So the stand-down decides with the inflow's own rule, and the composition
/// root runs `implScheduler.tick()` FIRST. Either order then lands the item in
/// the same place; `apps/server/test/implementation_inflow_tick_order_test.dart`
/// runs both orders against both schedulers and asserts it.
///
/// ## THE ONE CASE THAT IS NOT A STAND-DOWN
///
/// `maxImplementationInflows`. When the shared re-work discriminator is already
/// at the bound, the inflow will NOT route this item — the implementation lane
/// has already had its budget — so standing down would leave the item at
/// `agentCompleted` for ever with nobody acting on it. That is the case the
/// human gate exists for, and the stand-down checks the SAME number so the two
/// can never disagree about whether the budget is spent.
///
/// ## THE TRANSITION, WHEN IT DOES PARK
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
  required WorkerStore workerStore,
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

  // THE STAND-DOWN. Scoped to `agentCompleted`, the one state the inflow reads,
  // so this can never suppress a park for an item that is somewhere else.
  //
  // Every read here is guarded: the inflow's own discriminator and the
  // discriminator read below BOTH throw on unreadable durable state, and a
  // handler that throws would take the whole `review` section of the tick with
  // it — every other blocked job in that section unreported. An unreadable
  // answer falls through to the fail-closed park, which is the conservative
  // side of the choice: this handler's job is to stop something being stranded.
  if (item.state == WorkItemState.agentCompleted) {
    final standDown = await _implementationInflowOwns(item, workerStore);
    if (standDown.owns) {
      logger?.call('engineering-review-missing-artifact-stands-down', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'reason':
            'the producer left no artifact, so there is nothing to review. '
            'The implementation lane\'s completion inflow owns this item and '
            'routes it for another pass; parking it here would pre-empt that '
            'and put an item that can be implemented in front of a human who '
            'can only rework or reject it',
      });
      return;
    }
    logger?.call('engineering-review-missing-artifact-parking', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'why': standDown.why,
    });
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
