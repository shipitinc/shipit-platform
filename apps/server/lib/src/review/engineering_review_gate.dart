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
  required int timeoutSeconds,
}) {
  return (job, item) async {
    final produced = await producedCommitFor(workerStore, item);
    switch (produced) {
      case CommitProduced(:final repositoryPath, :final commit):
        return SchedulerWorkload(
          repositoryPath: repositoryPath,
          startingRevision: commit,
          // INJECTED, not declared here, and that is the whole point.
          //
          // This used to be a literal `300` typed into this file with no
          // justification anywhere in the repository — and it was LESS THAN THE
          // STATED MINIMUM for the role: an operator reports a review run here,
          // through opencode, at 15–30 minutes, so every review this resolver
          // built a workload for was killed before it could finish. A budget
          // below the observed floor is not a ceiling; it is a coin toss that
          // always lands on killed.
          //
          // The number now lives in ONE place — `AgentExecutionBudgets` in the
          // composition root — and is required rather than optional so this
          // signature cannot compile without the caller naming it. That is the
          // difference between a number someone chose and a number someone
          // typed: a required argument has to be answered by someone reading
          // the call site, and there is exactly one call site.
          //
          // PROVISIONAL: see `AgentExecutionBudgets` for where the value comes
          // from and for the measurement that should replace it.
          timeoutSeconds: timeoutSeconds,
          runtimeTypeId: runtimeTypeId,
        );
      case NoCommitProduced():
        return null;
    }
  };
}

/// WHY THERE IS NO "NO VERDICT" MEMBER OF [ReviewVerdict]
///
/// This gate used to answer "the reviewer returned nothing" with
/// [ReviewVerdict.changesRequired], in three places: a wire default before any
/// result had been read, a fallback when `ReviewVerdict.fromWire` threw, and a
/// literal when there was no reviewer result at all. Three work items were
/// sitting at `waitingForHumanDecision` reading *"Engineering review requires
/// changes"* and *"WHAT WE SUGGEST: CHANGES_REQUIRED"* for code no reviewer had
/// ever assessed.
///
/// The tempting fix is a fifth enum constant — `ReviewVerdict.notAssessed`, say.
/// It is wrong, and the type's shape is why. [ReviewVerdict] is a CLOSED set of
/// four assessments; every member claims a reviewer looked at work and reached
/// that conclusion, and every reader downstream (`isPassing`, the
/// APPROVE/CHANGES_REQUIRED recommendation, `HumanDecisionRouting`) is entitled
/// to treat each member as exactly that claim. A member meaning "nobody looked"
/// would be a member that lies about its own contract: every one of those readers
/// would have to be taught to distrust it, which is a wider and more dangerous
/// change than this one, and it lives in `packages/platform_contracts`, shared by
/// every product surface rather than by this gate.
///
/// So the type keeps its meaning and the DECISION PATH becomes unreachable
/// without a real verdict. [ReviewVerdict] cannot represent "no verdict"
/// honestly, therefore nothing downstream of a missing verdict is ever entered:
/// [engineeringReviewTickHandler] reads a verdict or it records an absence and
/// returns, and the `requestHumanDecision` call below is reachable only from a
/// branch holding a [ReviewVerdict] a reviewer actually produced.
///
/// "No verdict" is represented here, in this file, as [_NoVerdict] — a value that
/// exists only to be turned into a durable record and a log line. It is never
/// converted into a verdict, never persisted on a decision, and never shown to a
/// human as something to adjudicate.
enum _NoVerdictCause {
  /// The reviewer execution hit its budget without producing anything.
  reviewerTimedOut('reviewer_timed_out'),

  /// The reviewer execution ended in a non-assessing terminal state (failed,
  /// cancelled, orphaned) and wrote no result.
  reviewerExecutionFailed('reviewer_execution_failed'),

  /// The reviewer execution completed but the store holds no agent result for it.
  reviewerResultMissing('reviewer_result_missing'),

  /// A result exists and parses, but carries no verdict at all.
  verdictAbsent('verdict_absent'),

  /// A verdict string exists and is not one of [ReviewVerdict]'s wire values.
  verdictUnreadable('verdict_unreadable'),

  /// The result's structured payload could not be read.
  structuredResultUnreadable('structured_result_unreadable');

  const _NoVerdictCause(this.wire);

  final String wire;
}

