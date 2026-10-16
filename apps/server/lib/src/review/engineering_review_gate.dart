import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowTransitionRejectedException;
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
/// decision is already being raised or deliberately NOT raised, and the log line
/// below still says why.
///
/// ## `retryOwed` AND `reviewCompleted` ARE TWO DIFFERENT FACTS
///
/// The gate raises when NO RETRY IS OWED. That is not the same question as
/// "did the review finish", and conflating the two is the whole defect: a
/// PERMANENT failure settles its execution `failed`/`interrupted`, so it never
/// reaches `completed`, and an item waiting on a permanent failure is not
/// retried by anything. Recorded as two booleans here because an operator
/// reading the timeline needs both — "a retry is still owed" says the queue is
/// handling it, and "the review completed" says whether the reviewer got to say
/// anything at all.
Future<void> _recordNoVerdict({
  required ExecutionStore executionStore,
  required Job job,
  required String workItemId,
  required String executionId,
  required _NoVerdict absence,
  required bool reviewCompleted,
  required bool retryOwed,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final detail = {
    'jobId': job.jobId,
    'workItemId': workItemId,
    'executionId': executionId,
    'cause': absence.cause.wire,
    'why': absence.detail,
    'jobState': job.state.wire,
    'retryOwed': retryOwed,
    // Says WHAT WAS DONE about it, because "no verdict" on its own is exactly
    // the sentence that left four items invisible: the reader cannot tell a gate
    // that is handling this from a gate that dropped it.
    //
    // AND ONLY WHAT IS ALREADY TRUE WHEN THIS LINE IS WRITTEN. When no retry is
    // owed, the decision is raised by the CALLER, after this record, and
    // `raiseVerdictAbsentDecision` has three outcomes that write nothing
    // (`alreadyPending`, `producerIdentityUnreadable`, `refused`). A sentence
    // emitted here claiming a decision was raised would therefore be false on
    // every one of them — the same class of statement this gate exists to end,
    // one layer down, and the exact sentence removed at a different layer. So
    // this line claims the absence record and nothing else; the caller logs
    // what the raise actually did.
    'decision': !retryOwed
        ? 'no decision claimed by this record. It states the absence, which is '
              'durable on the reviewer\'s execution timeline; the verdict-less '
              'decision is handled straight afterwards and reports its own '
              'outcome under engineering-review-gate-no-verdict-decision'
        : 'not raised; the reviewer job is still owed a retry inside its bounded '
              'maxAttempts, so the item is left retryable at review_in_progress',
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
          'reviewCompleted': reviewCompleted,
          'retryOwed': retryOwed,
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

/// The `metadata` key under which the verdict-less decision records WHY there
/// is no verdict and WHICH run produced none.
///
/// ## WHY IT IS A KEY AND NOT A FLAG, AND WHY IT IS NOT THE STALL'S KEY
///
/// `stalledWorkItemMetadataKey` (`'schedulerStall'`, in
/// `apps/server/lib/src/triage/stalled_work_item_gate.dart`) is the other way
/// this repository stops a work item from moving with nothing on screen, and the
/// two gates raise the same `HumanDecisionType.engineeringReview` because
/// `reviewInProgress -> waitingForHumanDecision` is guarded by
/// `blockingHumanDecisionPendingOfType([engineeringReview])` and no other type is
/// reachable from there. So type alone cannot tell them apart, and anything that
/// renders or reads a decision must be able to.
///
/// They differ in cause, in who acts, and in what acting does:
///
/// | | supersession stall (b8) | verdict-less review (this file) |
/// |---|---|---|
/// | cause | the lane refused to launch; no execution ever started | a reviewer DID run, to completion, and its output could not be read |
/// | reviewer output | none exists | prose exists and is quoted in the question |
/// | operator action | find why this item cannot begin an execution at all, then start it again | read what the reviewer wrote, then have it built and reviewed again |
/// | recoverable by | moving the item — any action lifts it by evidence | resolving the decision: `rework` re-runs the work, `cancel` stops it |
///
/// Four further structural differences keep them apart on any surface that
/// renders `question`, `recommendation` or the option labels, which is all
/// `DecisionView` carries: the metadata key, the opening sentence of the
/// question, the `recommendation` string, and the option labels. Asserted
/// together in
/// `apps/server/test/engineering_review_verdict_absent_decision_test.dart`.
const String reviewVerdictAbsentMetadataKey = 'reviewVerdictAbsent';

/// The ONLY choices a verdict-less decision may be resolved with.
///
/// `HumanDecisionRouting.targetFor(engineeringReview, …)` routes `approve` to
/// `reviewApproved` and `reject` to `reviewRejected`. Both are ASSESSMENTS, and
/// both would be fabrications here: `reviewApproved` is the state that admits a
/// change to the rest of the pipeline on a review nobody concluded, and
/// `reviewRejected` records a reviewer having rejected work for reasons no
/// reviewer gave. `rework` routes to `implementationReady` and `cancel` to
/// `cancelled`, and neither says anything at all about the work's quality — one
/// runs it again, the other stops it.
///
/// `resolveDecision` takes a `HumanDecisionChoice` off the wire and never checks
/// it against the decision's own `options`, so "we did not offer it" would not by
/// itself hold. [verdictAbsentChoiceIsResolvable] is checked at the resolution
/// path for exactly this decision.
const Set<HumanDecisionChoice> verdictAbsentResolvableChoices = {
  HumanDecisionChoice.rework,
  HumanDecisionChoice.cancel,
};

/// Whether [decision] is a verdict-less decision raised by this file.
///
/// A structural test on the record, not on a field the caller can set loosely:
/// the key is written by [raiseVerdictAbsentDecision] alongside the cause and the
/// reviewer's own prose, and its presence is what the resolution path keys on.
/// A decision that carries a `reviewVerdict` and this key at once is refused —
/// see [verdictAbsentChoiceIsResolvable].
bool isVerdictAbsentDecision(HumanDecision decision) =>
    decision.metadata?[reviewVerdictAbsentMetadataKey] != null;

/// Whether [choice] may resolve [decision].
///
/// The check is scoped to verdict-less decisions deliberately. Widening it to
/// "every choice must be one of the decision's options" would be a change to the
/// behaviour of every lifecycle gate in the platform, which is not this lane's
/// to make and is not what decision
/// `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` asked for. What it asked for is that a
/// decision carrying no verdict cannot be turned into one, and that is scoped.
bool verdictAbsentChoiceIsResolvable(
  HumanDecision decision,
  HumanDecisionChoice choice,
) {
  if (!isVerdictAbsentDecision(decision)) return true;
  if (decision.metadata?['reviewVerdict'] != null) {
    // Unreachable by construction — [raiseVerdictAbsentDecision] never writes
    // one — and refused anyway rather than trusted, because a row that claims a
    // verdict AND a verdict-less marker is exactly the shape that must not be
    // resolvable as though a reviewer had spoken.
    return false;
  }
  return verdictAbsentResolvableChoices.contains(choice);
}

/// The `recommendation` the verdict-less decision carries.
///
/// Deliberately not `APPROVE`, not `CHANGES_REQUIRED`, and not `REWORK` — the
/// last one is what the supersession stall gate carries, and two questions that
/// differ in cause must not share the one line the operator reads under
/// "WHAT WE SUGGEST". A suggestion that begins with the words NO VERDICT cannot
/// be skimmed as an assessment by anyone, including a screen reader announcing
/// the label on its own.
const String verdictAbsentRecommendation =
    'NO VERDICT — READ WHAT THE REVIEWER WROTE, THEN SEND THE WORK BACK';

/// The same decision for a review that did NOT finish.
///
/// ## WHY IT CANNOT BE [verdictAbsentRecommendation]
///
/// That line's whole content is an instruction: read what the reviewer wrote.
/// For a review that crashed on an ACP timeout there is nothing to read — the
/// execution never wrote a result, so `reviewProse` is null and the question
/// says so in its own section. An operator told to go and read prose that does
/// not exist is being pointed at an absence, which is a different mistake from
/// the one this file exists to end rather than a smaller version of it.
///
/// It is a SEPARATE constant rather than a branch inside one string, because this
/// is the one field a surface renders on its own under "WHAT WE SUGGEST": a
/// concatenation would read as two sentences and hide the half that applies.
const String verdictAbsentReviewFailedRecommendation =
    'NO VERDICT — THE REVIEW DID NOT FINISH; FIX THE FAILURE, THEN SEND THE '
    'WORK BACK';

/// The `recommendation` a verdict-less decision carries, chosen by whether the
/// review reached a terminal state on its own.
///
/// Both constants lead with the literal `NO VERDICT`, neither is a
/// [ReviewVerdict] wire value, and neither is the stall gate's `REWORK`, so the
/// anti-fabrication property asserted at
/// `apps/server/test/engineering_review_never_fabricates_verdict_test.dart`
/// holds identically on both paths.
String verdictAbsentRecommendationFor({required bool reviewCompleted}) =>
    reviewCompleted
    ? verdictAbsentRecommendation
    : verdictAbsentReviewFailedRecommendation;

/// The two options. Same `optionId`s the routing table understands and the stall
/// gate uses, different words, and neither one is pre-marked `recommended`:
/// there is no better answer here, and highlighting one would be the platform
/// nudging an operator toward a judgement it has no basis for.
const List<HumanDecisionOption> verdictAbsentOptions = [
  HumanDecisionOption(
    optionId: 'rework',
    label: 'Build it again and review it again',
    description:
        'No reviewer assessed this. Send it back to be implemented and '
        'reviewed from scratch.',
  ),
  HumanDecisionOption(
    optionId: 'cancel',
    label: 'Abandon this work item',
    description: 'Stop working on this. The review and its record are kept.',
  ),
];

/// The one sentence chain an operator reads, plus the reviewer's own words.
///
/// ## EVERY SENTENCE HERE IS A REFUSAL TO BE MISREAD
///
/// * It opens with the literal words `NO VERDICT` and says, in terms, that
///   nothing was assessed — no approval, no request for changes, no findings.
/// * It separates "the review PROCESS succeeded" from "the review CONCLUDED
///   something", which is the exact conflation that produced the four invisible
///   items.
/// * It labels the reviewer's prose as prose and says it has not been
///   interpreted, so a reviewer that wrote something assessment-shaped in
///   English cannot be read back as having returned a verdict.
/// * It names the two actions and says plainly that neither is a verdict.
///
/// ## AND IT NEVER CLAIMS A REVIEW RAN THAT DID NOT
///
/// The sentence separating PROCESS from CONCLUSION used to be hardcoded to "the
/// engineering review ran to completion", which was true for the four parked
/// items and false for every failure this gate now also answers. Telling an
/// operator that a reviewer which died on an ACP timeout "ran to completion" is
/// the same class of statement as inventing its verdict: a confident sentence
/// about a fact nobody established. [reviewCompleted] selects the sentence
/// instead of it being assumed.
///
/// Takes the facts, not the file-private [_NoVerdict]: this is the operator-facing
/// text of a durable record, and its inputs are two strings and an id.
String verdictAbsentQuestion({
  required String cause,
  required String detail,
  required String executionId,
  required String? producerExecutionId,
  required String? reviewProse,
  required bool reviewCompleted,
}) {
  final prose = (reviewProse ?? '').trim();
  final buffer = StringBuffer()
    ..writeln('NO VERDICT. Nothing has been assessed on this work item.')
    ..writeln()
    ..writeln(
      reviewCompleted
          ? 'The engineering review ran to completion and this build could not '
                'read a review verdict from what it returned. So there is no '
                'approval and no request for changes here, and no findings have '
                'been accepted or rejected — not because a reviewer found none, '
                'but because no reviewer produced a verdict to act on. The review '
                'PROCESS succeeded; that is not the same as the review CONCLUDING '
                'anything.'
          : 'The engineering review did not finish, and this build could not '
                'read a review verdict from what it returned. So there is no '
                'approval and no request for changes here, and no findings have '
                'been accepted or rejected — not because a reviewer found none, '
                'but because no reviewer reached a conclusion to act on. The '
                'review PROCESS did not succeed either; nothing will retry it, '
                'which is why this is in front of you rather than waiting.',
    )
    ..writeln()
    ..writeln('  cause:     $cause')
    ..writeln('  detail:    $detail')
    ..writeln('  reviewer:  $executionId')
    ..writeln(
      '  reviewed:  ${producerExecutionId == null || producerExecutionId.isEmpty ? 'an implementation whose execution id is not recorded' : producerExecutionId}',
    )
    ..writeln();

  if (prose.isEmpty) {
    buffer.writeln(
      'The reviewer wrote no summary either, so there is nothing of its own to '
      'read here.',
    );
  } else {
    buffer
      ..writeln(
        'What the reviewer actually wrote follows, verbatim. It is the '
        "reviewer's own prose. It has NOT been read as a verdict and nothing in "
        'it has been interpreted as one:',
      )
      ..writeln()
      ..writeln('---')
      ..writeln(prose)
      ..writeln('---');
  }

  buffer
    ..writeln()
    ..writeln(
      'Choose "Build it again and review it again" to send this item back to be '
      'implemented and reviewed from scratch, or "Abandon this work item" to '
      'stop it and keep the record. Neither answer approves this change and '
      'neither is a review verdict, because no reviewer produced one.',
    );
  return buffer.toString();
}

/// The structured facts, kept beside the prose so a surface can render them
/// without parsing English.
///
/// Deliberately carries NO `reviewVerdict` and NO `engineeringReviewResult`:
/// those two keys are what `readReviewVerdictProvenance` and every downstream
/// reader treat as "a reviewer assessed this", and writing either here — even
/// as null — is the first step of a row that later reads as an assessment. The
/// absence is named by `cause` and by the key it hangs under, which is what
/// [isVerdictAbsentDecision] and [verdictAbsentChoiceIsResolvable] read.
///
/// [jobFailure] is the REVIEW JOB's own record, not a reviewer's opinion: why
/// the run ended and how much of its budget was spent. It is the only place the
/// worker-side text (`AgpTransportException: ACP request timed out`) survives —
/// the coordinator composes its own [AgentExecution.reason], and the raw failure
/// detail lives on `JobFailure.reason`. An operator deciding between `rework` and
/// `cancel` needs that text: it is the difference between "the reviewer was slow"
/// and "the reviewer could not be reached at all".
Map<String, dynamic> verdictAbsentMetadata({
  required String cause,
  required String detail,
  required String executionId,
  required String? producerActorId,
  required String? reviewProse,
  required bool reviewCompleted,
  Map<String, dynamic>? jobFailure,
}) => {
  reviewVerdictAbsentMetadataKey: {
    'verdictRecorded': false,
    'cause': cause,
    'detail': detail,
    'reviewExecutionId': executionId,
    'reviewedRevisionExecutionId': producerActorId,
    // Says whether the reviewer got to the end of its own turn. Distinct from
    // `cause`, which says why there is no verdict: a `verdict_absent` on a
    // COMPLETED review and a `reviewer_execution_failed` on one that died are
    // both absences, and an operator needs to tell them apart before choosing
    // between rework and cancel.
    'reviewCompleted': reviewCompleted,
    // Carried so a surface can show how much the reviewer actually said. Null
    // is a real answer here: "it wrote nothing" is what the operator needs to
    // see, and it is different from "its prose is not readable here".
    'reviewProsePresent': (reviewProse ?? '').trim().isNotEmpty,
    if (jobFailure != null) 'reviewJobFailure': jobFailure,
  },
  // `readReviewVerdictProvenance` reads this key to find the reviewer run when
  // classifying a decision, and it is what makes "set aside and re-review"
  // available on a verdict-less decision that carried no prose at all.
  'reviewExecutionId': executionId,
};

/// What raising the verdict-less decision did with one work item.
enum VerdictAbsentDecisionOutcome {
  /// A blocking decision is now attached to the work item.
  raised,

  /// The item is already parked behind a pending decision of this type. The
  /// engine's own `requestHumanDecision` idempotency returned it, so a repeated
  /// tick did not mint a second question.
  alreadyPending,

  /// No producer identity is recorded, and `actorIsNotSelf()` — which
  /// `reviewInProgress -> waitingForHumanDecision` carries — FAILS CLOSED
  /// without one. Nothing is written: the absence record and the log line are
  /// already durable, and inventing an identity to get through the guard would
  /// be the same fabrication one layer up.
  producerIdentityUnreadable,

  /// The engine refused the gate entry. The item is left exactly where it was
  /// and still needs a person; this is a visible block, not a quiet one.
  refused,
}

/// The sentence that states what raising the verdict-less decision ACTUALLY did
/// with one work item.
///
/// ## ONLY `raised` MAY CLAIM THAT SOMETHING WAS RAISED
///
/// The other three outcomes write nothing, and each has to say so in the same
/// words a reader can grep. A log line that said "raised" on a path that raised
/// nothing would be the false-state class this file exists to eliminate, one
/// layer below the reviewer verdict — so the claim is made by exactly one branch
/// and the three write-nothing branches each carry `not raised` plus what the
/// item is left needing.
String verdictAbsentDecisionSentence(VerdictAbsentDecisionOutcome outcome) {
  switch (outcome) {
    case VerdictAbsentDecisionOutcome.raised:
      return 'raised a verdict-less engineering review decision: it asserts no '
          'verdict, states whether the review finished at all, and offers only '
          'rework and cancel';
    case VerdictAbsentDecisionOutcome.alreadyPending:
      return 'not raised by this tick; the item is already parked behind a '
          'pending engineeringReview decision, so a repeated tick did not mint '
          'a second question';
    case VerdictAbsentDecisionOutcome.producerIdentityUnreadable:
      return 'not raised; the producer identity is unreadable, so '
          'actorIsNotSelf() fails closed. Nothing was written and nothing was '
          'fabricated to get past the guard that refused it';
    case VerdictAbsentDecisionOutcome.refused:
      return 'not raised; the engine refused the gate entry and wrote nothing. '
          'The item is still at review_in_progress, still needs a person, and '
          'the absence is on its reviewer\'s timeline';
  }
}

/// Raises the verdict-less decision for a review that produced none, idempotently.
///
/// ## THE CALLER OWNS THE TRIGGER, AND THE TRIGGER IS NOT "COMPLETED"
///
/// This function raises for a review that produced no verdict when NOTHING ELSE
/// WILL MOVE THE ITEM — no retry is still owed. That includes a review that
/// completed, and it includes one that FAILED PERMANENTLY: the latter settles
/// its execution `failed`/`interrupted`, never reaches `completed`, and is never
/// retried by anything, because `RetryPolicy` routes `permanent` straight to
/// `complete(failed)` and `_returnRetriableItemsToEntryStates` only returns items
/// for a `retryWaiting` job. Measured on 2026-10-15:
/// `defect-DEF-1791685024220546` and `defect-DEF-1791686357139031` both sat at
/// `reviewInProgress` with `AgpTransportException: ACP request timed out`, a
/// job `failed` with `kind: permanent`, and nothing on any operator screen.
///
/// `reviewInProgress` is not in `engineeringReviewDefinition.entryStates`, so
/// the review lane can never re-mint one: `RunnableWorkEvaluator` answers
/// `noAction` before any policy probe runs.
///
/// ## IDEMPOTENCE IS THE ENGINE'S, AND THIS DOES NOT WEAKEN IT
///
/// The gate is drained on every tick for as long as the job is terminal, and the
/// tick period is 30s. `DurableWorkflowEngine.requestHumanDecision` already
/// returns the existing pending decision when an item is parked at the gate, and
/// the caller has already returned early for an item at
/// `waitingForHumanDecision` — so this is belt-and-braces over an idempotency
/// that exists independently, not a new mechanism competing with it.
Future<VerdictAbsentDecisionOutcome> raiseVerdictAbsentDecision({
  required DurableWorkflowEngine workflowEngine,
  required String workItemId,
  required Job job,
  required String executionId,
  required String cause,
  required String detail,
  required String? producerActorId,
  required String? reviewProse,
  required bool reviewCompleted,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final item = await workflowEngine.loadWorkItem(workItemId);
  if (item.state == WorkItemState.waitingForHumanDecision) {
    logger?.call('engineering-review-no-verdict-decision-already-pending', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'executionId': executionId,
      'decisionId': item.blockingHumanDecisionId,
    });
    return VerdictAbsentDecisionOutcome.alreadyPending;
  }

  if (producerActorId == null || producerActorId.isEmpty) {
    // Fail closed and say so. `actorIsNotSelf()` refuses a gate entry with no
    // producer identity, so raising here would throw rather than land, and
    // throwing would take the whole `review` section of the tick with it.
    logger?.call('engineering-review-no-verdict-decision-no-producer', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'executionId': executionId,
      'cause': cause,
      'action':
          'no decision was raised. This review produced no verdict and no retry '
          'is owed, so nothing else will move this item: the absence is on the '
          'reviewer\'s execution timeline and the item is still parked at '
          'review_in_progress. The missing fact is the implementer\'s execution '
          'id on the work item; nothing was fabricated to get past the guard '
          'that refused it',
    });
    return VerdictAbsentDecisionOutcome.producerIdentityUnreadable;
  }

  try {
    await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: HumanDecisionType.engineeringReview,
      question: verdictAbsentQuestion(
        cause: cause,
        detail: detail,
        executionId: executionId,
        producerExecutionId: producerActorId,
        reviewProse: reviewProse,
        reviewCompleted: reviewCompleted,
      ),
      options: verdictAbsentOptions,
      recommendation: verdictAbsentRecommendationFor(
        reviewCompleted: reviewCompleted,
      ),
      blocking: true,
      metadata: verdictAbsentMetadata(
        cause: cause,
        detail: detail,
        executionId: executionId,
        producerActorId: producerActorId,
        reviewProse: reviewProse,
        reviewCompleted: reviewCompleted,
        jobFailure: _reviewJobFailureFacts(job),
      ),
      // The ORCHESTRATOR, not the reviewer. The edge
      // `reviewInProgress -> waitingForHumanDecision` admits
      // [ActorType.engineeringReviewer] and `actorIsNotSelf()` passes either,
      // because the reviewer's execution id cannot equal the implementer's. But
      // there is nothing here for the reviewer to have said — that is the whole
      // subject of this decision — and attributing it to that execution would
      // be a second, quieter version of the bug this lane exists to end. The
      // producer identity travels in `extraContext` for the same reason
      // `engineeringReviewMissingArtifact` passes it: the guard reads it there.
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      extraContext: {
        'producerActorId': producerActorId,
        'reviewExecutionId': executionId,
      },
    );
  } on WorkflowTransitionRejectedException catch (e) {
    logger?.call('engineering-review-no-verdict-decision-refused', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'executionId': executionId,
      'error': e.toString(),
      'action':
          'nothing was written; the item is still at review_in_progress with '
          'the absence on its reviewer\'s timeline and still needs a person',
    });
    return VerdictAbsentDecisionOutcome.refused;
  }

  logger?.call('engineering-review-no-verdict-decision-raised', {
    'jobId': job.jobId,
    'workItemId': workItemId,
    'executionId': executionId,
    'cause': cause,
    'carriesVerdict': false,
  });
  return VerdictAbsentDecisionOutcome.raised;
}

