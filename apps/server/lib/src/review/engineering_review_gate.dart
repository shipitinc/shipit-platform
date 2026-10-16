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
/// ## AND WHY IT IS CURRENTLY UNREACHABLE, WHICH IS NOT THE SAME AS POINTLESS
///
/// Stated plainly rather than left for a reader to discover: after the removal,
/// `owns: false` from the stand-down means the producer DID commit, and
/// [reviewGateRouteFor] turns a commit into [reReview]. The artifact-unreadable
/// case never arrives here either — it arrives as `produced == null`, and the
/// caller skips [reviewGateRouteFor] entirely and falls through to the decision.
/// So today this member has no input that reaches it.
///
/// It is kept because the safety property it encodes is the one that was just
/// paid for in production: "if this function ever cannot route, the answer is a
/// person, not a loop". Deleting the member would delete the case from the
/// switch and make a future unroutable input a silent no-route instead of a
/// compile-forced one. The guard that actually keeps the unreadable case out of
/// a loop is unchanged and is asserted by
/// `apps/server/test/engineering_review_verdict_absent_smoke_test.dart`.
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

/// The route for a review that concluded nothing, from the ONE artifact
/// predicate.
///
/// A `switch`, not an inline `if`, and not re-stated from the source: the input
/// is already a named function — [producedCommitFor] — and the asymmetry
/// between the two branches is the whole safety argument. A commit routes on
/// NO question about the implementation lane's budget at all, because
/// `agentCompleted -> reviewInProgress` is not an entry into that lane. A
/// producer that left nothing routes TO that lane, which under decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` no longer has a budget to be out of.
///
/// [humanDecision] is unreachable from the current caller; see its own
/// documentation for why it is kept anyway.
ReviewGateRoute reviewGateRouteFor({
  required ProducedCommit produced,
  required bool implementationLaneWillRoute,
}) => switch (produced) {
  CommitProduced() => ReviewGateRoute.reReview,
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
Future<bool> _routeVerdictAbsentItem({
  required DurableWorkflowEngine workflowEngine,
  required WorkItem item,
  required Job job,
  required _ProducedCommitRead produced,
  required bool implementationLaneWillRoute,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final commit = produced.produced!;
  final route = reviewGateRouteFor(
    produced: commit,
    implementationLaneWillRoute: implementationLaneWillRoute,
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
/// is not evidence that the platform is out of moves.
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