/// "There is no verdict", together with the cause that says WHY.
///
/// This is the counterpart [ReviewVerdict] cannot be. It exists so that "we
/// could not ask" and "the answer is changes" stop sharing a value.
class _NoVerdict {
  const _NoVerdict(this.cause, this.detail);

  final _NoVerdictCause cause;
  final String detail;
}

/// Exactly one of the two fields is non-null.
typedef _VerdictRead = ({EngineeringReviewResult? result, _NoVerdict? absence});

/// Which REVIEWER-side absence explains a missing verdict.
///
/// The split is the operator-facing point of requirement "tell a slow review
/// from a broken one": a budget that ran out and a crash are different incidents
/// with different remedies, and an unreadable verdict is neither — it is a
/// reviewer that answered in a dialect this build does not speak.
///
/// The wording matched is the coordinator's own (`_expireExecution` /
/// `_neverEmittedTerminalEvent`): both budget-expiry reasons contain "budget",
/// and `interrupted` is the status a timed-out session settles at.
_NoVerdictCause _absenceCauseFor(AgentExecution execution) {
  final reason = (execution.reason ?? '').toLowerCase();
  final ranOutOfBudget =
      reason.contains('budget') ||
      reason.contains('timeout') ||
      reason.contains('timed out') ||
      reason.contains('terminal event');
  if (ranOutOfBudget || execution.status == AgentSessionStatus.interrupted) {
    return _NoVerdictCause.reviewerTimedOut;
  }
  return switch (execution.status) {
    AgentSessionStatus.completed => _NoVerdictCause.reviewerResultMissing,
    _ => _NoVerdictCause.reviewerExecutionFailed,
  };
}

/// Supplies the five [DesignFinding] fields that are run identity rather than
/// review content, and ONLY those, so a reviewer that reported what it
/// observed does not lose the finding to a missing bookkeeping field.
///
/// ## WHY THIS EXISTS
///
/// [engineeringReviewInstruction] documents the fields a reviewer legitimately
/// owns — severity, dimension, evidence, requiredCorrection, affectedSurface,
/// category. It cannot document `findingId`, `revisionId`, `reviewExecutionId`,
/// `createdAt` or `version`, because a reviewer has no way to know its own
/// `reviewExecutionId` and inventing one would be fabricated provenance. But
/// [DesignFinding.fromJson] requires all eleven, and a finding missing any of
/// them used to be DROPPED with a log line — so the prompt could describe a
/// finding the gate was guaranteed to throw away.
///
/// That is a silent loss of exactly the evidence an operator needs: the reason
/// `recommendation` says what it says. It is fixed by completing the five from
/// the run this gate is already holding, not by inventing them.
///
/// ## EVERY VALUE IS READ, NOT GUESSED
///
///  * `reviewExecutionId` — the reviewing execution, the same id already stamped
///    on the enclosing [EngineeringReviewResult].
///  * `revisionId` — the reviewer's own `workspace.startingRevision`, which is
///    the commit the workload resolver handed it
///    (`engineeringReviewWorkloadResolver`), i.e. the revision actually under
///    review. An empty string when the execution carries no workspace, which
///    still parses and is still visibly empty rather than wrong.
///  * `createdAt` — the reviewer's result completion, the same instant the
///    enclosing result uses.
///  * `version` — `1`, matching the enclosing result's own literal.
///  * `findingId` — derived from the execution id and the finding's position,
///    so it is stable for a given run and distinguishes two findings from one
///    review. It is an identifier for a row that exists, not a claim about
///    anything.
///  * `category` — [DesignFindingCategory.feasibility] when the reviewer gave
///    none. That is the classification b1's own engineering-review fixtures use
///    and it says only "this came out of an engineering review". The enum is a
///    DESIGN-review taxonomy (accessibility, design_system_compliance, …) and
///    an engineering reviewer has no honest choice among eight design
///    categories, so asking it to pick one would be asking for a meaningless
///    answer. A reviewer that supplies a real category keeps it.
///
/// ## AND NOTHING THE REVIEWER SAID IS TOUCHED
///
/// Only ABSENT keys are filled. A reviewer that supplies its own identity keeps
/// it, and `resolvedByRevisionId` is never stamped — that field means something
/// has been fixed, which only a later run may assert.
Map<String, dynamic> _withReviewRunIdentity(
  Map<String, dynamic> finding, {
  required AgentExecution execution,
  required String executionId,
  required DateTime createdAt,
  required int index,
}) {
  final completed = finding;
  completed.putIfAbsent('findingId', () => '$executionId-f$index');
  completed.putIfAbsent(
    'revisionId',
    () => execution.workspace.startingRevision ?? '',
  );
  completed.putIfAbsent('reviewExecutionId', () => executionId);
  completed.putIfAbsent('createdAt', () => createdAt.toIso8601String());
  completed.putIfAbsent('version', () => 1);
  completed.putIfAbsent(
    'category',
    () => DesignFindingCategory.feasibility.wire,
  );
  return completed;
}