/// Whether the review lane's own bounded retry is STILL OWED on [job] — the one
/// question that decides whether this gate may take the work item out from under
/// the queue.
///
/// ## THIS IS THE SCHEDULER'S RULE, READ NOT RE-DERIVED
///
/// [Scheduler._returnRetriableItemsToEntryStates] returns an item to a lane entry
/// state on exactly two conditions: `job.state == JobState.retryWaiting`, and
/// `failure.kind.isRetryable` (which is `== transient` on the contract enum). Its
/// own comment on the second is that `canRetry` is deliberately NOT re-checked,
/// because `JobQueue.scheduleRetry` PRE-INCREMENTS `attempt` — so a perfectly
/// live retry answers `2 < 2`, which is false. That is why this function checks
/// `retryWaiting` FIRST and unconditionally: a job holding a scheduled retry has
/// spent its whole budget on the counter and owes one anyway.
///
/// The other branch is `attempt < maxAttempts` — [RetryPolicy.canRetry], the same
/// bound, for a job that is live but has not been told to wait. A job that is
/// live with nothing left is treated as owed nothing, which is the conservative
/// direction: it is the side that reaches a person rather than stranding.
///
/// ## WHY NOT `job.isTerminal` ALONE
///
/// The drain hands a terminal job to this handler exactly once
/// (`drainTriageOutcomesFromTick` consumes `dispatched ∪ terminal ∪ reconciled`),
/// so through the scheduler the two readings coincide today. This function is
/// also the gate's own guard, and it is deliberately the narrower claim: a test,
/// or a future caller, that passes a `retryWaiting` job gets the refusal, because
/// parking that item at `waitingForHumanDecision` would pre-empt a retry that is
/// coming — the exact mirror of the bug being fixed.
bool _reviewRetryOwed(Job job) {
  if (job.isTerminal) return false;
  if (job.state == JobState.retryWaiting) return true;
  return job.attempt < job.maxAttempts;
}

