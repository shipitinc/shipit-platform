// `_workflowEngine` and friends take initializers rather than `this._x` formals
// only because their public names are un-prefixed (`workflowEngine`) while the
// fields are private (`_workflowEngine`); an initializing formal cannot express
// that mapping.
// ignore_for_file: prefer_initializing_formals

import 'package:design_governance/design_governance.dart'
    show DesignGovernanceStore, DesignRevisionNotFoundException;
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowTransitionRejectedException;

import 'design_revision_producer.dart'
    show designRevisionIdMetadataKey, designerExecutionIdMetadataKey;
import '../implementation/design_scope_grant.dart'
    show designScopeDeclarationMetadata;

/// The `metadata` key under which a design-approval decision records the
/// verdict it was raised from, so the resolution path can tell an APPROVED plan
/// from one flagged for changes without reading the reviewer's English.
///
/// It is deliberately NOT `reviewVerdictAbsentMetadataKey` (the engineering
/// review gate's key): that key means "no reviewer produced a verdict", and the
/// design approval decision raised here exists precisely BECAUSE one did.
const String designReviewVerdictMetadataKey = 'designReviewVerdict';

/// The `metadata` key under which a design-approval decision raised from an
/// ABSENT verdict records WHY there was none.
///
/// A decision carrying this key asserts no verdict and is refused any choice
/// other than [designApprovalAbsentResolvableChoices] — see
/// [designApprovalAbsentChoiceIsResolvable]. It mirrors
/// `reviewVerdictAbsentMetadataKey` on the engineering-review side, one lane
/// over, and for the same reason: a decision for work no reviewer assessed must
/// not be resolvable as though a reviewer had spoken.
const String designReviewVerdictAbsentMetadataKey = 'designReviewVerdictAbsent';

/// The `recommendation` a design-approval decision carries when a reviewer
/// produced a verdict.
///
/// It is the reviewer's own verdict, uppercased, and nothing invented: the
/// operator reads the reviewer's assessment, not a platform paraphrase of it.
String designApprovalRecommendationFor(DesignReviewVerdict verdict) =>
    verdict.wire.toUpperCase();

/// The `recommendation` a design-approval decision carries when NO reviewer
/// produced a verdict.
///
/// Deliberately not a [DesignReviewVerdict] wire value and not the engineering
/// review gate's `NO VERDICT` line: this decision is still a blocking approval
/// gate on a design revision, and its recommendation must say both that there is
/// no assessment AND that the item is nevertheless in front of a person. It
/// opens with the literal words `NO VERDICT` so it cannot be skimmed as one.
const String designApprovalNoVerdictRecommendation =
    'NO VERDICT — NO REVIEWER ASSESSED THIS REVISION; READ THE RECORD, THEN '
    'APPROVE, SEND IT BACK, OR RETURN IT TO REVIEW';

/// The full three-choice menu a design approval offers.
///
/// ## WHY ALL THREE, AND NOT THE TWO THE STALE CONSTANT OFFERS
///
/// `design_scope_grant.dart`'s `designApprovalOptions` offers `approve` and
/// `reject` only, on the stated ground that `rework` "routes back to
/// `designInReview`, which no `JobDefinition` dispatches". **That ground is
/// false as of step 8**, and the design says so twice:
///
///  * `designReviewDefinition.entryStates` is `{designInReview}` and it IS
///    mounted (`sched-design-review`), so `designInReview` is dispatched — a
///    `rework` answer re-enqueues a review, which is exactly what §5.4 says a
///    rework answer judges (the REVIEW, not the design).
///  * §5.1 lists `rework` as one of the three choices the gate offers, and
///    `HumanDecisionRouting.targetFor(designApproval, rework)` returns
///    `designInReview` (`human_decision_routing.dart:97`), a live arm.
///
/// The stale constant is in `apps/server/lib/src/implementation/`, which this
/// lane does not own and must not edit; it is reported as a follow-up rather
/// than silently mirrored. This constant is the authoritative menu for the gate
/// this file raises, and it lists every choice the routing table understands so
/// the button and the state cannot drift.
///
/// Option ids are the WIRE values of [HumanDecisionChoice], so the option the
/// operator picks and the target the routing table resolves cannot disagree.
const List<HumanDecisionOption> designApprovalGateOptions = [
  HumanDecisionOption(
    optionId: 'approve',
    label: 'Approve this design',
    description:
        'The design is accepted. The work item moves to implementation behind '
        'a recorded scope grant.',
  ),
  HumanDecisionOption(
    optionId: 'reject',
    label: 'Reject this design',
    description:
        'The design is not accepted. The work item is sent back to be designed '
        'again and no scope grant is recorded.',
  ),
  HumanDecisionOption(
    optionId: 'rework',
    label: 'Send it back for another review',
    description:
        'The design is neither accepted nor rejected. The work item returns to '
        'design review for another independent assessment.',
  ),
];

