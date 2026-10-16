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
Future<void> _recordNoVerdict({
  required ExecutionStore executionStore,
  required Job job,
  required String workItemId,
  required String executionId,
  required _NoVerdict absence,
  required bool reviewCompleted,
  void Function(String message, Map<String, dynamic> context)? logger,
}) async {
  final detail = {
    'jobId': job.jobId,
    'workItemId': workItemId,
    'executionId': executionId,
    'cause': absence.cause.wire,
    'why': absence.detail,
    // Says WHAT WAS DONE about it, because "no verdict" on its own is exactly
    // the sentence that left four items invisible: the reader cannot tell a gate
    // that is handling this from a gate that dropped it.
    //
    // AND ONLY WHAT IS ALREADY TRUE WHEN THIS LINE IS WRITTEN. When the review
    // completed, the decision is raised by the CALLER, after this record, and
    // `raiseVerdictAbsentDecision` has three outcomes that write nothing
    // (`alreadyPending`, `producerIdentityUnreadable`, `refused`). A sentence
    // emitted here claiming a decision was raised would therefore be false on
    // every one of them — the same class of statement this gate exists to end,
    // one layer down, and the exact sentence removed at a different layer. So
    // this line claims the absence record and nothing else; the caller logs
    // what the raise actually did.
    'decision': reviewCompleted
        ? 'no decision claimed by this record. It states the absence, which is '
              'durable on the reviewer\'s execution timeline; the verdict-less '
              'decision is handled straight afterwards and reports its own '
              'outcome under engineering-review-gate-no-verdict-decision'
        : 'not raised; this review has not finished, so the reviewer job\'s own '
              'bounded maxAttempts is still owed a retry and the item is left '
              'retryable at review_in_progress',
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
/// Takes the facts, not the file-private [_NoVerdict]: this is the operator-facing
/// text of a durable record, and its inputs are two strings and an id.
String verdictAbsentQuestion({
  required String cause,
  required String detail,
  required String executionId,
  required String? producerExecutionId,
  required String? reviewProse,
}) {
  final prose = (reviewProse ?? '').trim();
  final buffer = StringBuffer()
    ..writeln('NO VERDICT. Nothing has been assessed on this work item.')
    ..writeln()
    ..writeln(
      'The engineering review ran to completion and this build could not read a '
      'review verdict from what it returned. So there is no approval and no '
      'request for changes here, and no findings have been accepted or '
      'rejected — not because a reviewer found none, but because no reviewer '
      'produced a verdict to act on. The review PROCESS succeeded; that is not '
      'the same as the review CONCLUDING anything.',
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
Map<String, dynamic> verdictAbsentMetadata({
  required String cause,
  required String detail,
  required String executionId,
  required String? producerActorId,
  required String? reviewProse,
}) => {
  reviewVerdictAbsentMetadataKey: {
    'verdictRecorded': false,
    'cause': cause,
    'detail': detail,
    'reviewExecutionId': executionId,
    'reviewedRevisionExecutionId': producerActorId,
    // Carried so a surface can show how much the reviewer actually said. Null
    // is a real answer here: "it wrote nothing" is what the operator needs to
    // see, and it is different from "its prose is not readable here".
    'reviewProsePresent': (reviewProse ?? '').trim().isNotEmpty,
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
          'verdict, carries the reviewer\'s own prose, and offers only rework '
          'and cancel';
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

/// Raises the verdict-less decision for a review that completed with none,
/// idempotently.
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
          'no decision was raised. This review completed without a verdict and '
          'nothing else will move this item, so the absence is on the '
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
      ),
      options: verdictAbsentOptions,
      recommendation: verdictAbsentRecommendation,
      blocking: true,
      metadata: verdictAbsentMetadata(
        cause: cause,
        detail: detail,
        executionId: executionId,
        producerActorId: producerActorId,
        reviewProse: reviewProse,
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

/// Builds a tick handler for engineering review jobs. When the reviewer
/// execution reaches a terminal state, this raises a blocking
/// `engineeringReview` HumanDecision to move `reviewInProgress` to
/// `waitingForHumanDecision`.
///
/// ## IT RAISES A VERDICT-LESS DECISION FOR A REVIEW THAT COMPLETED WITHOUT ONE
///
/// The original b1 rule was: if the reviewer produced no verdict, record why and
/// return, leaving the item at `reviewInProgress`. That is still exactly right
/// for a review that did NOT finish — a budget kill, a crash, a missing result.
/// There the reviewer job's own bounded `maxAttempts` is still owed a retry, and
/// `Scheduler._returnOneToEntryState` returns the item to a lane entry state to
/// make it claimable, while `waitingForHumanDecision` is explicitly skipped by
/// that return. Parking those items would pre-empt a retry that is coming.
///
/// It is wrong for a review that DID finish. Measured on 2026-10-15: four review
/// executions reached `completed` against real commits (one `18ad90a`, +957/-199)
/// and produced real findings in their prose, every one of them recorded `{}` in
/// `structuredResultJson`, so no verdict was parsed, so no decision was raised,
/// so all four items sat at `reviewInProgress` with nothing on any operator
/// screen and no retry coming — the job SUCCEEDED, and `maxAttempts` only ever
/// retries a failure. A review that concluded nothing and a review that passed
/// were indistinguishable, and that is the false state this whole programme
/// exists to end.
///
/// So the gate now raises ONE more decision, under decision
/// `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option A),
/// and it is a decision that asserts NO VERDICT:
///
///  * it names the absence and its cause in its own text, and never carries a
///    `ReviewVerdict` anywhere — not in `metadata`, not in
///    `extraContext`, not in a recommendation that reads like one;
///  * it carries the reviewer's ACTUAL prose, because the reviewer did real
///    work and hiding it would replace one false state with another;
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
      await _recordNoVerdict(
        executionStore: executionStore,
        job: job,
        workItemId: workItemId,
        executionId: executionId,
        absence: absence,
        // THE ONLY DIFFERENCE SINCE b1, and it is one word. `completed` means the
        // review ran to the end of its turn and nothing will retry it, so the
        // only thing that can still move this item is a person. Anything else
        // (`failed`, `interrupted`) still has `maxAttempts` owed to it, and this
        // gate must not take the item out from under that retry.
        reviewCompleted: execution.status == AgentSessionStatus.completed,
        logger: logger,
      );

      if (execution.status == AgentSessionStatus.completed) {
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