/// The review JOB's own durable facts, for a decision an operator has to act on.
///
/// Recorded because the coordinator composes its own [AgentExecution.reason] and
/// the worker-side text — `AgpTransportException: ACP request timed out`, the
/// string on both live victims — survives only on `JobFailure.reason`. `kind` is
/// the field that answers "will this ever be retried": `permanent` is the class
/// nothing retries, and `transient` at a spent `attempt` is the other.
///
/// Never a verdict and never an assessment. Every value here is read off the job
/// row the scheduler itself wrote.
Map<String, dynamic>? _reviewJobFailureFacts(Job job) {
  final failure = job.failure;
  return {
    'jobState': job.state.wire,
    'attempt': job.attempt,
    'maxAttempts': job.maxAttempts,
    if (failure != null) ...{
      'code': failure.code.name,
      'kind': failure.kind.name,
      if (failure.reason != null) 'reason': failure.reason,
    },
  };
}

/// Builds a tick handler for engineering review jobs. When the reviewer's job
/// reaches a state in which NOTHING will retry it and the reviewer produced no
/// verdict, this raises a blocking `engineeringReview` HumanDecision to move
/// `reviewInProgress` to `waitingForHumanDecision`.
///
/// ## THE TRIGGER IS "NO RETRY IS OWED", NOT "THE REVIEW FINISHED"
///
/// Those are different questions and the earlier version of this gate asked the
/// second one, which is why `reviewInProgress` was terminal by omission for
/// exactly one failure class.
///
/// The b1 rule was: if the reviewer produced no verdict, record why and return,
/// leaving the item at `reviewInProgress`. That is right while the review lane's
/// own bounded `maxAttempts` is still owed a retry —
/// `Scheduler._returnOneToEntryState` returns the item to a lane entry state to
/// make the retry claimable, while `waitingForHumanDecision` is explicitly SKIPPED
/// by that return, so parking those items pre-empts a retry that is coming.
///
/// It is wrong the moment no retry is owed, and there are TWO ways to get there.
/// The first is a review that DID finish: measured on 2026-10-15, four review
/// executions reached `completed` against real commits (one `18ad90a`, +957/-199)
/// and produced real findings in their prose, every one of them recorded `{}` in
/// `structuredResultJson`, so no verdict was parsed, so no decision was raised,
/// so all four items sat at `reviewInProgress` with nothing on any operator
/// screen and no retry coming — the job SUCCEEDED, and `maxAttempts` only ever
/// retries a failure.
///
/// The second is the one this handler's condition used to miss entirely: a
/// review that FAILED. A PERMANENT failure settles its execution `failed` or
/// `interrupted` and so never reaches `completed`, but `RetryPolicy` routes
/// `permanent` straight to `complete(failed)` and never schedules a retry, and
/// `_returnRetriableItemsToEntryStates` only returns items for a `retryWaiting`
/// job. So a permanent failure is terminal on both sides at once: no verdict, and
/// nothing owed. Measured on 2026-10-15, `defect-DEF-1791685024220546` and
/// `defect-DEF-1791686357139031` both sat there with
/// `AgpTransportException: ACP request timed out` and a job `failed` with
/// `kind: permanent`.
///
/// Nothing can re-mint them either: `reviewInProgress` is NOT in
/// `engineeringReviewDefinition.entryStates` (`{agentCompleted}`), so
/// `RunnableWorkEvaluator` answers `noAction` before any policy probe, and
/// `_retireSupersededForItem` sweeps anything queued. The item was terminal by
/// omission.
///
/// So the condition is [_reviewRetryOwed]'s negation, evaluated against the JOB
/// rather than inferred from the execution's status. Asking "did the review
/// complete" was asking a question about the wrong record: it is a fact about
/// whether a reviewer got to the end of its turn, not about whether anyone is
/// still going to try again.
///
/// ## AND IT NEVER FABRICATES A VERDICT TO GET THERE
///
/// Raising is not inventing. The decision the gate raises is a decision that
/// asserts NO VERDICT — under decision
/// `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option A):
///
///  * it names the absence and its cause in its own text, and never carries a
///    `ReviewVerdict` anywhere — not in `metadata`, not in
///    `extraContext`, not in a recommendation that reads like one;
///  * it says whether the review FINISHED, because a decision whose text claims
///    a review "ran to completion" when it died on an ACP timeout is the same
///    class of false statement as a verdict nobody produced;
///  * it carries the reviewer's ACTUAL prose when there is any, because the
///    reviewer did real work and hiding it would replace one false state with
///    another — and says plainly when there is none;
///  * it offers only `rework` and `cancel`, because `approve` and `reject` are
///    the two choices that WOULD assert an assessment nobody made; and
///  * it is refused by the resolution path if a client submits any other choice,
///    so "it was not offered" is not the only thing stopping it.
///
/// The invariant this replaces — "no decision exists without a parsed verdict" —
/// was an OPERATOR INSTRUCTION from b1, deliberately weakened to "no decision
/// asserts a verdict that was not parsed", which is the property that actually
/// protects a reader. The two zero-row assertions it rested on are amended in
/// `apps/server/test/engineering_review_never_fabricates_verdict_test.dart`,
/// with the decision quoted inline.
///
/// ## AND WHY IT ROUTES BEFORE IT PARKS — BLOCKER B2
///
/// The composition root drains TERMINAL review jobs to this handler FIRST
/// (`apps/server/lib/server.dart`, [runReviewLaneTick]) and only then walks
/// `SchedulerTickResult.blockedArtifactMissing`. That order is correct and is
/// asserted, but it made the automatic route unreachable in production: a
/// reviewer that concludes nothing settles its job terminal, reaches THIS
/// handler, and was parked at `waitingForHumanDecision` — so by the time
/// `engineeringReviewMissingArtifact` was called the item was already parked and
/// that handler returned at its `waitingForHumanDecision` guard. The new
/// `reviewInProgress` branch never ran, and decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab`'s `REREVIEW -> AUTOMATIC` was not
/// delivered: the dead end the operator tapped on 2026-10-16 was still exactly
/// there.
///
/// It was also structurally unreachable, not merely out of order:
/// `blockedArtifactMissing` is populated by `Scheduler._dispatchOne` only while
/// dispatching a job this lane minted from `entryStates = {agentCompleted}`, so
/// the item is at `agentCompleted` — and the review lane's entry hop is a no-op
/// for it, because `agentCompleted -> reviewInProgress` exists as an edge
/// (`skipWorkflowPolicyCheck` deliberately bypasses the policy probe). No job
/// can ever be `blockedArtifactMissing` for an item at `reviewInProgress`.
///
/// So the routing lives HERE, where the verdict-absent case actually arrives, and
/// `engineeringReviewMissingArtifact` keeps its own `reviewInProgress` branch as
/// the defensive second door onto the same function.
//
// ---------------------------------------------------------------------------
// WHICH REVIEW EXECUTION IS BEING ADJUDICATED, AND WHY IT IS NOT THE JOB'S
// ---------------------------------------------------------------------------
//
// ## THE QUESTION THIS GATE ACTUALLY HAS TO ANSWER
//
// "Has a reviewer that FINISHED produced a verdict on this item?"
//
// It used to answer a different question — "did the execution this job is
// holding have a verdict?" — and by the time an answer exists that is the wrong
// execution. The job was retired underneath its own reviewer, a replacement
// reviewer was dispatched behind it, and the job row the gate is handed now
// names the replacement. So the gate read a fresh, unfinished reviewer, found no
// verdict on it, and said so:
//
//     [engineering-review-verdict-absent-routed] x7   route: re_review
//     [engineering-review-gate-no-verdict]      x7
//
// while the reviewer that DID conclude sat on a row nobody looked at again:
//
//     work item  defect-DEF-1791684804452198
//     execution  (ENGINEERING_REVIEWER, completed 2026-10-16 20:02:28)
//     result     {"verdict":"changes_required","findings":[{"severity":"major", ...}]}
//
// Seven statements that "this review returned nothing" and one item with a real
// `changes_required` nobody acted on. Asking about the job is asking about the
// QUEUE; the question is about the WORK.
//
// ## WHY `item.metadata['producerActorId']` IS NOT THE ANSWER EITHER
//
// That key is the IMPLEMENTER's execution id — `ExecutionCoordinator._complete-
// Success` stamps the producer, not the producer's reviewer. Reading a verdict
// off it would be reading the implementer's run, which is both the wrong record
// and the one `actorIsNotSelf()` exists to keep apart from the reviewer.
//
// ## AND WHY THIS SCANS, INSTEAD OF FOLLOWING A POINTER
//
// There is no "the review execution for this item" column to follow. The durable
// facts are per execution — role, status, result — and a re-routed review leaves
// several reviewer executions on one item with only ONE of them concluded. The
// honest answer is a query over this item's settled reviewers, made with the
// SAME parser the verdict path uses, so "carries a verdict" can never mean one
// thing to the scan and another to the raise.
//
// ## AND IT NEVER MAKES UP AN EXECUTION
//
// [_readReviewVerdict] is the only thing in this file that turns a payload into
// a verdict, and it is called here with the logger suppressed, as a PROBE. A
// payload that does not parse to a verdict simply is not a match, so a scan that
// finds nothing resolves to "there is no verdict here" — the same answer the
// gate gave before, from the same parser. There is no default, no fallback id
// and no synthesised `ReviewVerdict` anywhere below.
enum ReviewSubjectSource {
  /// The execution this job was holding carried the verdict itself.
  jobExecutionReference,

  /// A DIFFERENT, settled reviewer execution on this same item carried the
  /// verdict, and the job now names somewhere else. This is the live QA shape.
  verdictBearingExecution,
}

/// The one review execution this gate is adjudicating right now.
class ReviewSubject {
  const ReviewSubject({
    required this.executionId,
    required this.execution,
    required this.result,
    required this.source,
  });

  final String executionId;
  final AgentExecution execution;
  final AgentResult? result;
  final ReviewSubjectSource source;

  @override
  String toString() =>
      'ReviewSubject($executionId, ${execution.status.name}, '
      '${source.name})';
}

/// Most-recently-concluded first, deterministically.
///
/// The store's own ordering is not usable for this: `InMemoryExecutionStore`
/// returns insertion order and `PostgresExecutionStore` orders by `startedAt`
/// with a tie-break on a surrogate key the caller cannot see. Two passes over
/// the same durable rows must agree, so the order is computed here from fields
/// the caller can read, with the execution id as the final tie-break so it never
/// depends on which store answered.
int _byRecencyThenId(AgentExecution a, AgentExecution b) {
  final aAt = a.completedAt ?? a.startedAt;
  final bAt = b.completedAt ?? b.startedAt;
  if (aAt != null && bAt != null && !aAt.isAtSameMomentAs(bAt)) {
    return bAt.compareTo(aAt);
  }
  if (aAt == null && bAt != null) return 1;
  if (aAt != null && bAt == null) return -1;
  return a.executionId.compareTo(b.executionId);
}

/// The status of the execution a job points at, for a log line that has to say
/// both executions' states side by side.
///
/// `'absent'` for a job with no execution reference and `'null'` for a
/// reference that names no row, because those are different facts about a log
/// line an operator is reading to work out which reviewer is live.
Future<String> _statusNameFor(
  ExecutionStore executionStore,
  String? executionId,
) async {
  if (executionId == null || executionId.isEmpty) return 'absent';
  final execution = await executionStore.readExecutionOrNull(executionId);
  return execution?.status.name ?? 'null';
}

/// The verdict wire a result carries, for a log line that reports WHAT was
/// found rather than THAT something was.
///
/// Returns `null` unless the payload's `verdict` is a string this build
/// recognises as a [ReviewVerdict]. That check is the whole point: an
/// unrecognised wire value reported under a key called `reviewVerdict` is a
/// verdict-shaped string nobody produced, and a log line is the easiest place in
/// a file like this to accidentally assert one. It never defaults, and it never
/// returns a value the payload does not contain.
String? _verdictWireOf(AgentResult? result) {
  if (result == null) return null;
  try {
    final raw = result.structuredResult['verdict'];
    if (raw is! String || raw.isEmpty) return null;
    return ReviewVerdict.fromWire(raw).wire;
  } on Object {
    return null;
  }
}