/// The choices a design-approval decision raised from an ABSENT verdict may
/// resolve to.
///
/// `approve` is deliberately absent: an operator cannot approve a design no
/// reviewer assessed, which would be the platform accepting work on nobody's
/// authority. `reject` and `rework` both send the item back, which is the only
/// honest action when there is no assessment to act on.
const Set<HumanDecisionChoice> designApprovalAbsentResolvableChoices = {
  HumanDecisionChoice.reject,
  HumanDecisionChoice.rework,
};

/// Whether [decision] is a design-approval decision raised from an absent
/// verdict by this file.
///
/// A structural test on the record, not on a caller-settable flag: the key is
/// written by [raiseDesignApproval] alongside the cause, and its presence is
/// what the resolution path keys on.
bool isDesignApprovalAbsentDecision(HumanDecision decision) =>
    decision.metadata?[designReviewVerdictAbsentMetadataKey] != null;

/// Whether [choice] may resolve [decision].
///
/// Scoped to absent-verdict design approvals only, mirroring
/// `verdictAbsentChoiceIsResolvable` one lane over. A decision carrying a real
/// `designReviewVerdict` AND this marker at once is refused outright — the shape
/// that must never be resolvable as though a reviewer had spoken.
bool designApprovalAbsentChoiceIsResolvable(
  HumanDecision decision,
  HumanDecisionChoice choice,
) {
  if (!isDesignApprovalAbsentDecision(decision)) return true;
  if (decision.metadata?[designReviewVerdictMetadataKey] != null) return false;
  return designApprovalAbsentResolvableChoices.contains(choice);
}

/// Why a terminal design review produced no readable verdict.
///
/// Mirrors `_NoVerdictCause` on the engineering-review side. Each value names a
/// DIFFERENT incident, because "the reviewer said nothing" and "the reviewer's
/// answer was unreadable" are different remedies.
enum DesignReviewNoVerdictCause {
  /// The reviewer execution settled in a non-assessing terminal state and wrote
  /// no result.
  reviewerExecutionFailed('reviewer_execution_failed'),

  /// The reviewer execution completed but the store holds no result for it.
  reviewerResultMissing('reviewer_result_missing'),

  /// A result exists but carries no verdict at all.
  verdictAbsent('verdict_absent'),

  /// A verdict string exists and is not one of [DesignReviewVerdict]'s values.
  verdictUnreadable('verdict_unreadable'),

  /// The result's structured payload could not be read.
  structuredResultUnreadable('structured_result_unreadable');

  const DesignReviewNoVerdictCause(this.wire);

  final String wire;
}

/// "There is no verdict", with the cause that says WHY.
///
/// The counterpart [DesignReviewVerdict] cannot be: it exists only to become a
/// durable record and a log line, never to be turned into a verdict and never
/// shown to a human as an assessment. See the engineering-review gate's
/// `_NoVerdict` for the full argument against a verdict-less enum member.
class DesignReviewNoVerdict {
  const DesignReviewNoVerdict(this.cause, this.detail);

  final DesignReviewNoVerdictCause cause;
  final String detail;
}

/// Exactly one of the two fields is non-null.
typedef DesignReviewRead = ({
  DesignReviewResult? result,
  DesignReviewNoVerdict? absence,
});