/// Reads the reviewer's verdict, or says why there is none.
///
/// Everything this returns that is not an [EngineeringReviewResult] is an
/// absence, and an absence is never turned into a verdict on the way out. The
/// previous version had three exits that all produced `changesRequired`; this has
/// none, and that is the whole invariant.
_VerdictRead _readReviewVerdict({
  required Job job,
  required String workItemId,
  required String executionId,
  required AgentExecution execution,
  required AgentResult? reviewerResult,
  void Function(String message, Map<String, dynamic> context)? logger,
}) {
  if (reviewerResult == null) {
    return (
      result: null,
      absence: _NoVerdict(
        _absenceCauseFor(execution),
        'the reviewer execution reached ${execution.status.name} without '
        'writing an agent result'
        '${execution.reason == null ? '' : ' (${execution.reason})'}',
      ),
    );
  }

  final Map<String, dynamic> structured;
  try {
    structured = reviewerResult.structuredResult;
  } on Object catch (e) {
    return (
      result: null,
      absence: _NoVerdict(
        _NoVerdictCause.structuredResultUnreadable,
        'the reviewer result could not be read: $e',
      ),
    );
  }

  // An embedded, fully-formed review result is the richest thing a reviewer can
  // hand back and it carries its own verdict, so it is read first. A parse
  // failure falls THROUGH to the wire+findings path rather than aborting: that
  // path can still produce an honest verdict from the same payload, and
  // refusing to look would be its own kind of fabrication.
  final embedded = structured['engineeringReviewResult'];
  if (embedded is Map) {
    try {
      return (
        result: EngineeringReviewResult.fromJson(
          Map<String, dynamic>.from(embedded),
        ),
        absence: null,
      );
    } on Object catch (e) {
      logger?.call('engineering-review-gate-embedded-result-unparseable', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'executionId': executionId,
        'error': '$e',
      });
    }
  }

  // NO DEFAULT. There is no verdict here yet, and that is a fact about the
  // reviewer rather than a verdict.
  final rawVerdict = structured['verdict'];
  final verdictWire = rawVerdict is String && rawVerdict.isNotEmpty
      ? rawVerdict
      : null;
  if (verdictWire == null) {
    return (
      result: null,
      absence: _NoVerdict(
        _NoVerdictCause.verdictAbsent,
        'the reviewer returned a result carrying no verdict',
      ),
    );
  }

  // Requirement 4. An unreadable verdict wire is NOT a review verdict: it is a
  // string this build does not recognise as one. It used to become
  // `changesRequired`, which is the most dangerous of the three sites precisely
  // because it reads like an ordinary parse fallback — a reviewer that answered
  // `CHANGES_REQUIRED`, or `needs_work`, or shipped a typo would have been
  // reported to the operator as a reviewer having found problems.
  final ReviewVerdict verdict;
  try {
    verdict = ReviewVerdict.fromWire(verdictWire);
  } on Object catch (e) {
    return (
      result: null,
      absence: _NoVerdict(
        _NoVerdictCause.verdictUnreadable,
        "'$verdictWire' is not a review verdict ($e)",
      ),
    );
  }

  final findings = <DesignFinding>[];
  try {
    final f = structured['findings'];
    if (f is List) {
      for (var i = 0; i < f.length; i++) {
        final x = f[i];
        if (x is Map) {
          try {
            findings.add(
              DesignFinding.fromJson(
                _withReviewRunIdentity(
                  Map<String, dynamic>.from(x),
                  execution: execution,
                  executionId: executionId,
                  createdAt: reviewerResult.completedAt,
                  index: i,
                ),
              ),
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
    // A finding that cannot be read is dropped from the list, which understates
    // what the reviewer found. That is a lesser evil than inventing a verdict,
    // and it is loud rather than silent.
    logger?.call('engineering-review-gate-findings-unreadable', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'executionId': executionId,
      'error': '$e',
    });
  }

  return (
    result: EngineeringReviewResult(
      reviewExecutionId: executionId,
      workItemId: workItemId,
      verdict: verdict,
      findings: findings,
      assessedDimensions: const [],
      createdAt: reviewerResult.completedAt,
      version: 1,
      reviewerRole: AgentRole.engineeringReviewer,
    ),
    absence: null,
  );
}

/// Makes the absence durable on the reviewer's own execution before returning.
///
/// A log line is not a record: it leaves with the process, and the next operator
/// to open this item needs to tell a slow review from a broken one without
/// reading logs. The event is appended to the reviewer's execution timeline —
/// where its `AgentExecution`, its `AgentResult` and its run page already live —
/// carrying the cause and the detail.
///
/// It is recorded as [AgentEventType.warning], not `executionFailed`: a reviewer
/// that ended on `end_turn` with an unreadable payload did NOT fail, and
/// stamping a failure onto it would be the same fabrication this gate exists to
/// stop, one layer down.
///
/// A store that refuses the write must not take the tick down with it: the
/// decision is already NOT being raised, and the log line below still says why.
Future<void> _recordNoVerdict({
  required ExecutionStore executionStore,
  required Job job,
  required String workItemId,
  required String executionId,
  required _NoVerdict absence,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final detail = {
    'jobId': job.jobId,
    'workItemId': workItemId,
    'executionId': executionId,
    'cause': absence.cause.wire,
    'why': absence.detail,
    'decision': 'not raised; no reviewer returned a verdict',
  };
  logger?.call('engineering-review-gate-no-verdict', detail);

  try {
    final prior = await executionStore.readEvents(executionId);
    final sequence =
        prior.fold<int>(0, (max, e) => e.sequence > max ? e.sequence : max) + 1;
    final now = DateTime.now().toUtc();
    await executionStore.appendEvent(
      AgentEventRecord(
        eventId: 'no-verdict-$executionId-${now.microsecondsSinceEpoch}',
        executionId: executionId,
        workItemId: workItemId,
        sequence: sequence,
        type: AgentEventType.warning,
        occurredAt: now,
        payload: {
          'reviewGate': 'no_verdict',
          'cause': absence.cause.wire,
          'detail': absence.detail,
        },
      ),
    );
  } on Object catch (e) {
    logger?.call('engineering-review-gate-no-verdict-record-failed', {
      ...detail,
      'error': '$e',
    });
  }
}

/// Builds a tick handler for engineering review jobs. When the reviewer
/// execution reaches a terminal state, this raises a blocking
/// `engineeringReview` HumanDecision to move `reviewInProgress` to
/// `waitingForHumanDecision`.
///
/// ## IT ONLY RAISES A DECISION FOR A VERDICT A REVIEWER ACTUALLY RETURNED
///
/// If the reviewer produced no verdict — it ran out of budget, it crashed, its
/// result never landed, or it answered in something this build cannot parse —
/// this records why and returns, leaving the item at `reviewInProgress`.
///
/// Leaving it at `reviewInProgress` is the RETRYABLE state, and it is left there
/// rather than at `waitingForHumanDecision` because that state is the only thing
/// this gate used to reach and it is terminal with respect to the item's own
/// budget: nothing re-dispatches a `blockedHumanDecisionId`, so parking an
/// unassessed item there converts a review that can still be retried into a
/// question a human has to answer about work nobody read. The reviewer job's own
/// bounded `maxAttempts` (`engineeringReviewDefinition`) is the retry mechanism
/// and this gate does not duplicate, pre-empt or reset it.
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

    // THE INVARIANT, IN ONE LINE. Either a reviewer returned a verdict, or this
    // gate records why it did not and leaves the item alone. There is no third
    // branch, and no default for `ReviewVerdict` anywhere below this line.
    final read = _readReviewVerdict(
      job: job,
      workItemId: workItemId,
      executionId: executionId,
      execution: execution,
      reviewerResult: reviewerResult,
      logger: logger,
    );
    final absence = read.absence;
    if (absence != null) {
      await _recordNoVerdict(
        executionStore: executionStore,
        job: job,
        workItemId: workItemId,
        executionId: executionId,
        absence: absence,
        logger: logger,
      );
      return;
    }
    final reviewResult = read.result!;

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