/// Resolves the review execution this gate must adjudicate, or `null` when there
/// is nothing settled to adjudicate.
///
/// `null` means EXACTLY "the job's own execution is missing or still open, and
/// no settled reviewer on this item produced a verdict". That is the shape the
/// caller must leave alone — a reviewer executing right now is not a thing this
/// gate has an opinion about.
///
/// A terminal job execution that produced NO verdict still resolves, to itself.
/// That is the verdict-absent rescue the whole file exists for, and it must keep
/// resolving to the job's own execution so that path's records, logs and decision
/// metadata keep naming the run they have always named.
Future<ReviewSubject?> resolveReviewSubject({
  required ExecutionStore executionStore,
  required Job job,
  required String workItemId,
}) async {
  final jobExecutionId = job.executionReference?.agentExecutionId;
  if (jobExecutionId != null && jobExecutionId.isNotEmpty) {
    final jobExecution = await executionStore.readExecutionOrNull(
      jobExecutionId,
    );
    if (jobExecution != null && jobExecution.isTerminal) {
      final result = await executionStore.readResult(jobExecutionId);
      final read = _readReviewVerdict(
        job: job,
        workItemId: workItemId,
        executionId: jobExecutionId,
        execution: jobExecution,
        reviewerResult: result,
        // PROBE. The verdict path re-reads this same execution WITH the logger
        // once the subject is settled, so the raise reports its own findings
        // once. Logging inside the scan would attribute a parse complaint to an
        // execution that was only ever a candidate.
        logger: null,
      );
      if (read.result != null) {
        return ReviewSubject(
          executionId: jobExecutionId,
          execution: jobExecution,
          result: result,
          source: ReviewSubjectSource.jobExecutionReference,
        );
      }
      // Terminal, no verdict here. Fall through: a DIFFERENT settled reviewer on
      // this item may have concluded, and that outranks a verdict-absent record
      // about this one.
    }
  }

  // THE SCAN. Only settled reviewers, most recent first, and only the ones the
  // gate's own parser can read a verdict out of.
  final executions = await executionStore.listExecutions(
    workItemId: workItemId,
  );
  final candidates =
      executions
          .where(
            (e) =>
                e.role == AgentRole.engineeringReviewer &&
                e.isTerminal &&
                (jobExecutionId == null || e.executionId != jobExecutionId),
          )
          .toList()
        ..sort(_byRecencyThenId);

  for (final execution in candidates) {
    final result = await executionStore.readResult(execution.executionId);
    if (result == null) continue;
    final read = _readReviewVerdict(
      job: job,
      workItemId: workItemId,
      executionId: execution.executionId,
      execution: execution,
      reviewerResult: result,
      logger: null,
    );
    if (read.result != null) {
      return ReviewSubject(
        executionId: execution.executionId,
        execution: execution,
        result: result,
        source: ReviewSubjectSource.verdictBearingExecution,
      );
    }
  }

  // Nothing anywhere produced a verdict. If the job's own execution is settled
  // it is still the subject — of the VERDICT-ABSENT path, which is about that run
  // and names that run everywhere it writes.
  if (jobExecutionId != null && jobExecutionId.isNotEmpty) {
    final jobExecution = await executionStore.readExecutionOrNull(
      jobExecutionId,
    );
    if (jobExecution != null && jobExecution.isTerminal) {
      return ReviewSubject(
        executionId: jobExecutionId,
        execution: jobExecution,
        result: await executionStore.readResult(jobExecutionId),
        source: ReviewSubjectSource.jobExecutionReference,
      );
    }
  }
  return null;
}

TickJobHandler engineeringReviewTickHandler({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
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

    // WHICH REVIEW EXECUTION IS UNDER ADJUDICATION. Not "the one this job
    // names": see the section header on [resolveReviewSubject] for the live
    // seven-times-ignored-verdict shape that made the difference.
    final subject = await resolveReviewSubject(
      executionStore: executionStore,
      job: job,
      workItemId: workItemId,
    );

    if (subject == null) {
      final jobExecutionId = job.executionReference?.agentExecutionId;
      if (jobExecutionId == null || jobExecutionId.isEmpty) {
        logger?.call(
          'engineering-review-gate-missing-execution',
          {'jobId': job.jobId, 'workItemId': workItemId},
        );
        return;
      }
      final open = await executionStore.readExecutionOrNull(jobExecutionId);
      logger?.call(
        'engineering-review-gate-execution-not-terminal',
        {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'executionId': jobExecutionId,
          'status': open?.status.name ?? 'null',
          'carriesVerdict': false,
          'decision':
              'the execution this job was holding has not settled and no other '
              'settled reviewer on this item produced a verdict, so there is '
              'nothing here to adjudicate. This gate does not reach past a live '
              'reviewer to some older run on its own initiative',
        },
      );
      return;
    }

    final executionId = subject.executionId;
    final execution = subject.execution;
    final reviewerResult = subject.result;

    if (subject.source == ReviewSubjectSource.verdictBearingExecution) {
      // Named, because "this gate read a verdict off an execution the job does
      // not reference" is otherwise invisible on a live stack, and it is the
      // whole of this correction: an operator reading the item would otherwise
      // see a decision whose `reviewExecutionId` matches no job they can find.
      logger?.call('engineering-review-gate-verdict-bearing-execution', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'executionId': executionId,
        'jobExecutionId': job.executionReference?.agentExecutionId,
        'jobExecutionStatus': await _statusNameFor(
          executionStore,
          job.executionReference?.agentExecutionId,
        ),
        'executionStatus': execution.status.name,
        'reviewVerdict': _verdictWireOf(reviewerResult),
        'carriesVerdict': true,
        'decision':
            'the job this gate was handed points at an execution that did not '
            'conclude; the verdict being adjudicated is on this other settled '
            'reviewer execution for the same item. The job row is not changed '
            'and no execution is written to by this line',
      });
    }

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
      // TWO FACTS, AND ONLY THE SECOND ONE DECIDES.
      //
      // `reviewCompleted` is a fact about the reviewer: did it reach the end of
      // its own turn. `retryOwed` is a fact about the queue, read off the JOB
      // rather than inferred from the execution's status, and it is the trigger.
      // They came apart on 2026-10-15: a PERMANENT review failure is
      // `failed`/`interrupted` and never completes, and it is also owed no retry
      // by anything, so the old condition read it as "keep waiting" forever.
      final reviewCompleted = execution.status == AgentSessionStatus.completed;
      final retryOwed = _reviewRetryOwed(job);

      await _recordNoVerdict(
        executionStore: executionStore,
        job: job,
        workItemId: workItemId,
        executionId: executionId,
        absence: absence,
        reviewCompleted: reviewCompleted,
        retryOwed: retryOwed,
        logger: logger,
      );

      if (!retryOwed) {
        // THE ROUTE COMES FIRST. This is the case decision
        // `92d567e3-da03-4c43-99f4-e3726472f0ab` resolved `REREVIEW ->
        // AUTOMATIC`, and until this line it never ran in production: parking
        // happened here, and `engineeringReviewMissingArtifact` — which holds
        // the route — was called afterwards on an item already parked at
        // `waitingForHumanDecision`, where it returns at its first guard. See
        // this function's own `## AND WHY IT ROUTES BEFORE IT PARKS`.
        //
        // Every input the route needs is already in scope. The item is at
        // `reviewInProgress` (checked above), which is the only state the
        // `reviewInProgress -> agentCompleted` edge is reachable from and the
        // only state this handler routes from.
        final produced = await _readProducedCommit(workerStore, item);
        final standDown = produced.produced == null
            ? null
            : _implementationInflowOwns(produced.produced!);
        final routed =
            produced.produced != null &&
            await _routeVerdictAbsentItem(
              workflowEngine: workflowEngine,
              item: item,
              job: job,
              produced: produced,
              implementationLaneWillRoute: standDown!.owns,
              logger: logger,
            );
        if (routed) return;

        final producerActorId = item.metadata?['producerActorId'] as String?;
        final outcome = await raiseVerdictAbsentDecision(
          workflowEngine: workflowEngine,
          workItemId: workItemId,
          job: job,
          executionId: executionId,
          cause: absence.cause.wire,
          detail: absence.detail,
          reviewProse: reviewerResult?.summary,
          producerActorId: producerActorId,
          reviewCompleted: reviewCompleted,
          logger: logger,
        );
        // Written AFTER the raise, and carrying what the raise actually did.
        // This is the only place in the file that is allowed to say a decision
        // was raised, and it says it from the returned outcome rather than from
        // the fact that the call was attempted.
        logger?.call('engineering-review-gate-no-verdict-decision', {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'executionId': executionId,
          'jobState': job.state.wire,
          'outcome': outcome.name,
          'routingAttemptedFirst': true,
          'decision': verdictAbsentDecisionSentence(outcome),
        });
      }
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

    // THE RAISE IS GUARDED, AND THE GUARD IS ABOUT VISIBILITY, NOT SAFETY.
    //
    // `DurableWorkflowEngine.requestHumanDecision` THROWS on a refused gate entry,
    // after appending the refusal to the transition history — so an unguarded
    // call here escapes into `drainTriageOutcomesFromTick`'s per-job guard,
    // which logs `triage.tick.job_failed` and moves on. What that leaves on a
    // live stack is exactly the shape this correction exists to end: a reviewer
    // produced a verdict, the item stayed at `reviewInProgress`, and the only
    // record was a job-level failure line naming neither the verdict nor the
    // guard that refused it. The verdict-less raise three hundred lines above
    // has its own guard for the same reason; this is its twin on the verdict
    // path, and the two are kept adjacent so the next reader cannot add one
    // without seeing the other.
    //
    // Nothing about the refusal is swallowed: the raw engine text goes into the
    // log context, and the re-drive sweep below reaches the same settled review
    // again exactly once.
    try {
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
    } on WorkflowTransitionRejectedException catch (e) {
      logger?.call('engineering-review-gate-verdict-decision-refused', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'executionId': executionId,
        'state': item.state.wire,
        // The reviewer's OWN verdict, verbatim, so the operator can read what
        // was discarded without opening the execution store. It is not applied
        // to anything: the item is left exactly where it was.
        'reviewVerdict': reviewResult.verdict.wire,
        'error': e.toString(),
        'carriesVerdict': false,
        'decision':
            'no decision was raised and no verdict was applied to this item. '
            'The reviewer\'s verdict is on its own execution and in this line; '
            'the item is still at review_in_progress and still needs a person',
      });
    }
  };
}

// ---------------------------------------------------------------------------
// THE THIRD DOOR: A SETTLED REVIEW NOBODY CONSUMED
// ---------------------------------------------------------------------------
//
// ## THE DEFECT THIS EXISTS TO END, IN THE ORDER IT ACTUALLY HAPPENS
//
// `engineeringReviewTickHandler` is reached from `drainTriageOutcomesFromTick`,
// which consumes the tick's `dispatched ∪ terminal ∪ reconciled` set. A job in
// that set is handed to its handler ONCE, ever: a terminal job is never reported
// by a later tick, because step 1 of `Scheduler.tick` reconciles only
// `claimed`/`running` rows and steps 5–9 attempt only runnable ones.
//
// So the line
//
// ```dart
// final execution = await executionStore.readExecutionOrNull(executionId);
// if (execution == null || !execution.isTerminal) { log(...); return; }
// ```
//
// is not a guard that defers a decision. It is a guard that DISCARDS one, unless
// something else reaches the same job again — and after that guard the job is
// terminal, so nothing does.
//
// The ordering that makes it real is production machinery, not a hand-built
// fixture, and it is short:
//
//  1. a reviewer's job is `running`, its claim lapses while the agent session is
//     still open, and `Scheduler._reclaimZombie` settles the JOB terminal
//     (`failed`, `kind: permanent`) — `_releaseWorkItem` leaves a reviewer at
//     `reviewInProgress` untouched, so the item does not move;
//  2. the same tick reports that job on `reconciled`, and the drain hands it to
//     this handler;
//  3. the reviewer is STILL RUNNING, so the guard above returns; and
//  4. two minutes later the reviewer finishes and writes a real verdict into a
//     job that will never be reported again.
//
// Measured on live QA at `defect-DEF-1791684804452198`: the review job succeeded,
// the reviewer returned `{"verdict":"changes_required", …}` at 20:02:28, and the
// item was still at `review_in_progress` with `blockingHumanDecisionId` NULL and
// `updatedAt` unchanged since BEFORE that review started. So no transition and
// no decision followed the verdict.
//
// WHAT WAS NOT ESTABLISHED, stated here rather than glossed: this lane could not
// read the QA database, so it did not observe WHICH guard consumed the outcome —
// whether the handler ran against a not-yet-settled execution, or did not run
// for that job at all. Both produce byte-identical durable state, and both are
// one-shot, so both are this defect. What IS established from the code is the
// class: on this path a real verdict reaches a durable row that no component
// reads again, which is what the correction below closes.
//
// ## WHAT THIS DOES, AND WHAT IT DELIBERATELY DOES NOT DO
//
// It re-drives [engineeringReviewTickHandler] itself — the SAME function, not a
// second copy of the verdict logic — for a settled review whose item is still at
// `reviewInProgress`. Re-using the handler is the whole safety argument: every
// guard above is re-evaluated against fresh durable state, so the item's state,
// the producer identity and the retry obligation are all re-read rather than
// remembered.
//
// It NEVER touches a live reviewer. A candidate is admitted only when its
// `AgentExecution` is terminal and its role is `engineeringReviewer`; a
// `running` execution is skipped silently, every pass, so a reviewer executing
// right now is not disturbed by a sweep that is looking at its own neighbours.
//
// ## THE BOUND, AND WHY IT IS NOT `maxAutomaticReviewReroutes`
//
// [maxAutomaticReviewReroutes] bounds a different loop: re-arming the review
// LANE so a new reviewer runs. This loop mints no job, spends no attempt and
// starts no agent — it re-enters a function that either moves the item or
// writes nothing. Reusing that counter would have made the two budgets one
// number, and raising one would silently raise the other.
//
// The bound used here is stricter than either: **at most one re-drive per
// settled review execution, ever.** It is durable and it needs no new write
// authority, because the reviewer's OWN execution timeline already accepts
// appends from this file — the same authority [_recordNoVerdict] uses — and
// `DurableWorkflowEngine` has no metadata-only write at all. After a re-drive
// attempt the gate appends [reviewGateConsumedPayloadKey] to that execution, and
// every later pass sees it and skips.
//
// It is written at [reviewGateConsumedSequence], which is negative on purpose.
// The bound is the safety property of this whole function, and the previous
// version of the marker write collided with `agent_event`'s unique
// `(executionId, sequence)` index and therefore never persisted — so the bound
// was inert on a live stack while reading as protection. That section records
// the measured failure and why each rejected alternative leaves it worse.
//
// Why "attempt", not "success": a re-drive that cannot act — a producer identity
// nobody can read, a transition another writer has already taken — must not be
// retried for ever either. Bounding on success would make an un-actionable
// review re-read its verdict every thirty seconds, which is the same shape as an
// unbounded loop with a slower clock. Bounding on the attempt means the worst
// case is one extra look and then a durable, greppable statement that this gate
// tried once, on the reviewer's own timeline, and a person is needed.
//
// ## AND WHY A SWEEP, RATHER THAN MAKING THE DRAIN RE-REPORT
//
// Re-reporting terminal jobs would put every finished review in this deployment
// back on every tick, for ever, whether or not anything was wrong with it. The
// sweep reads the same durable rows and considers only the narrow shape that is
// actually broken: a settled reviewer, an item still claiming to be in review,
// and no consumption marker.
const String reviewGateConsumedPayloadKey = 'reviewGateConsumed';