/// Reads the reviewer's verdict, or says why there is none.
///
/// Everything returned that is not a [DesignReviewResult] is an absence, and an
/// absence is never turned into a verdict on the way out: there is no default
/// verdict here, because a default would be the fabrication this recorder exists
/// to prevent.
///
/// The READ ORDER mirrors `_readReviewVerdict`:
///  1. an embedded, fully-formed `designReviewResult` object carries its own
///     verdict and findings and is read first (a parse failure falls THROUGH to
///     the wire path, which can still produce an honest verdict);
///  2. otherwise the wire fields — `verdict` is REQUIRED, `findings` and
///     `assessedDimensions` are read if present.
DesignReviewRead _readDesignReview({
  required Job job,
  required String workItemId,
  required String executionId,
  required AgentExecution execution,
  required AgentResult? reviewerResult,
  required String revisionId,
  required DateTime createdAt,
  void Function(String message, Map<String, dynamic> context)? logger,
}) {
  if (reviewerResult == null) {
    return (
      result: null,
      absence: DesignReviewNoVerdict(
        execution.status == AgentSessionStatus.completed
            ? DesignReviewNoVerdictCause.reviewerResultMissing
            : DesignReviewNoVerdictCause.reviewerExecutionFailed,
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
      absence: DesignReviewNoVerdict(
        DesignReviewNoVerdictCause.structuredResultUnreadable,
        'the reviewer result could not be read: $e',
      ),
    );
  }

  final embedded = structured['designReviewResult'];
  if (embedded is Map) {
    try {
      final parsed = DesignReviewResult.fromJson(
        Map<String, dynamic>.from(embedded),
      );
      return (result: parsed, absence: null);
    } on Object catch (e) {
      logger?.call('design.review.recorder.embedded-result-unparseable', {
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
      absence: DesignReviewNoVerdict(
        DesignReviewNoVerdictCause.verdictAbsent,
        'the reviewer returned a result carrying no verdict',
      ),
    );
  }

  final DesignReviewVerdict verdict;
  try {
    verdict = DesignReviewVerdict.fromWire(verdictWire);
  } on Object catch (e) {
    return (
      result: null,
      absence: DesignReviewNoVerdict(
        DesignReviewNoVerdictCause.verdictUnreadable,
        "'$verdictWire' is not a design review verdict ($e)",
      ),
    );
  }

  final findings = <DesignFinding>[];
  final rawFindings = structured['findings'];
  if (rawFindings is List) {
    for (var i = 0; i < rawFindings.length; i++) {
      final x = rawFindings[i];
      if (x is! Map) continue;
      try {
        findings.add(
          DesignFinding.fromJson(
            _withFindingRunIdentity(
              Map<String, dynamic>.from(x),
              revisionId: revisionId,
              executionId: executionId,
              createdAt: createdAt,
              index: i,
            ),
          ),
        );
      } on Object catch (e) {
        logger?.call('design.review.recorder.finding-dropped', {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'executionId': executionId,
          'index': i,
          'error': '$e',
        });
      }
    }
  }

  final assessed = <String>[];
  final rawAssessed = structured['assessedDimensions'];
  if (rawAssessed is List) {
    for (final d in rawAssessed) {
      if (d is String && d.isNotEmpty) assessed.add(d);
    }
  }

  return (
    result: DesignReviewResult(
      reviewExecutionId: executionId,
      revisionId: revisionId,
      verdict: verdict,
      findings: findings,
      assessedDimensions: assessed,
      createdAt: createdAt,
      version: 1,
    ),
    absence: null,
  );
}

/// Supplies the four [DesignFinding] fields that are RUN identity rather than
/// review content, and only those.
///
/// Mirrors `_withReviewRunIdentity` on the engineering-review side: a reviewer
/// cannot know its own `reviewExecutionId` or the revision id it is reviewing,
/// and inventing them would be fabricated provenance — but a finding that omits
/// them fails `DesignFinding.fromJson` and is dropped. The reviewer's own
/// reported values for these fields are kept when present; only the missing
/// ones are completed, from the run this recorder is already holding.
Map<String, dynamic> _withFindingRunIdentity(
  Map<String, dynamic> raw, {
  required String revisionId,
  required String executionId,
  required DateTime createdAt,
  required int index,
}) {
  final completed = Map<String, dynamic>.from(raw);
  completed.putIfAbsent(
    'findingId',
    () => 'finding-$executionId-$index',
  );
  completed.putIfAbsent('revisionId', () => revisionId);
  completed.putIfAbsent('reviewExecutionId', () => executionId);
  completed.putIfAbsent('createdAt', () => createdAt.toIso8601String());
  completed.putIfAbsent('version', () => 1);
  return completed;
}

/// What recording one terminal design review did with one work item.
enum DesignReviewRecorderOutcome {
  /// A durable `DesignReviewResult` was written AND a blocking
  /// `designApproval` decision is now attached to the work item.
  recorded,

  /// The result was already durable and a decision was already pending: a
  /// repeated tick changed nothing.
  alreadyRecorded,

  /// The item is not in a state this recorder acts on. Nothing was written.
  skippedWrongState,

  /// The revision id is unreadable, or the revision is not readable, so there
  /// is nothing to record against. Fail closed; nothing was written.
  revisionUnreadable,

  /// No reviewer execution could be resolved for this job. Fail closed; nothing
  /// was written.
  executionUnresolved,

  /// The verdict is absent or unreadable. The absence was recorded durably on
  /// the reviewer's execution timeline, and a labelled non-verdict
  /// `designApproval` decision was raised so the work item is not silently
  /// stranded. No `DesignReviewResult` was invented.
  noVerdict,

  /// The engine refused the gate entry. The item is left where it was and still
  /// needs a person; this is a visible block, not a quiet one.
  refused,
}

/// The sentence that states what recording ACTUALLY did with one work item.
///
/// Only [DesignReviewRecorderOutcome.recorded] may claim that something was
/// raised or written; every other outcome says what it did NOT do, so a log line
/// cannot read as a success it did not have.
String designReviewRecorderSentence(DesignReviewRecorderOutcome outcome) {
  switch (outcome) {
    case DesignReviewRecorderOutcome.recorded:
      return 'recorded the review verdict durably and raised a blocking '
          'designApproval decision for it';
    case DesignReviewRecorderOutcome.alreadyRecorded:
      return 'not re-recorded; the verdict is already durable and the item is '
          'already parked behind a pending designApproval decision';
    case DesignReviewRecorderOutcome.skippedWrongState:
      return 'not recorded; the item is not at designInReview and not parked '
          'behind this gate';
    case DesignReviewRecorderOutcome.revisionUnreadable:
      return 'not recorded; the revision id is missing or the revision is not '
          'readable, so there is nothing to record a verdict against. Nothing '
          'was written';
    case DesignReviewRecorderOutcome.executionUnresolved:
      return 'not recorded; no reviewer execution could be resolved for this '
          'job, so there is nothing to read a verdict from. Nothing was written';
    case DesignReviewRecorderOutcome.noVerdict:
      return 'no DesignReviewResult was written (there is no verdict), but the '
          'absence is durable on the reviewer\'s execution timeline and a '
          'non-verdict designApproval decision was raised so the item is not '
          'stranded';
    case DesignReviewRecorderOutcome.refused:
      return 'not recorded; the engine refused the gate entry and wrote '
          'nothing. The item is still at designInReview and still needs a '
          'person';
  }
}

/// The composition root's recorder for terminal `designReview` jobs (design
/// step 9, gap G-C).
///
/// ## WHAT IT REPLACES
///
/// `design_review_observer.dart` logged a terminal `designReview` job and said,
/// in the record, that no decision was raised. That was correct for step 8 and
/// is wrong now: step 9 exists to consume the review verdict that step 8 made
/// durable, record it as a [DesignReviewResult] row (`saveDesignReviewResult`
/// had stores and contract tests but no production caller — F-224a), and raise
/// the blocking [HumanDecisionType.designApproval] gate that has been callerless
/// (G-C) since the edges and routing were added.
///
/// ## THE ORDER, AND WHY IT IS THIS WAY
///
/// 1. **Read the revision the item names.** The producer stamps
///    `designRevisionId` onto the item atomically with `designerExecutionId`.
///    A review is OF a revision; without one there is nothing to record against,
///    so an unreadable revision fails closed.
/// 2. **Resolve the reviewer execution**, preferring the job's own
///    `executionReference.agentExecutionId` and falling back to the most recent
///    TERMINAL execution whose role was the design reviewer. Recency is a
///    fallback, not the first choice, because a job that names its execution is
///    the strongest evidence of which run is under adjudication.
/// 3. **Read the verdict, or record its absence.** There is no default verdict.
/// 4. **Persist the result BEFORE raising**, so a crash between the two leaves a
///    durable result and no decision (a state the next tick repairs) rather than
///    a decision with no result behind it.
/// 5. **Raise the blocking `designApproval`** — unconditionally when a verdict
///    exists (step 9 / D4: every revision is HIGH and gated), and, for an absent
///    verdict, as a labelled non-verdict decision so the item is not stranded.
///
/// ## IDEMPOTENCE
///
/// Two independent checks, mirroring the engineering-review gate:
///  * an item already at `waitingForHumanDecision` is returned from immediately,
///    so a repeated tick does not mint a second question;
///  * `readDesignReviewResultForExecution` is consulted before the write, so a
///    crash-replay does not double-write the result.
///
/// `DurableWorkflowEngine.requestHumanDecision` is itself idempotent for a
/// repeated raise, so this is belt-and-braces over an idempotency that exists
/// independently, not a competing mechanism.
class DesignReviewRecorder {
  DesignReviewRecorder({
    required DurableWorkflowEngine workflowEngine,
    required ExecutionStore executionStore,
    required DesignGovernanceStore designGovernanceStore,
    required void Function(String message, Map<String, dynamic> context) logger,
    DateTime Function()? clock,
  }) : _workflowEngine = workflowEngine,
       _executionStore = executionStore,
       _designGovernanceStore = designGovernanceStore,
       _logger = logger,
       _clock = clock ?? _utcNow;

  final DurableWorkflowEngine _workflowEngine;
  final ExecutionStore _executionStore;
  final DesignGovernanceStore _designGovernanceStore;
  final void Function(String message, Map<String, dynamic> context) _logger;
  final DateTime Function() _clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Consumes one terminal `designReview` job. Returns what it did, so the
  /// caller can distinguish "a decision was raised" from "nothing happened"
  /// without parsing the log.
  Future<DesignReviewRecorderOutcome> record(Job job) async {
    final workItemId = job.workItemId;
    final item = await _workflowEngine.loadWorkItem(workItemId);

    if (item.state == WorkItemState.waitingForHumanDecision) {
      _logger('design.review.recorder.already-parked', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'decisionId': item.blockingHumanDecisionId,
      });
      return DesignReviewRecorderOutcome.alreadyRecorded;
    }
    if (item.state != WorkItemState.designInReview) {
      _logger('design.review.recorder.skip-non-reviewing-state', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'state': item.state.name,
      });
      return DesignReviewRecorderOutcome.skippedWrongState;
    }

    // ---- 1. The revision being reviewed ----
    final revisionId = item.metadata?[designRevisionIdMetadataKey];
    if (revisionId is! String || revisionId.isEmpty) {
      _logger('design.review.recorder.revision-unreadable', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'reason':
            'the work item carries no $designRevisionIdMetadataKey, so no '
            'review verdict can be recorded against a revision',
      });
      return DesignReviewRecorderOutcome.revisionUnreadable;
    }

    final DesignRevision revision;
    try {
      revision = await _designGovernanceStore.readDesignRevision(revisionId);
    } on DesignRevisionNotFoundException catch (e) {
      _logger('design.review.recorder.revision-unreadable', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'revisionId': revisionId,
        'reason': 'the design revision is not readable',
        'error': '$e',
      });
      return DesignReviewRecorderOutcome.revisionUnreadable;
    }
    if (revision.workItemId != workItemId) {
      _logger('design.review.recorder.revision-unreadable', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'revisionId': revisionId,
        'revisionWorkItemId': revision.workItemId,
        'reason': 'the design revision belongs to a different work item',
      });
      return DesignReviewRecorderOutcome.revisionUnreadable;
    }

    // ---- 2. The reviewer execution ----
    final execution = await _resolveReviewerExecution(job, workItemId);
    if (execution == null) {
      _logger('design.review.recorder.execution-unresolved', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'revisionId': revisionId,
        'jobExecutionId': job.executionReference?.agentExecutionId,
        'reason':
            'neither the job\'s own execution reference nor a settled '
            'design-reviewer execution for this item could be resolved',
      });
      return DesignReviewRecorderOutcome.executionUnresolved;
    }
    final executionId = execution.executionId;

    // ---- The idempotence read ----
    final existing = await _designGovernanceStore
        .readDesignReviewResultForExecution(
          revisionId,
          executionId,
        );

    final reviewerResult = await _executionStore.readResult(executionId);
    final read = _readDesignReview(
      job: job,
      workItemId: workItemId,
      executionId: executionId,
      execution: execution,
      reviewerResult: reviewerResult,
      revisionId: revisionId,
      createdAt: _clock(),
      logger: _logger,
    );

    final absence = read.absence;
    if (absence != null) {
      // NO VERDICT. Record the absence durably on the reviewer's own execution
      // timeline, then raise a labelled non-verdict decision so the item is not
      // stranded. Nothing that resembles a verdict is written.
      await _recordNoVerdict(
        job: job,
        workItemId: workItemId,
        executionId: executionId,
        absence: absence,
      );
      return _raiseForAbsence(
        job: job,
        item: item,
        revisionId: revisionId,
        executionId: executionId,
        absence: absence,
      );
    }

    // ---- 3. Persist the result, BEFORE raising ----
    if (existing == null) {
      try {
        await _designGovernanceStore.saveDesignReviewResult(read.result!);
      } on Object catch (e) {
        // A store that refuses the write must not silently proceed to raise a
        // decision over a verdict that is not durable. Fail closed and say so.
        _logger('design.review.recorder.result-write-failed', {
          'jobId': job.jobId,
          'workItemId': workItemId,
          'revisionId': revisionId,
          'executionId': executionId,
          'error': '$e',
          'action':
              'the review verdict was NOT recorded and no decision was raised. '
              'The item stays at designInReview and the next tick retries',
        });
        return DesignReviewRecorderOutcome.revisionUnreadable;
      }
      _logger('design.review.recorder.result-recorded', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'revisionId': revisionId,
        'executionId': executionId,
        'verdict': read.result!.verdict.wire,
        'findingCount': read.result!.findings.length,
      });
    } else {
      _logger('design.review.recorder.result-already-recorded', {
        'jobId': job.jobId,
        'workItemId': workItemId,
        'revisionId': revisionId,
        'executionId': executionId,
        'verdict': existing.verdict.wire,
      });
    }

    // ---- 4. Raise the blocking designApproval gate, unconditionally ----
    return _raiseApproval(
      job: job,
      item: item,
      revision: revision,
      executionId: executionId,
      result: read.result!,
    );
  }

  /// Logs what the drain-table handler did with one terminal job.
  ///
  /// Separate from [record]'s own per-step logging because it is the ONE place
  /// that says, per job, what the handler as a whole concluded — and it reads
  /// the sentence from [designReviewRecorderSentence], so a log line cannot
  /// claim a raise that did not happen.
  void logHandlerOutcome(Job job, DesignReviewRecorderOutcome outcome) {
    _logger('design.review.recorder.handled', {
      'jobId': job.jobId,
      'workItemId': job.workItemId,
      'outcome': outcome.name,
      'decision': designReviewRecorderSentence(outcome),
    });
  }

  /// Resolves the reviewer execution under adjudication.
  ///
  /// PREFERS the job's own `executionReference.agentExecutionId`; that is the
  /// run this job was holding, and it is the strongest evidence of which run is
  /// under review. Falls back to the most recent TERMINAL execution for the item
  /// whose role was [AgentRole.designReviewer] — the shape a lease expiry leaves,
  /// where the job row is `reconciled` and no longer names a settled run.
  Future<AgentExecution?> _resolveReviewerExecution(
    Job job,
    String workItemId,
  ) async {
    final referenced = job.executionReference?.agentExecutionId;
    if (referenced != null && referenced.isNotEmpty) {
      final execution = await _executionStore.readExecutionOrNull(referenced);
      if (execution != null) return execution;
    }

    final executions = await _executionStore.listExecutions(
      workItemId: workItemId,
    );
    final reviewers =
        executions
            .where((e) => e.role == AgentRole.designReviewer && e.isTerminal)
            .toList()
          ..sort((a, b) {
            final aAt = a.startedAt ?? a.completedAt;
            final bAt = b.startedAt ?? b.completedAt;
            if (aAt == null || bAt == null) return 0;
            return bAt.compareTo(aAt);
          });
    return reviewers.isEmpty ? null : reviewers.first;
  }

  /// Records an absent verdict durably on the reviewer's execution timeline.
  ///
  /// It is a [AgentEventType.warning], not `executionFailed`: a reviewer that
  /// ended on its own turn with an unreadable payload did NOT fail, and stamping
  /// a failure onto it would be the same fabrication this recorder exists to
  /// stop, one layer down. A store that refuses the write must not take the tick
  /// down with it; the decision below is still raised and the log line still says
  /// why.
  Future<void> _recordNoVerdict({
    required Job job,
    required String workItemId,
    required String executionId,
    required DesignReviewNoVerdict absence,
  }) async {
    final detail = {
      'jobId': job.jobId,
      'workItemId': workItemId,
      'executionId': executionId,
      'cause': absence.cause.wire,
      'why': absence.detail,
      'jobState': job.state.wire,
    };
    _logger('design.review.recorder.no-verdict', detail);

    try {
      final prior = await _executionStore.readEvents(executionId);
      final sequence =
          prior.fold<int>(0, (max, e) => e.sequence > max ? e.sequence : max) +
          1;
      final now = _clock();
      await _executionStore.appendEvent(
        AgentEventRecord(
          eventId:
              'design-no-verdict-$executionId-${now.microsecondsSinceEpoch}',
          executionId: executionId,
          workItemId: workItemId,
          sequence: sequence,
          type: AgentEventType.warning,
          occurredAt: now,
          payload: {
            'designReviewGate': 'no_verdict',
            'cause': absence.cause.wire,
            'detail': absence.detail,
          },
        ),
      );
    } on Object catch (e) {
      _logger('design.review.recorder.no-verdict-record-failed', {
        ...detail,
        'error': '$e',
      });
    }
  }

  /// Raises the blocking `designApproval` for a durable verdict, idempotently.
  Future<DesignReviewRecorderOutcome> _raiseApproval({
    required Job job,
    required WorkItem item,
    required DesignRevision revision,
    required String executionId,
    required DesignReviewResult result,
  }) async {
    final producerActorId =
        item.metadata?[designerExecutionIdMetadataKey] as String?;
    final declaredPaths = revision.declaredOwnedPaths ?? const <String>[];
    try {
      await _workflowEngine.requestHumanDecision(
        workItemId: item.workItemId,
        decisionType: HumanDecisionType.designApproval,
        question: _approvalQuestion(result),
        options: designApprovalGateOptions,
        recommendation: designApprovalRecommendationFor(result.verdict),
        blocking: true,
        metadata: {
          'designReviewResult': result.toJson(),
          'reviewExecutionId': executionId,
          designReviewVerdictMetadataKey: result.verdict.wire,
          ...designScopeDeclarationMetadata(
            declaredOwnedPaths: declaredPaths,
            decisionType: HumanDecisionType.designApproval,
            declaredBy: 'design-review-recorder',
            declaredAt: _clock(),
          ),
        },
        // The ORCHESTRATOR, not the reviewer: this is a platform gate on the
        // revision, not something the reviewer said about itself. The edge
        // `designInReview -> waitingForHumanDecision` admits the orchestrator.
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        extraContext: {
          if (producerActorId != null) 'producerActorId': producerActorId,
          'reviewExecutionId': executionId,
        },
      );
    } on WorkflowTransitionRejectedException catch (e) {
      _logger('design.review.recorder.approval-refused', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'revisionId': revision.revisionId,
        'executionId': executionId,
        'verdict': result.verdict.wire,
        'error': e.toString(),
        'action':
            'the verdict IS durable, but no decision was raised and the item '
            'is still at designInReview. It still needs a person',
      });
      return DesignReviewRecorderOutcome.refused;
    }

    _logger('design.review.recorder.approval-raised', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'revisionId': revision.revisionId,
      'executionId': executionId,
      'verdict': result.verdict.wire,
      'blocking': true,
    });
    return DesignReviewRecorderOutcome.recorded;
  }

  /// Raises the labelled non-verdict `designApproval` for an absent verdict.
  ///
  /// The item is still a design revision awaiting approval; the difference from
  /// [_raiseApproval] is that this decision asserts NO verdict and offers only
  /// reject/rework — see [designApprovalAbsentResolvableChoices].
  Future<DesignReviewRecorderOutcome> _raiseForAbsence({
    required Job job,
    required WorkItem item,
    required String revisionId,
    required String executionId,
    required DesignReviewNoVerdict absence,
  }) async {
    final producerActorId =
        item.metadata?[designerExecutionIdMetadataKey] as String?;
    try {
      await _workflowEngine.requestHumanDecision(
        workItemId: item.workItemId,
        decisionType: HumanDecisionType.designApproval,
        question: _noVerdictQuestion(
          absence: absence,
          executionId: executionId,
          revisionId: revisionId,
        ),
        options: const [
          HumanDecisionOption(
            optionId: 'reject',
            label: 'Reject this design',
            description:
                'The design is not accepted. The work item is sent back to be '
                'designed again.',
          ),
          HumanDecisionOption(
            optionId: 'rework',
            label: 'Send it back for another review',
            description:
                'The design is neither accepted nor rejected. The work item '
                'returns to design review for another assessment.',
          ),
        ],
        recommendation: designApprovalNoVerdictRecommendation,
        blocking: true,
        metadata: {
          designReviewVerdictAbsentMetadataKey: {
            'verdictRecorded': false,
            'cause': absence.cause.wire,
            'detail': absence.detail,
            'reviewExecutionId': executionId,
            'revisionId': revisionId,
          },
          'reviewExecutionId': executionId,
        },
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        extraContext: {
          if (producerActorId != null) 'producerActorId': producerActorId,
          'reviewExecutionId': executionId,
        },
      );
    } on WorkflowTransitionRejectedException catch (e) {
      _logger('design.review.recorder.no-verdict-decision-refused', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'executionId': executionId,
        'cause': absence.cause.wire,
        'error': e.toString(),
        'action':
            'no decision was raised and the item stays at designInReview; the '
            'absence is on the reviewer\'s execution timeline',
      });
      return DesignReviewRecorderOutcome.refused;
    }

    _logger('design.review.recorder.no-verdict-decision-raised', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'revisionId': revisionId,
      'executionId': executionId,
      'cause': absence.cause.wire,
      'blocking': true,
    });
    return DesignReviewRecorderOutcome.noVerdict;
  }

  String _approvalQuestion(DesignReviewResult result) {
    final buffer = StringBuffer()
      ..writeln('Approve this design revision?')
      ..writeln()
      ..writeln('An independent design review has recorded its verdict.')
      ..writeln()
      ..writeln('  verdict:   ${result.verdict.wire}')
      ..writeln('  findings:  ${result.findings.length}')
      ..writeln(
        '  assessed:  ${result.assessedDimensions.isEmpty ? 'none recorded' : result.assessedDimensions.join(', ')}',
      );
    return buffer.toString();
  }

  String _noVerdictQuestion({
    required DesignReviewNoVerdict absence,
    required String executionId,
    required String revisionId,
  }) {
    return (StringBuffer()
          ..writeln(
            'NO VERDICT. Nothing has been assessed on this design revision.',
          )
          ..writeln()
          ..writeln(
            'The design review produced no readable verdict, so there is no '
            'approval and no request for changes here. This is not a reviewer '
            'having found the design acceptable — it is a review the platform '
            'could not read a conclusion from.',
          )
          ..writeln()
          ..writeln('  cause:     ${absence.cause.wire}')
          ..writeln('  detail:    ${absence.detail}')
          ..writeln('  reviewer:  $executionId')
          ..writeln('  revision:  $revisionId')
          ..writeln()
          ..writeln(
            'Choose "Reject this design" to send it back to be designed again, '
            'or "Send it back for another review" to have it reviewed again. '
            'Neither answer approves this design, because no reviewer produced '
            'a verdict.',
          ))
        .toString();
  }
}