/// THE SEQUENCE THIS GATE'S CONSUMPTION MARKER IS WRITTEN AT, AND WHY IT IS
/// NEGATIVE.
///
/// ## THE BOUND IS THE SAFETY PROPERTY, AND IT WAS INERT
///
/// The previous version of [_markSettledReviewConsumed] computed the marker's
/// `sequence` as `max(prior events) + 1` from a snapshot of the execution's
/// events read BEFORE the re-drive ran. But the re-drive itself appends —
/// [_recordNoVerdict] reads fresh and writes `max + 1` — so by the time the
/// marker wrote, `max + 1` was already taken, and the insert hit the index that
/// guards the whole table:
///
/// ```sql
/// CREATE UNIQUE INDEX agent_event_execution_sequence_unique
///   ON agent_event ("executionId", "sequence");
/// ```
///
/// Every marker write failed, so `alreadyConsumed` was never recorded, so the
/// bound never advanced, and every pass re-drove the same settled review. One
/// tick of live QA:
///
///     [engineering-review-settled-redrive] {considered: 18, redriven: 0,
///                                           alreadyConsumed: 0, failed: 7}
///     [engineering-review-settled-redrive-not-marked] x7
///         error: duplicate key value violates unique constraint
///                "agent_event_execution_sequence_unique"
///
/// A bound that reads as protection and protects nothing is worse than no bound,
/// because an operator reading `redriveSettledReviews` concludes the loop is
/// closed.
///
/// ## WHY "COMPUTE THE NEXT FREE SEQUENCE" IS NOT THE FIX
///
/// A fresh read still allocates client-side, so it fixes the *stale snapshot*
/// and leaves the *race*: two writers on one execution both read `max = N`, both
/// write `N + 1`, one loses. The bound would hold on a quiet stack and fail the
/// first time two review ticks overlapped. Read-then-append cannot be correct
/// against a unique index it cannot see, and this marker is written by a lane
/// that shares its timeline with the coordinator writing that same timeline.
///
/// MEASURED, not assumed: re-reading immediately before the write does stop the
/// collision — the handler's append is already visible — and
/// `engineering_review_verdict_bearing_execution_test.dart` confirms it, which
/// is why "just read fresh" is the tempting answer. It is rejected because it
/// converts a certain failure into a timing-dependent one, and a safety property
/// that holds until two writers arrive is not a safety property.
///
/// ## WHY A PURPOSE-APPROPRIATE TABLE IS NOT AVAILABLE HERE
///
/// It is the right answer in the abstract — one row per execution, keyed by
/// execution, no shared sequence space. It is not reachable in this change:
/// `apps/server/migrations/**` is outside this correction's ownership, so there
/// is no new table to write into, and no existing table has the shape. The
/// nearest is `scheduler_event`, which is keyed by JOB — and the job is precisely
/// the record this defect proved to be the wrong key, since a re-routed review
/// leaves the verdict on an execution no job names.
///
/// ## SO: A RESERVED NAMESPACE, DISJOINT BY CONSTRUCTION
///
/// Every other writer of `agent_event` allocates a POSITIVE sequence starting at
/// one. `ExecutionCoordinator._nextSequence` is an in-process counter over 0, and
/// [_recordNoVerdict] is `max(prior) + 1` over a floor of 0. Neither can ever
/// produce a negative number, for any input, ever.
///
/// So the marker takes the negative half-line, which is therefore unreachable by
/// every other allocator — not "unlikely to be free", but *not producible*. The
/// collision is impossible by construction rather than avoided by timing.
///
/// Negative is also the direction that cannot perturb anybody: `max(prior)`
/// never selects a negative while a positive exists, so [_recordNoVerdict]'s
/// allocation is unchanged whether or not the marker is present, and the marker
/// is still the first row of its own timeline when read back in
/// `sequence ASC` order.
///
/// ## AND THE ID IS DETERMINISTIC, SO A SECOND WRITE IS A CONFLICT AND NOT A ROW
///
/// The id names the execution and nothing else. A marker that is written twice
/// must collide — on `agent_event_id_unique` as well as on the sequence index —
/// rather than append a second marker with a fresh timestamp. The bound is
/// "exactly one marker per review execution", and only a deterministic id makes
/// that true under a retry. A timestamped id, which is what this used, would let
/// a duplicate through the one index a disjoint sequence cannot protect.
const int reviewGateConsumedSequence = -1;

/// What one [redriveSettledReviews] pass did with the terminal review jobs it
/// found.
///
/// Reported rather than logged only, because "a lane that looks idle with no
/// item to explain it" is the failure this whole file exists to end — and an
/// operator needs to be able to tell "there was nothing to do" from "there was
/// something and it was refused".
class SettledReviewRedrive {
  const SettledReviewRedrive({
    required this.consideredJobIds,
    required this.redrivenJobIds,
    required this.alreadyConsumedJobIds,
    required this.failedJobIds,
  });

  /// Every terminal review job that named an execution at all. The candidate set
  /// BEFORE the state and liveness filters, so a shrinking candidate set is
  /// visible as a number rather than inferred from silence.
  final List<String> consideredJobIds;

  /// Jobs whose settled review this gate handed to [engineeringReviewTickHandler]
  /// during this pass. Each is now marked consumed and will never be handed to
  /// it again.
  final List<String> redrivenJobIds;

  /// Jobs skipped because their reviewer already carries
  /// [reviewGateConsumedPayloadKey]. This is the bound, counted.
  final List<String> alreadyConsumedJobIds;

  /// Jobs the gate could not mark consumed. The ONLY unbounded shape this
  /// function has, it is loud, and the next pass tries them again — which is
  /// why it is reported rather than dropped.
  final List<String> failedJobIds;

  @override
  String toString() =>
      'SettledReviewRedrive(considered: ${consideredJobIds.length}, '
      'redriven: ${redrivenJobIds.length}, '
      'alreadyConsumed: ${alreadyConsumedJobIds.length}, '
      'failed: ${failedJobIds.length})';
}

/// Whether this gate has already consumed the review on [events]' execution.
bool _settledReviewAlreadyConsumed(List<AgentEventRecord> events) =>
    events.any((e) => e.payload?[reviewGateConsumedPayloadKey] != null);

/// Records on the reviewer's own timeline that this gate has taken its outcome.
///
/// One append per settled review execution, and the reason it is an event rather
/// than a work-item metadata key is written on [_recordNoVerdict]: a metadata key
/// would need a state move to write, the re-drive has no state move to make, and
/// a metadata-only write would be a new authority this file does not have.
///
/// [AgentEventType.warning] for the same reason as there: this is bookkeeping
/// about the review, not a claim that the review went wrong, and
/// `executionFailed` would be the second fabrication in a file that exists to
/// prevent the first.
///
/// It takes NO `prior` event list, and that is the fix rather than a detail.
/// The previous signature was handed a snapshot read before the re-drive ran and
/// allocated `max + 1` from it, which collided with the very append the re-drive
/// itself had just made — see [reviewGateConsumedSequence] for the whole of it
/// and for why reading fresh instead would only have narrowed the window.
///
/// Nothing here is derived from the review's outcome: the payload records which
/// job this gate reached, and that is all it is allowed to say.
Future<void> _markSettledReviewConsumed({
  required ExecutionStore executionStore,
  required Job job,
  required String executionId,
}) async {
  final now = DateTime.now().toUtc();
  await executionStore.appendEvent(
    AgentEventRecord(
      // Deterministic on purpose — see the id argument on
      // [reviewGateConsumedSequence]. One marker per execution, and a retry is
      // a conflict rather than a second row.
      eventId: 'review-gate-consumed-$executionId',
      executionId: executionId,
      workItemId: job.workItemId,
      sequence: reviewGateConsumedSequence,
      type: AgentEventType.warning,
      occurredAt: now,
      payload: {
        'reviewGate': 'settled_review_consumed',
        // The BOUND, in the one form a later pass can read it from.
        reviewGateConsumedPayloadKey: true,
        'jobId': job.jobId,
        'jobState': job.state.wire,
        'markedAt': now.toIso8601String(),
      },
    ),
  );
}

/// Reaches a settled-but-unconsumed engineering review again. See the section
/// header above for the ordering, the bound and why this is a sweep.
///
/// Runs AFTER the drain and the `blockedArtifactMissing` loop in the composition
/// root, so the two doors that already existed run first, in the order
/// `engineering_review_composition_order_test.dart` asserts. This one only ever
/// acts on a settled review those two did not consume, so it cannot pre-empt
/// either.
Future<SettledReviewRedrive> redriveSettledReviews({
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required JobStore jobStore,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  // ONE handler, constructed once and used for every candidate, so the sweep and
  // the drain cannot describe different gates.
  final handler = engineeringReviewTickHandler(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    workerStore: workerStore,
    logger: logger,
  );

  // Sorted, so a pass is deterministic and two passes over the same state do the
  // same work in the same order. Job ids are the tie-break because two review
  // jobs for one item are ordinary — the reviewer that ran and the one that was
  // re-routed behind it — and which is consulted first must not be luck.
  final candidates =
      (await jobStore.listJobs())
          .where(
            (j) =>
                j.jobType == JobType.engineeringReview &&
                j.isTerminal &&
                (j.executionReference?.agentExecutionId?.isNotEmpty ?? false),
          )
          .toList()
        ..sort((a, b) {
          final byItem = a.workItemId.compareTo(b.workItemId);
          return byItem != 0 ? byItem : a.jobId.compareTo(b.jobId);
        });

  final considered = <String>[];
  final redriven = <String>[];
  final consumed = <String>[];
  final failed = <String>[];

  for (final job in candidates) {
    considered.add(job.jobId);

    // THE ITEM FILTER, and it is the only state this sweep acts from.
    // `waitingForHumanDecision` means somebody already decided, `agentCompleted`
    // and below mean the review lane is not holding this item. Both are somebody
    // else's to move.
    final item = await workflowEngine.loadWorkItem(job.workItemId);
    if (item.state != WorkItemState.reviewInProgress) continue;

    // THE LIVENESS FILTER, restated in terms of the execution that will actually
    // be adjudicated rather than the one the job happens to name.
    //
    // It used to read `job.executionReference!.agentExecutionId` and skip
    // anything not terminal — which is precisely the job-relative mistake the
    // verdict path was just corrected for. A re-routed review leaves the verdict
    // on an execution no job names, and the jobs that DO get handed to this
    // sweep name the replacements, so the one settled, verdict-bearing reviewer
    // on the item was filtered out as "not a candidate" and its verdict stayed
    // unconsumed.
    //
    // The rule is unchanged in what it protects: a candidate is admitted only
    // when [resolveReviewSubject] returns a SETTLED reviewer execution to act
    // on, and returns `null` — so this sweep declines — whenever every reviewer
    // on this item is still running. A reviewer executing right now is still not
    // a thing this gate has an opinion about.
    final subject = await resolveReviewSubject(
      executionStore: executionStore,
      job: job,
      workItemId: job.workItemId,
    );
    if (subject == null) continue;
    final executionId = subject.executionId;

    final events = await executionStore.readEvents(executionId);
    if (_settledReviewAlreadyConsumed(events)) {
      consumed.add(job.jobId);
      continue;
    }

    Object? handlerError;
    try {
      await handler(job);
    } on Object catch (error) {
      // Per-job, and it does NOT stop the pass. The handler is already guarded
      // on its own paths; this catches a store fault, and one item's fault must
      // not hide every other stranded review in the same pass.
      handlerError = error;
    }

    try {
      await _markSettledReviewConsumed(
        executionStore: executionStore,
        job: job,
        executionId: executionId,
      );
      redriven.add(job.jobId);
    } on Object catch (error) {
      // RE-READ BEFORE CALLING IT A FAILURE. A concurrent pass may have written
      // this exact marker between the bound check above and this write — the id
      // is deterministic, so the loser of that race gets a unique violation it
      // did not cause. The marker exists in that case, so the bound HOLDS, and
      // reporting it as `failed` would be a false statement about the safety
      // property this whole function exists to provide.
      //
      // Durable state is re-read rather than the error string being parsed: the
      // question is "is the marker there", and that has one honest answer.
      final marked = _settledReviewAlreadyConsumed(
        await executionStore.readEvents(executionId),
      );
      if (marked) {
        consumed.add(job.jobId);
        continue;
      }
      failed.add(job.jobId);
      logger?.call('engineering-review-settled-redrive-not-marked', {
        'jobId': job.jobId,
        'workItemId': job.workItemId,
        'executionId': executionId,
        'handlerError': handlerError == null ? null : '$handlerError',
        'error': '$error',
        'carriesVerdict': false,
        'decision':
            'the handler ran and the marker is still absent after a re-read, so '
            'the next pass will reach the same settled review again. That is the '
            'one shape here that is not bounded, and it is a store fault rather '
            'than a review outcome',
      });
    }
  }

  if (redriven.isNotEmpty || failed.isNotEmpty) {
    logger?.call('engineering-review-settled-redrive', {
      'considered': considered.length,
      'redriven': redriven.length,
      'alreadyConsumed': consumed.length,
      'failed': failed.length,
      'redrivenJobIds': redriven,
      'failedJobIds': failed,
      'carriesVerdict': false,
      'decision':
          'a settled review whose outcome no earlier door consumed was handed to '
          'this gate again, once. Each is now marked on its own execution '
          'timeline and will not be handed over again; nothing here asserted a '
          'verdict, and nothing here started an agent',
    });
  }

  return SettledReviewRedrive(
    consideredJobIds: List.unmodifiable(considered),
    redrivenJobIds: List.unmodifiable(redriven),
    alreadyConsumedJobIds: List.unmodifiable(consumed),
    failedJobIds: List.unmodifiable(failed),
  );
}

/// Whether the implementation lane's completion inflow will move the item off
/// `agentCompleted` this tick, and — when it will not — why this gate is the
/// one that has to act.
typedef _InflowStandDown = ({bool owns, String why});

/// One read of the ONE artifact predicate, kept whole.
///
/// [producedCommitFor] is called on every path through this handler, so it is
/// called ONCE and its answer carried, rather than re-read per branch. Two
/// reads could disagree — a second read landing between them is a different
/// durable state, and the route would be taken on the first answer while the
/// log reported the second.
///
/// [produced] is null exactly when the read itself failed, and `error` carries
/// why. Every refusal inside [producedCommitFor] is already a
/// [NoCommitProduced]; a null [produced] therefore means something worse than
/// "no commit" — the answer is UNKNOWN — and the two are deliberately not the
/// same value.
typedef _ProducedCommitRead = ({ProducedCommit? produced, Object? error});

Future<_ProducedCommitRead> _readProducedCommit(
  WorkerStore workerStore,
  WorkItem item,
) async {
  try {
    return (produced: await producedCommitFor(workerStore, item), error: null);
  } on Object catch (error) {
    // `producedCommitFor` reads durable state that throws by design when it
    // cannot be read, and a handler that throws takes the whole `review`
    // section of the tick down with it — every other blocked job in that
    // section unreported. Caught here and resolved to "unknown", which routes
    // to the human: parking is the side of the choice that cannot strand an
    // item on an answer nobody established.
    return (produced: null, error: error);
  }
}

/// THE STAND-DOWN, AND WHY IT NO LONGER ASKS ABOUT THE RE-WORK BOUND
///
/// ## THE BRANCH THAT WAS HERE WAS NOT MERELY DEAD — IT WAS WRONG
///
/// This used to read the shared re-work discriminator
/// (`DurableWorkflowEngine.readTriageAttempt`) against `maxImplementationInflows`
/// and answer `owns: false` once the number was at or above that bound, on the
/// stated ground that
///
/// > so the implementation lane will not route it either and nobody else is
/// > left to act
///
/// That ground was false, and false in the one direction that strands work.
/// Decision `92d567e3-da03-4c43-99f4-e3726472f0ab` (ARCHITECTURE, RESOLVED)
/// answered `RETRY_LIMIT -> REMOVE`: the automatic inflow bound is gone, so the
/// implementation lane's completion inflow routes a no-artifact item back into
/// `implementationReady` UNBOUNDED. The lane was always going to take it. The
/// branch refused on behalf of a lane that had never been asked, and then parked
/// the item in front of a human whose only answers are `rework` and `reject` —
/// neither of which reaches an implementer.
///
/// The cost was measured rather than hypothetical, and it is the operator's own
/// evidence in the same decision: four defects sat at `agent_completed` with a
/// discriminator reading 3 or 4, and every tick logged
/// `engineering-review-missing-artifact-parking` carrying that sentence. An
/// automatic route had been switched off by a number that was only ever a brake
/// on a loop, and that loop no longer exists for a better reason — the same
/// decision makes an implementation that produced nothing a permanent FAILURE,
/// so it never reaches `agent_completed` and the cycle
/// `agentCompleted -> implementationReady -> agentExecuting -> agentCompleted`
/// is broken at the step that started it.
///
/// So the answer for a producer that left no commit is `owns: true`,
/// unconditionally. The item is not parked on an accounting question; it is
/// returned to the lane that can do the work that is missing.
///
/// The re-work discriminator is still read — by
/// `implementFeatureDedupeKey`, which needs it to build a key a consumed job
/// does not already hold — but it is no longer read HERE, because nothing about
/// it bears on who acts next. The parameter that carried the item is gone with
/// it: this decision is a function of the artifact answer alone.
_InflowStandDown _implementationInflowOwns(ProducedCommit produced) {
  if (produced.isProduced) {
    return (
      owns: false,
      why:
          'the producer did leave a commit, so this item is not the '
          'inflow\'s case and there is still a real question for a human '
          'here',
    );
  }
  return (
    owns: true,
    why:
        'the producer left no commit, and the implementation lane\'s completion '
        'inflow routes it back into implementationReady without a bound — so '
        'this gate stands down rather than asking a human a question whose '
        'options are only rework and reject',
  );
}

/// WHERE A REVIEW THAT CONCLUDED NOTHING IS SENT, AND WHY THAT IS NOT A VERDICT
///
/// Decision `92d567e3-da03-4c43-99f4-e3726472f0ab` (ARCHITECTURE, RESOLVED)
/// recorded what the operator measured on the live QA stack: a work item at
/// `review_in_progress` whose reviewer concluded nothing was parked behind a
/// decision whose options were exactly `[rework, reject]`, and
///
/// > how would a reviewer actually review it.
///
/// Neither option answers that question. `rework` runs the IMPLEMENTATION lane
/// again — throwing away a commit that already exists — and `reject` is the
/// shape that means "a reviewer rejected this work" for work no reviewer
/// assessed. The same decision answered `REREVIEW`: `AUTOMATIC`, "platform
/// routes automatically", explicitly NOT a human decision with a third option.
///
/// ## THIS ENUM SAYS WHICH LANE ACTS NEXT. IT ASSESSES NOTHING
///
/// There is no member meaning "the work is good" and none meaning "the work is
/// bad". [reReview] is "there is an artifact and nobody has looked at it yet";
/// [implementation] is "there is no artifact, so there is nothing to look at";
/// [humanDecision] is "the platform cannot tell, so a person must". Read as a
/// verdict any of those three would be a fabrication, and the anti-fabrication
/// property asserted in
/// `apps/server/test/engineering_review_never_fabricates_verdict_test.dart`
/// would hold only by accident. What keeps them apart is that no member carries
/// a [ReviewVerdict] and no branch below writes one.
///
/// ## WHY `humanDecision` IS A MEMBER AND NOT A FAILURE
///
/// Automatic routing that cannot route is a dropped work item, so the member
/// stays and stays meaningful as the exhaustive case. What CHANGED is which
/// inputs reach it.
///
/// It used to be reached by two: a producer whose artifact could not be read,
/// and a no-artifact producer whose re-work discriminator was at the bound. The
/// second is gone with the bound it was reading — a discriminator at its former
/// ceiling is no longer evidence that nobody is left to act, because the
/// implementation lane now routes such an item unbounded. See
/// [_implementationInflowOwns] for the whole of that.
///
/// ## AND WHY `humanDecision` IS NOW REACHABLE, WHICH IS WHY THE MEMBER STAYS
///
/// It was unreachable at the reviewed HEAD, and the reviewer's B2 finding says so
/// plainly: the sole caller passed `implementationLaneWillRoute: standDown.owns`,
/// which is `false` exactly when the producer DID commit, and `CommitProduced`
/// short-circuited to [reReview] without consulting anything else.
///
/// Two things changed. [engineeringReviewTickHandler] now calls
/// [reviewGateRouteFor] at all — before, nothing on the production path reached
/// it — and the function grew a third input, [reviewGateRouteFor]'s
/// `automaticRerouteBudgetSpent`.
///
/// ## THE BOUND, AND WHY THE PLATFORM NEEDS ONE
///
/// A re-review route that is not bounded is an unbounded automatic LLM retry
/// loop, which is precisely what [RetryPolicy] and
/// `engineeringReviewDefinition.maxAttempts` exist to prevent, and it is
/// contradicted by the operator's own stated principle in decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab`:
///
/// > Everything the platform retries on its own must therefore be bounded, and
/// > everything a human drives must not be.
///
/// The measured shape of the unbounded version is not hypothetical either: the
/// reviewers that reached this gate on 2026-10-15 died on
/// `AgpTransportException: ACP request timed out` — a transport fault that has
/// nothing to do with the work — and a route that re-arms the lane would mint a
/// fresh reviewer for the same timeout for ever.
///
/// So the count lives on the item ([_autoRerouteLedger], written by the same
/// transition that performs the route) and is spent one unit per automatic
/// re-review. When it is spent the answer is [humanDecision]: the platform has
/// tried, twice, and the evidence says a person should look. That is the
/// operator's original dead end — but reached after the platform has actually
/// acted, rather than as the first and only thing that happened.
enum ReviewGateRoute {
  /// An artifact exists and no reviewer has concluded anything about it. The
  /// item goes back to the review lane's entry state so a reviewer is
  /// dispatched at the revision the producer actually left.
  reReview('re_review'),

  /// No artifact exists, so there is nothing to review. The item goes back
  /// through the completion fan-out, where the implementation lane's own
  /// completion inflow routes it into `implementationReady` — the lane that can
  /// do the work that is missing.
  implementation('implementation'),

  /// Neither. A human decides, on the existing decision.
  humanDecision('human_decision');

  const ReviewGateRoute(this.wire);

  final String wire;
}

/// The metadata key holding [_autoRerouteLedger]'s durable count.
///
/// Public because it names a KEY WRITTEN INTO PRODUCTION ROWS: a test that
/// wants to model an item which has already spent its budget has to be able to
/// write it, and a private name would force such a test to either re-spell the
/// string or reach past the API.
const String engineeringReviewAutoRerouteMetadataKey =
    'engineeringReviewAutoReroute';

/// How many automatic re-reviews the platform grants a single item, per stretch
/// of production work, before it asks a person instead.
///
/// ## ONE, AND WHY THE NUMBER IS NOT THE JOB'S `maxAttempts`
///
/// It is not `engineeringReviewDefinition.maxAttempts` because that budget is
/// spent INSIDE one job and the route mints the next one, so re-using it would
/// reset on every route and bound nothing. The number that has to be monotone
/// across routes is the one this ledger is.
///
/// It is `1` rather than more because the reviewers that actually reached this
/// gate did not fail on the work. They died on
/// `AgpTransportException: ACP request timed out` — four of them on 2026-10-15,
/// against real commits, three of which produced real findings in their prose.
/// A second automatic attempt at the same transport is the same transport, and
/// each one costs a real worker execution and real money. One automatic retry
/// distinguishes "the first reviewer died before it started" from "this review
/// does not converge", and the second is a fact about the platform, not about
/// the code, so it belongs in front of a person.
///
/// Raising it is a one-character change to a named constant and nothing else.
const int maxAutomaticReviewReroutes = 1;

/// This item's automatic re-review ledger, keyed by the production pass it was
/// spent in.
///
/// ## WHY IT CARRIES THE PASS IT WAS SPENT IN
///
/// The count is per stretch of production work, so it has to be scoped to one.
/// [DurableWorkflowEngine.triageAttemptMetadataKey] is the durable marker that
/// advances every time an item is sent back into production — the operator
/// retry, a resolved rework/reject, and the implementation lane's own completion
/// inflow — so a different value of it means the item HAS been back in
/// production, and this stretch's budget is fresh.
///
/// Without that scoping the ledger would be a lifetime cap of one re-review for
/// the whole life of the item, and an item that is legitimately re-implemented
/// five times would get exactly one automatic re-review across all of them.
///
/// ## A LEDGER THAT CANNOT BE READ RESETS TO ZERO, AND SAYS SO
///
/// Unreadable means "the platform cannot establish that this item already spent
/// its budget", and the two available answers are to route (risk an unbounded
/// loop on a tampered ledger) or to park (strand a real item behind a human).
///
/// It takes the third: it parks, it reports, and it leaves the ledger alone for
/// a human. Refusing to loop on an answer nobody established is the property
/// this file is for — see [ReviewGateRoute.humanDecision] — and a tampered
/// ledger is a defect to repair, not a budget to spend.
typedef _AutoRerouteLedger = ({int? productionPass, int spent, bool readable});

_AutoRerouteLedger _autoRerouteLedger(WorkItem item, int? productionPass) {
  final raw = item.metadata?[engineeringReviewAutoRerouteMetadataKey];
  if (raw is! Map) {
    return (productionPass: productionPass, spent: 0, readable: true);
  }
  final spent = raw['spent'];
  final pass = raw['productionPass'];
  if (spent is! int || (pass != null && pass is! int)) {
    return (
      productionPass: productionPass,
      spent: 0,
      readable: false,
    );
  }
  // A different production pass is a fresh budget: the item went back through
  // implementation, so any refusal in the previous pass has been answered.
  if (pass != productionPass) {
    return (productionPass: productionPass, spent: 0, readable: true);
  }
  return (productionPass: productionPass, spent: spent, readable: true);
}

/// The route for a review that concluded nothing, from the ONE artifact
/// predicate.
///
/// A `switch`, not an inline `if`, and not re-stated from the source: the input
/// is already a named function — [producedCommitFor] — and the asymmetry
/// between the two branches is the whole safety argument. A commit routes on NO
/// question about the implementation lane's budget, because
/// `agentCompleted -> reviewInProgress` is not an entry into that lane. A
/// producer that left nothing routes TO that lane, which under decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` no longer has a budget to be out of.
///
/// [humanDecision] has exactly two inputs and both are asserted:
/// `automaticRerouteBudgetSpent` — the platform already spent
/// [maxAutomaticReviewReroutes] re-reviews on this item in this production pass
/// — and an unreadable or absent ledger, which
/// [_routeVerdictAbsentItem] resolves to the same refusal rather than to a
/// guess.
ReviewGateRoute reviewGateRouteFor({
  required ProducedCommit produced,
  required bool implementationLaneWillRoute,
  required bool automaticRerouteBudgetSpent,
}) => switch (produced) {
  CommitProduced() =>
    automaticRerouteBudgetSpent
        ? ReviewGateRoute.humanDecision
        : ReviewGateRoute.reReview,
  NoCommitProduced() =>
    implementationLaneWillRoute
        ? ReviewGateRoute.implementation
        : ReviewGateRoute.humanDecision,
};

/// The evidence a route was taken on, in a form the next operator can check.
///
/// [ProducedCommit.reason] alone is a GENERIC statement — "a commit was produced
/// that differs from the starting revision" — which is true of every commit in
/// the system and therefore falsifies nothing. A route decided on an
/// unidentifiable answer is not a route somebody can audit a week later, so the
/// revision and the repository are named here. Read off the same
/// [CommitProduced] the gate just decided on, never re-derived.
String _artifactEvidence(ProducedCommit produced) => switch (produced) {
  CommitProduced(:final repositoryPath, :final commit) =>
    'a commit exists to review: $commit in $repositoryPath ($produced)',
  NoCommitProduced() => 'no commit exists to review: $produced',
};

/// Returns an item that a reviewer entered but that concluded nothing to
/// `agentCompleted`, and reports whether the route was taken.
///
/// ## `agentCompleted` IS THE FAN-OUT, AND IT IS ALREADY BUILT
///
/// `agentCompleted` is where `sched-review`'s `entryStates` and
/// `sched-impl`'s `completionInflowFrom` meet, and `completionRouteFor` is
/// already the one function that decides which of them owns a producer's
/// output, on the same [producedCommitFor] answer read here. So the gate does
/// NOT re-decide the second hop, and it does NOT take the
/// `agentCompleted -> implementationReady` edge itself: that move is written in
/// the SAME transaction as the dispatch discriminator stamp
/// (`Scheduler._applyCompletionInflow`), and a move taken here without that
/// stamp would re-use an `implementFeatureDedupeKey` the previous
/// implementation job already consumed — `enqueueIfAbsent` would answer
/// `created: false` and the re-run would silently do nothing.
///
/// That is why this returns the item to the fan-out instead of to
/// `implementationReady`: the decision stays with the component that makes it,
/// and under decision `92d567e3-da03-4c43-99f4-e3726472f0ab` that component no
/// longer holds a bound this gate could keep a private copy of. A second copy
/// would have outlived the rule it enforced and refused routes against a bound
/// that no longer exists — which is precisely the defect that stranded four
/// defects on the live QA stack.
///
/// ## AND `implementationLaneWillRoute` IS NOT A BUDGET CHECK
///
/// Not because the inflow's answer is taken on trust — it is
/// [_implementationInflowOwns]'s, and it is only `false` when the producer DID
/// commit — but because there is no longer any per-item question to ask. A
/// no-artifact producer is routed by the inflow unconditionally, so the
/// parameter records which branch of the stand-down was taken rather than
/// consulting a counter that no longer gates anything. An item the platform
/// genuinely cannot route — a producer that cannot be read at all — still
/// returns `false`, and that is what falls back to the existing decision so a
/// person still sees it.
/// ## AND WHY THE RE-REVIEW BRANCH SPENDS THE PRODUCTION PASS
///
/// Returning the item to `agentCompleted` is necessary and NOT SUFFICIENT. The
/// review lane mints its job under
/// `engineeringReviewDedupeKey(item, engineeringReviewDefinition)`, which
/// `JobQueue.enqueueIfAbsent` resolves against ANY job holding that key —
/// terminal or not, by the documented contract at `job_queue.dart:37-51` ("one
/// intent, one job, one spend"). The reviewer that just concluded nothing is
/// such a job, and it still holds the key.
///
/// So a route that only moves the item lands it at `agentCompleted` with an
/// artifact nobody has read, no job that can be dispatched, and no operator
/// screen: the scheduler re-reports the consumed key every tick and does
/// nothing. That is the silent-no-op class this platform keeps naming in its own
/// comments, and it is worse than the decision it replaced, because a human at
/// least SAW the decision.
///
/// `Scheduler._applyCompletionInflow` solves the identical problem on the
/// implementation lane by writing `triageAttemptMetadataKey` in the SAME
/// transaction as the move, so the next key is one no earlier job holds. This
/// route does the same thing for the same reason, and it is the reason
/// `scheduler.dart` records that closing the second-review case "needs a
/// discriminator that counts REVIEW attempts and is advanced by whoever requests
/// the re-review… `DurableWorkflowEngine` has no metadata-only write (the only
/// one is `transition(metadataMerge:)`, which requires a state move)". The
/// re-review request HAS a state move — that is what it is — so the writer that
/// was said not to exist has one now.
///
/// Strict monotonicity is preserved: the value written is
/// [DurableWorkflowEngine.nextTriageAttempt], which is strictly greater than both
/// the value already on the item and its `floor`. The marker's own documented
/// meaning widens here from "sent back into production" to "sent back into
/// production OR re-requested by a route", which is a third writer alongside the
/// operator retry and the resolved rework/reject decision. That widening is real
/// and is reported as a discovery rather than smuggled in: the marker's own
/// documentation lives in `packages/workflow_store`, which this lane does not
/// own.
Future<bool> _routeVerdictAbsentItem({
  required DurableWorkflowEngine workflowEngine,
  required WorkItem item,
  required Job job,
  required _ProducedCommitRead produced,
  required bool implementationLaneWillRoute,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final commit = produced.produced!;
  // Read the production pass through the ONE reader, which throws by design on a
  // present-but-unreadable marker. It is read inside the same guard as the
  // route, because a marker nobody can read cannot key a budget and cannot key
  // a job either.
  int? productionPass;
  _AutoRerouteLedger ledger;
  try {
    productionPass = DurableWorkflowEngine.readTriageAttempt(item);
    ledger = _autoRerouteLedger(item, productionPass);
  } on FormatException catch (e) {
    logger?.call('engineering-review-verdict-absent-not-routed', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'state': item.state.wire,
      'artifactEvidence': _artifactEvidence(commit),
      'artifactProduced': commit.isProduced,
      'carriesVerdict': false,
      'error': e.toString(),
      'decision':
          'no route was taken. The dispatch discriminator on this item could '
          'not be read, so neither the re-review budget nor the next dedupe key '
          'can be established. Routing on an answer nobody established is the '
          'failure this gate exists to prevent, so the item is left for a person',
    });
    return false;
  }

  // The bound is asked ONLY of the re-review route. The implementation route
  // does not need it and must not be charged for it: that lane's own completion
  // inflow is what advances the discriminator, and an implementation run that
  // produces nothing is a permanent failure rather than a loop.
  final budgetSpent =
      !ledger.readable ||
      (commit.isProduced && ledger.spent >= maxAutomaticReviewReroutes);
  final route = reviewGateRouteFor(
    produced: commit,
    implementationLaneWillRoute: implementationLaneWillRoute,
    automaticRerouteBudgetSpent: budgetSpent,
  );
  if (route == ReviewGateRoute.humanDecision) {
    // NO CLAIM IS MADE HERE. What the caller does next is its own business and
    // it reports it; this returns false and says only that no route was taken.
    logger?.call('engineering-review-verdict-absent-not-routed', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'state': item.state.wire,
      'artifactEvidence': _artifactEvidence(commit),
      'artifactProduced': commit.isProduced,
      'carriesVerdict': false,
      'automaticReroutesSpent': ledger.spent,
      'maxAutomaticReroutes': maxAutomaticReviewReroutes,
      'rerouteLedgerReadable': ledger.readable,
      'decision':
          'no route was taken by this step and no decision is claimed by this '
          'line. The caller states what it did next',
    });
    return false;
  }

  final destination = route == ReviewGateRoute.reReview
      ? 'so a reviewer is dispatched at the revision the producer left'
      : 'so the implementation lane\'s completion inflow routes it into '
            'implementationReady, which is the lane that can do the work that '
            'is missing';
  // Computed once, before the transition, and read by BOTH merge keys below.
  // It is a pure function of the item, so the call cannot fail here and cannot
  // disagree with itself. Zero on the implementation branch, where it is never
  // read — the lane's own completion inflow writes that marker in its own
  // transaction.
  final nextRerouteDiscriminator = route == ReviewGateRoute.reReview
      ? DurableWorkflowEngine.nextTriageAttempt(item)
      : 0;
  try {
    await workflowEngine.transition(
      workItemId: item.workItemId,
      to: WorkItemState.agentCompleted,
      trigger: TransitionTrigger.systemEvent,
      // The ORCHESTRATOR, holding no execution. The same actor the entry
      // transition above uses, and the same one the edge
      // `reviewInProgress -> agentCompleted` admits.
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      // Merged, never replacing, and written ONLY on the re-review branch.
      //
      // Two keys, and both exist to stop a silent no-op rather than to describe
      // anything. `triageAttemptMetadataKey` gives the review lane a dedupe key
      // no earlier review job holds, so a reviewer is actually dispatched.
      // `_autoRerouteMetadataKey` records that this route was taken, which is
      // what bounds the NEXT one.
      //
      // The implementation branch merges nothing: it does not spend the
      // re-review budget, and the implementation lane writes its own marker in
      // its own transaction when it takes the second hop.
      metadataMerge: route == ReviewGateRoute.reReview
          ? {
              // ONE arithmetic rule, ONE call. Calling it twice would be the
              // same rule stated twice, and the two values could only ever
              // disagree by a bug.
              DurableWorkflowEngine.triageAttemptMetadataKey:
                  nextRerouteDiscriminator,
              engineeringReviewAutoRerouteMetadataKey: {
                'productionPass': nextRerouteDiscriminator,
                'spent': ledger.spent + 1,
              },
            }
          : null,
      // Written so that it cannot be read as an assessment. It names the
      // artifact evidence, the destination and the absence of a verdict —
      // nothing here claims a reviewer looked at this work, because by
      // construction none did.
      reason:
          'the reviewer concluded nothing, so this item is returned to '
          'agent_completed $destination. No reviewer assessed this work and '
          'this route asserts no verdict either way. Artifact evidence: '
          '${_artifactEvidence(commit)}',
    );
  } on WorkflowTransitionRejectedException catch (e) {
    // Someone else owns the item now — a human, a gate, another tick. Not an
    // error here: nothing was written, and the next tick re-reads and decides
    // again. Reported rather than swallowed, because a lane that looks idle
    // with no item to explain it is the failure this whole gate exists to end.
    logger?.call('engineering-review-verdict-absent-route-refused', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'route': route.wire,
      'error': e.toString(),
      'carriesVerdict': false,
      'decision':
          'no route was taken and no decision was raised. Nothing was '
          'written, nothing was consumed, and the next tick re-reads the item '
          'and decides again',
    });
    return false;
  }

  logger?.call('engineering-review-verdict-absent-routed', {
    'jobId': job.jobId,
    'workItemId': item.workItemId,
    'route': route.wire,
    'fromState': item.state.wire,
    'toState': WorkItemState.agentCompleted.wire,
    'artifactEvidence': _artifactEvidence(commit),
    'artifactProduced': commit.isProduced,
    'implementationLaneWillRoute': implementationLaneWillRoute,
    // The bound, reported as SPENT rather than as a limit that might still have
    // room. An operator reading `automaticReroutesSpent: 1` can tell how many
    // reviewers this item has already had for nothing; a boolean cannot.
    if (route == ReviewGateRoute.reReview) ...{
      'automaticReroutesSpent': ledger.spent + 1,
      'maxAutomaticReroutes': maxAutomaticReviewReroutes,
      'dispatchDiscriminatorStamped': true,
    },
    // The b1 invariant, restated on the route itself rather than on a
    // decision: a routed item carries no `reviewVerdict` and no
    // `engineeringReviewResult`, and this gate wrote neither.
    'carriesVerdict': false,
    'decision':
        'none raised. This is a routing decision about which lane acts next, '
        'not a review verdict: no reviewer assessed this work, and this item '
        'carries no verdict on any field a reader could take one from',
  });
  return true;
}