/// Builds the terminal-job handler every drain table registers for
/// [JobType.designReview].
///
/// ## WHY A SHARED FACTORY, AND NOT FOUR INLINE CLOSURES
///
/// Every `Scheduler.tick()` step 1 reconciles EVERY held job in the shared
/// `JobStore`, so a terminal `designReview` job can surface in the triage
/// drain, the review drain, or either of the design drain's two tables. Step 8
/// registered the OBSERVER in all four; step 9 must register the RECORDER in all
/// four, and the reachability requirement is that a given terminal job is
/// recorded EXACTLY once regardless of which drain reconciles it — which the
/// recorder's own idempotence provides, not the drain.
///
/// A factory keeps the four registrations identical by construction. Four
/// hand-written closures is four places for one of them to drift back to the
/// log-only observer, and the failure mode is silent: the job is "handled" and
/// nothing is recorded.
///
/// The returned function is structurally a `TickJobHandler`
/// (`Future<void> Function(Job)`); it is not typed as one to avoid a dependency
/// from this file onto the triage hook's typedef.
///
/// [unconsumedJobIds], when supplied, receives the job id so the design tick can
/// report which terminal reviews it recorded; the id is added uniformly for the
/// job the handler was handed, and the recorder's outcome is logged alongside it
/// so a fail-closed outcome (`revisionUnreadable`, `executionUnresolved`) is
/// distinguishable from a recorded one without re-reading the log.
Future<void> Function(Job job) designReviewRecorderHandler({
  required DesignReviewRecorder recorder,
  List<String>? unconsumedJobIds,
}) {
  return (Job job) async {
    final outcome = await recorder.record(job);
    unconsumedJobIds?.add(job.jobId);
    recorder.logHandlerOutcome(job, outcome);
  };
}