/// Fail-closed handling for an engineering-review job the scheduler refused to
/// dispatch because no produced artifact could be resolved.
///
/// The scheduler never runs a reviewer against the triage tree: with no artifact
/// its workload resolver returns `null` and the job surfaces in
/// `SchedulerTickResult.blockedArtifactMissing`. This is where that becomes
/// either an automatic ROUTE or a blocking `engineeringReview` HumanDecision,
/// and which one it is depends on whether the platform can move the item at all.
///
/// ## WHY THERE IS NOW A ROUTE, AND WHY IT IS AUTOMATIC
///
/// This handler used to answer one question — "can the implementation inflow
/// take it?" — and park everything else. Decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` (ARCHITECTURE, RESOLVED) added the
/// second: an item a reviewer entered and that concluded nothing is ROUTED, by
/// the artifact answer, to whichever lane can actually act on it.
///
/// The reason is the operator's own measurement on the live QA stack: the
/// decision this handler raised offered exactly `[rework, reject]`, and asked
///
/// > how would a reviewer actually review it.
///
/// `rework` runs the IMPLEMENTATION lane again, discarding a commit that
/// already exists; `reject` records a reviewer having rejected work no reviewer
/// assessed. Neither reaches a reviewer, so an item with a reviewable commit
/// was a dead end an operator could not act their way out of. The decision
/// answered `REREVIEW -> AUTOMATIC`: the platform routes, rather than offering a
/// human a third option.
///
/// ## WHY IT STILL STANDS DOWN FOR A NO-ARTIFACT PRODUCER AT `agentCompleted`
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
/// ## AND WHY `agentCompleted` IS NOT RE-ROUTED
///
/// An item at `agentCompleted` whose producer DID commit is not this handler's
/// to move: the workload resolver resolves that one, so no
/// `blockedArtifactMissing` job is ever created for it, and the case survives
/// here only as a defensive path (asserted against a real store in
/// `apps/server/test/integration/execution_store_roundtrip_test.dart`). Routing
/// it would be routing something review is already going to pick up. The
/// routing below is scoped to `reviewInProgress`, which is the state the
/// operator's item was actually in and the one nothing else can move.
///
/// ## THIS BRANCH IS THE SECOND DOOR, NOT THE ONLY ONE — BLOCKER B2
///
/// It was the ONLY door at the reviewed HEAD, and that is why the operator's
/// directive was not delivered. `SchedulerTickResult.blockedArtifactMissing` is
/// populated by `Scheduler._dispatchOne` while dispatching a job this lane
/// minted from `entryStates = {agentCompleted}`, and the review lane's entry hop
/// is a no-op for such an item because the edge `agentCompleted ->
/// reviewInProgress` exists. So no job can ever be `blockedArtifactMissing` for
/// an item at `reviewInProgress`, and the branch below had no input at all.
///
/// The verdict-absent case arrives here in production only by way of the
/// composition root's ORDER: `drainTriageOutcomesFromTick` hands the terminal
/// review job to `engineeringReviewTickHandler` FIRST, which parks the item, so
/// by the time this loop reached it the item was already at
/// `waitingForHumanDecision` and returned at the guard at the top of this
/// function.
///
/// [engineeringReviewTickHandler] now takes the route itself, before it raises.
/// This branch stays because two doors onto one bounded function is better than
/// one, and because it is the door a future caller that reaches the verdict-
/// absent case through `blockedArtifactMissing` would come through. What is NOT
/// left is the claim that it is the live path, and
/// `apps/server/test/engineering_review_composition_order_test.dart` drives the
/// REAL composition order ([runReviewLaneTick]) rather than this function in
/// isolation — which is precisely the gap that let an unreachable feature ship
/// green.
///
/// ## THERE IS NO LONGER A CASE THAT IS NOT A ROUTE, AND THAT IS THE FIX
///
/// This section used to be titled after `maxImplementationInflows`: when the
/// shared re-work discriminator was at the bound, the inflow would NOT route the
/// item, so routing it to `implementationReady` would leave it at
/// `agentCompleted` for ever with nobody acting on it, and this handler parked
/// it instead. Both halves of that argument are now false. The bound is removed
/// (decision `92d567e3-da03-4c43-99f4-e3726472f0ab`, `RETRY_LIMIT -> REMOVE`),
/// so the inflow routes such an item, and it no longer stands down in any case
/// that depends on how many times the item has been through this lane.
///
/// The parking that remains is the one that is still a parking: a producer that
/// could not be READ at all. That is an unknown, not a number, and an unknown
/// is not evidence that the platform is out of moves. And, for a producer that
/// DID commit, an item at `reviewInProgress` whose automatic re-review budget is
/// spent — see [maxAutomaticReviewReroutes] and [ReviewGateRoute.humanDecision],
/// which is what makes that member reachable rather than decorative.
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

  // ONE read of the ONE artifact predicate, and then the stand-down it decides
  // with. There is no second read: the re-work discriminator is no longer
  // consulted here, so an unreadable one cannot fail this handler.
  //
  // The read throws by design on unreadable durable state, and a handler that
  // throws would take the whole `review` section of the tick with it — every
  // other blocked job in that section unreported. An unreadable answer resolves
  // to `owns: false` with its reason, which is the conservative side of the
  // choice: this handler's job is to stop something being stranded on an
  // answer nobody established.
  //
  // The stand-down this feeds is scoped to `agentCompleted`, the one state the
  // inflow reads, so it can never suppress a park for an item that is somewhere
  // else.
  final produced = await _readProducedCommit(workerStore, item);
  final standDown = produced.produced == null
      ? (
          owns: false,
          why:
              'this item\'s producer could not be read (${produced.error}), so '
              'it is not possible to say the implementation lane would take it. '
              'Parking is the side of the choice that cannot strand the item',
        )
      : _implementationInflowOwns(produced.produced!);

  if (item.state == WorkItemState.agentCompleted) {
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
  } else if (item.state == WorkItemState.reviewInProgress) {
    // THE AUTOMATIC ROUTE. An item a reviewer entered and that concluded
    // nothing: the artifact answer says which lane can actually act, and
    // nothing else is going to ask.
    //
    // Reached only when the artifact answer is READABLE. An unreadable one is
    // `standDown.owns == false` with a reason, and it falls through to the
    // decision below rather than routing on an answer nobody established.
    final routed =
        produced.produced != null &&
        await _routeVerdictAbsentItem(
          workflowEngine: workflowEngine,
          item: item,
          job: job,
          produced: produced,
          implementationLaneWillRoute: standDown.owns,
          logger: logger,
        );
    if (routed) return;
  } else {
    logger?.call('engineering-review-missing-artifact-unexpected-state', {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'state': item.state.wire,
    });
    return;
  }

  if (item.state == WorkItemState.agentCompleted) {
    // THE PRODUCER, RESOLVED BY THE SHARED RULE — never by recency.
    //
    // This read `executionStore.latestExecutionForWorkItem`, the newest
    // execution of ANY role, which is correct exactly once — for the first
    // review of an item — and wrong for every one after, because
    // `LocalWorker` runs the reviewer as an execution too and a failed reviewer
    // is then the newest row. `agentResultValid()` would be handed the
    // REVIEWER's result as evidence that an IMPLEMENTER succeeded. That was
    // recorded unresolved at
    // `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §8
    // (`CONTRADICTION`, NOT RESOLVED) and is fixed here by calling the function
    // that already fixed it in `ExecutionCoordinator._reviewEntryTransitionContext`
    // and then in `raiseStallDecision`: `resolveProducerExecution`, which reads
    // the item's own `producerActorId` first and falls back to the newest
    // `AgentRole.implementer` — never to "whatever ran last".
    //
    // Two call sites re-deriving one rule is how they come to disagree; this is
    // now the third and last, and it delegates rather than transcribes. See
    // [ProducerResolution] for why the role fallback exists rather than failing
    // closed on a legacy item with no stamp.
    final producer = await resolveProducerExecution(
      store: executionStore,
      workItemId: workItemId,
      producerActorId: item.metadata?['producerActorId'],
    );
    final implementerResult = producer.result;
    if (implementerResult == null) {
      // `agentResultValid()` needs the implementer's completed result; without
      // it the entry transition is refused. Forcing it would fabricate the very
      // evidence that guard exists to check, so this is a visible block.
      logger?.call(
        'engineering-review-missing-artifact-no-implementer-result',
        {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'producer': producer.note,
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
  }
  // REACHED FROM EXACTLY TWO PLACES, and both are deliberate.
  //
  //  * `agentCompleted` — the stand-down above declined, so this handler has
  //    entered `reviewInProgress` (the only edge out of `agentCompleted` that
  //    leads to a human gate) and is about to raise.
  //  * `reviewInProgress` — the route above could not be taken: the artifact
  //    answer could not be read at all. THIS IS THE FALLBACK THAT INVARIANT 4
  //    REQUIRES. An item the platform cannot route is never dropped and never
  //    looped; it reaches a person on the decision that was already here. A
  //    producer that merely committed nothing is NOT in this list: the inflow
  //    routes that item, so it never reaches here.
  //
  // Every other state returned above, so no state check is repeated here: an
  // item in one of them is somebody else's to move and this handler is not
  // entitled to a say.

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
