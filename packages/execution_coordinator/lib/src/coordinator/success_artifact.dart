import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'workspace_delta_probe.dart';

/// What a lane's completed execution must have produced for the completion to
/// be true.
///
/// ## WHY THERE IS NO SINGLE ANSWER
///
/// `agent_completed` is SHARED by every producing lane. Triage legitimately
/// finishes without touching the product — it writes a classification report
/// into a scratch repo, never code — so a universal "no files changed means
/// failure" rule would fail every triage run. Human decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` chose `ROLE_AWARE`, and this enum is
/// that choice expressed once.
///
/// Measured motivation: seven IMPLEMENTER executions existed in QA, all seven
/// completed with zero files touched and zero commits, and all seven still
/// reached `agent_completed` — which is the state `engineeringReviewDefinition`
/// dispatches from, so the review lane then failed closed forever because there
/// was no artifact to review.
enum SuccessArtifactKind {
  /// A commit: the execution changed the repository.
  committedCode,

  /// A structured classification result — triage's deliverable.
  classificationResult,

  /// A parseable review verdict.
  reviewVerdict,

  /// This lane has no defined artifact here, so it is not judged by this rule.
  ///
  /// Deliberately the default for every role the human decision did not name.
  /// Inventing an artifact for the design and QA lanes from inside this rule
  /// would fail work this change knows nothing about, on evidence no one
  /// gathered.
  unspecified,
}

/// Whether an execution satisfied its lane's artifact.
enum ArtifactSatisfaction {
  /// The lane's artifact is present. The execution completed truthfully.
  satisfied,

  /// The lane's artifact is provably absent. This is a permanent failure.
  missing,

  /// The artifact could not be established. Not a failure — see
  /// [RoleAwareSuccessArtifacts] for why this must never be laundered into
  /// [missing].
  undetermined,
}

/// The verdict on one execution's success artifact.
@immutable
class SuccessArtifactVerdict {
  const SuccessArtifactVerdict._({
    required this.satisfaction,
    required this.kind,
    this.reason,
    this.details = const {},
  });

  const SuccessArtifactVerdict.satisfied(SuccessArtifactKind kind)
    : this._(satisfaction: ArtifactSatisfaction.satisfied, kind: kind);

  const SuccessArtifactVerdict.missing(
    SuccessArtifactKind kind,
    String reason, {
    Map<String, dynamic> details = const {},
  }) : this._(
         satisfaction: ArtifactSatisfaction.missing,
         kind: kind,
         reason: reason,
         details: details,
       );

  const SuccessArtifactVerdict.undetermined(
    SuccessArtifactKind kind,
    String reason, {
    Map<String, dynamic> details = const {},
  }) : this._(
         satisfaction: ArtifactSatisfaction.undetermined,
         kind: kind,
         reason: reason,
         details: details,
       );

  final ArtifactSatisfaction satisfaction;
  final SuccessArtifactKind kind;

  /// Set exactly when [satisfaction] is not [ArtifactSatisfaction.satisfied].
  /// Always leads with [SuccessArtifactArtifacts.marker] when missing, so one
  /// grep finds every instance of this failure class in a log.
  final String? reason;

  /// Merged into the terminal event payload, so the greppable fields survive in
  /// the event stream as well as in the execution's reason string.
  final Map<String, dynamic> details;

  bool get isSatisfied => satisfaction == ArtifactSatisfaction.satisfied;
  bool get isMissing => satisfaction == ArtifactSatisfaction.missing;
}

/// Decides whether a completed execution produced its lane's artifact.
///
/// [executionId] is named rather than read from the workspace so the reason
/// string identifies the RUN rather than the checkout it happened to run in —
/// the same reason `WorkItemSupersededException` names work item and execution
/// ids and no path.
abstract class SuccessArtifactChecker {
  Future<SuccessArtifactVerdict> inspect({
    required String executionId,
    required AgentRole role,
    required AgentWorkspace workspace,
    required AgentResult result,
  });
}

/// Constants and wording shared by the role-aware rule.
abstract final class SuccessArtifactArtifacts {
  /// Fixed prefix of every missing-artifact reason. The wire contract.
  ///
  /// Modelled on `WorkItemSupersededException.marker` in this same package: the
  /// worker flattens every thrown value to one string in
  /// `WorkerExecutionResult.failureDetail`, so prose alone cannot carry a
  /// classification and a fixed, greppable prefix has to.
  static const String marker = 'missing_success_artifact:';

  /// The event payload `kind`, so `kind = 'missingSuccessArtifact'` selects the
  /// same set of rows out of the event stream.
  static const String eventKind = 'missingSuccessArtifact';

  /// The `WorkItem.metadata` key carrying the verdict for the completion that
  /// LAST settled a work item. The wire contract between this package and the
  /// scheduler's completion inflow.
  ///
  /// ## WHY THE WORK ITEM AND NOT `agent_event` — the channel, chosen
  ///
  /// `successArtifactUndetermined` was first written into `_Completion
  /// .eventPayload` only, which reaches `ExecutionStore.appendEvent` and thence
  /// the `agent_event` table. That row is real, durable evidence, and it is
  /// **invisible to the platform**: the scheduler's production worker store
  /// (`PostgresWorkerStore`) reads `worker_execution`, `worker_result` and
  /// `worker_event`, and `packages/scheduler` does not depend on
  /// `execution_coordinator` at all. The marker existed for a human to grep in
  /// SQL and for nothing else — which is exactly why the unattended loop it
  /// describes ran for ever.
  ///
  /// So the verdict also travels on `WorkItem.metadata`, and that is the channel
  /// the brake uses. It is the right one, not merely the reachable one:
  ///
  ///  * **The counter is a property of the WORK ITEM, not of an execution.**
  ///    "N consecutive undetermined returns" is a statement about one item's
  ///    history, and *consecutive* is only definable against the item's own
  ///    position in its cycle. An event stream would force the scheduler to
  ///    reconstruct that ordering across executions — the exact reconstruction
  ///    `producerActorId` exists to avoid (see `producedCommitFor`, "WHY THE
  ///    ANCHOR AND NOT THE LATEST EXECUTION": recency would read a later triage
  ///    run as the implementation).
  ///  * **It is a channel this platform already writes and already reads for
  ///    exactly this purpose.** `producerActorId` is written by this same
  ///    coordinator, on this same `agentCompleted` transition, and read by this
  ///    same scheduler, out of the same durable row. Same transaction, same
  ///    durability, same failure modes — no new table, no migration, no new
  ///    store dependency.
  ///  * **The write is atomic with the state move.** The verdict is merged by
  ///    the same `metadataMerge` that performs the transition, so a crash
  ///    between "the run finished" and "the verdict was recorded" cannot leave
  ///    a count that is off by one.
  ///
  /// ## WHY THE WORKER-RECORD CHANNELS ARE NOT USED
  ///
  /// They are the other two candidates and neither is reachable from the
  /// writer. `WorkerExecution.reason` and `WorkerEventRecord.payload` are both
  /// written by `LocalWorker`, which never sees this verdict at all:
  /// `AgentExecution` carries a status and nothing else, and `LocalWorker`
  /// reads nothing else. Reaching them would mean growing
  /// `platform_contracts` to carry the flag across the boundary and editing
  /// `worker_runtime` to write it — and `execution_coordinator` cannot take a
  /// dependency on `worker_runtime` to do it itself, because `worker_runtime`
  /// already depends on `execution_coordinator`.
  ///
  /// ## WRITTEN ON EVERY COMPLETION, INCLUDING `false`
  ///
  /// Absence is not "undetermined" and absence is not "determined" either: it
  /// means this item has never been through a coordinator that writes the key
  /// (an item that predates it). The flag therefore describes the LAST
  /// completion and is overwritten every time, so a determined completion after
  /// an undetermined one cannot leave a stale `true` behind and inflate a
  /// streak for ever.
  static const String undeterminedMetadataKey = 'successArtifactUndetermined';

  /// The value written under [undeterminedMetadataKey] for [satisfaction].
  ///
  /// One function rather than a `== ArtifactSatisfaction.undetermined` written
  /// at the call site, so "which satisfaction counts as undetermined" has
  /// exactly one definition — the same reason
  /// `DurableWorkflowEngine.triageAttemptMetadataKey` pairs with
  /// `nextTriageAttempt`.
  static bool undeterminedFlagFor(ArtifactSatisfaction satisfaction) =>
      satisfaction == ArtifactSatisfaction.undetermined;

  /// The denied permission asks a result carries, read from the
  /// `permissionDenials` metadata key `OpenCodeSession` writes — a list of
  /// bounded summaries produced by `OpenCodeProcessTransport` when it denies
  /// a `session/request_permission`. Null when the run asked for nothing or
  /// the record predates the key.
  ///
  /// ## WHY THIS IS READ HERE
  ///
  /// Live QA (F-247): every implementer `missing_success_artifact` run ended
  /// `end_turn` immediately after exactly one denied ask, on capable paid
  /// models as well as cheap ones — the model treated the refusal as the end
  /// of the work. The denial does not change the verdict: the artifact is
  /// still provably absent, by probe or by result. It changes what the
  /// RECORD says: "the run finished cleanly and produced nothing" is not an
  /// honest description of a run the platform itself interrupted with a
  /// refusal, and the denied ask's content is the only evidence of whether
  /// the refused call was something the task needed or something the agent
  /// reached for unprompted.
  static List<dynamic>? denialsOf(AgentResult result) {
    final denials = result.metadata?['permissionDenials'];
    return denials is List && denials.isNotEmpty ? denials : null;
  }

  /// The permission kinds of [denials], for a reason string —
  /// `external_directory, doom_loop`. Falls back to a generic label when a
  /// summary carried neither a title nor a kind.
  static String denialTitles(List<dynamic> denials) => denials
      .map((d) {
        if (d is Map) {
          return (d['title'] ?? d['kind'] ?? 'permission').toString();
        }
        return 'permission';
      })
      .join(', ');

  /// `kind` for the ordinary artifact-missing path. Deliberately NOT one of the
  /// transient markers: a run that finished cleanly and produced nothing will
  /// produce nothing again on an automatic retry, so it must not be returned to
  /// a lane entry state.
  static String noCommitReason({
    required String executionId,
    required String role,
    required WorkspaceDelta delta,
    List<dynamic>? denials,
  }) =>
      '$marker $role execution $executionId produced no commit: its '
      'workspace is identical to the revision it started from '
      '(HEAD ${delta.headRevision ?? 'unknown'}, '
      'starting ${delta.startingRevision ?? 'unknown'}, no modified, staged or '
      'untracked paths). It produced a report, not an artifact. '
      '${denials == null || denials.isEmpty ? 'This is a permanent failure: the run finished cleanly, so an '
                'automatic retry would produce nothing again, and it is left '
                'for a human whose retry is uncounted.' : 'This is a permanent failure: the run ended after the platform '
                'denied ${denials.length} permission ask(s) '
                '(${denialTitles(denials)}). Whether the refused call(s) were '
                'required for the artifact cannot be told from the record, and '
                'the workspace is still provably unchanged — so it is recorded '
                'as produced-nothing, not as a platform fault, and it is left '
                'for a human whose retry is uncounted.'}';

  static String noClassificationReason({
    required String executionId,
    required String detail,
    List<dynamic>? denials,
  }) =>
      '$marker TRIAGE_DEFECT execution $executionId completed without a '
      'structured classification result: $detail. Triage writes its '
      'deliverable as a classification and never as code, so an empty or '
      'unparseable result is this lane having produced nothing.'
      '${denialClause(denials)}';

  static String noVerdictReason({
    required String executionId,
    required String detail,
    List<dynamic>? denials,
  }) =>
      '$marker ENGINEERING_REVIEWER execution $executionId completed without a '
      'parseable verdict: $detail. The review is its verdict; a run that '
      'concluded nothing cannot be recorded as a review that concluded '
      'something, and the platform never supplies one on the reviewer\'s '
      'behalf.'
      '${denialClause(denials)}';

  /// The sentence appended to a missing-artifact reason when the run's own
  /// record shows the platform refused permission asks during it. Empty when
  /// there were none, so every existing reason is byte-identical in the case
  /// this feature does not touch.
  ///
  /// It does not soften the verdict — the artifact is still provably absent —
  /// and it does not claim causation: a denied ask followed by `end_turn` is
  /// evidence the refusal ended the work, not proof, and the reason says
  /// exactly that.
  static String denialClause(List<dynamic>? denials) =>
      denials == null || denials.isEmpty
      ? ''
      : ' The platform denied ${denials.length} permission ask(s) during '
            'this run (${denialTitles(denials)}); the asks themselves are in '
            'the verdict details and the result\'s metadata. Whether the '
            'refused call(s) were required for the artifact cannot be told '
            'from the record.';
}

/// The role-aware rule.
///
/// ## THE THREE LANES, AND WHY EACH IS WHAT IT IS
///
///  * **IMPLEMENTER** (and CORRECTION_IMPLEMENTER) must have changed the
///    repository. This mirrors `producedCommitFor`
///    (`packages/scheduler/lib/src/implementation_inflow.dart`) and, through it,
///    `ArtifactCommitter`. It could not be imported: `worker_runtime` depends on
///    `execution_coordinator` and `scheduler` depends on `worker_runtime`, so
///    importing it would be a dependency cycle. See [GitWorkspaceDeltaProbe] for
///    the exact predicate and why it is not the inspector's.
///  * **TRIAGE_DEFECT** must have produced a structured classification. The
///    predicate below is `TriageProcessor._parseTriageResult`'s, field for
///    field, using the same `fromWire` calls — so a classification this rule
///    accepts is one the platform's own triage processor would have persisted,
///    and one it rejects is one the processor would have dropped. It calls
///    `DefectClassification.fromWire` and `DefectStatus.fromWire` rather than
///    matching literals for exactly that reason.
///  * **ENGINEERING_REVIEWER** must have produced a parseable verdict. See
///    [reviewVerdictMissingIn] for what "no verdict" means here.
///
/// ## UNDETERMINED IS NOT MISSING
///
/// A probe that could not run does not fail the execution. Two reasons, both
/// load-bearing:
///
///  1. **It would make a tooling fault permanent.** The operator's requirement
///     is that "a run that finished cleanly but produced nothing" is a
///     permanent failure settled for a human. A wedged filesystem is not that,
///     and reporting it in those words would tell the operator their agent did
///     nothing when the platform simply could not look.
///  2. **It would be decided by evidence nobody gathered.** A verdict of "no
///     artifact" asserted without a reading is a guess, and the same
///     argument-forbidding-guessing rule the rest of this package is built on
///     applies to the failure direction too.
///
/// An undetermined verdict is still recorded, in the execution reason and the
/// event payload, so it is visible rather than silent.
class RoleAwareSuccessArtifacts implements SuccessArtifactChecker {
  const RoleAwareSuccessArtifacts({required this.probe});

  /// The workspace reader. Injected so the git behaviour can be tested against
  /// a real repository and the role predicates without one.
  final WorkspaceDeltaProbe probe;

  /// The lane's artifact for [role].
  ///
  /// Exposed so a caller can report the expectation without running it, and so
  /// the mapping has exactly one definition.
  static SuccessArtifactKind kindFor(AgentRole role) => switch (role) {
    AgentRole.implementer => SuccessArtifactKind.committedCode,
    // The same defect is the same defect whoever is fixing it: a correction
    // that changed nothing has produced no implementation either.
    AgentRole.correctionImplementer => SuccessArtifactKind.committedCode,
    AgentRole.triageDefect => SuccessArtifactKind.classificationResult,
    AgentRole.engineeringReviewer => SuccessArtifactKind.reviewVerdict,
    _ => SuccessArtifactKind.unspecified,
  };

  @override
  Future<SuccessArtifactVerdict> inspect({
    required String executionId,
    required AgentRole role,
    required AgentWorkspace workspace,
    required AgentResult result,
  }) async {
    return switch (kindFor(role)) {
      SuccessArtifactKind.committedCode => _committedCode(
        executionId,
        role,
        workspace,
        result,
      ),
      SuccessArtifactKind.classificationResult => classificationVerdict(
        executionId,
        result,
      ),
      SuccessArtifactKind.reviewVerdict => reviewVerdict(executionId, result),
      SuccessArtifactKind.unspecified => SuccessArtifactVerdict.satisfied(
        SuccessArtifactKind.unspecified,
      ),
    };
  }

  Future<SuccessArtifactVerdict> _committedCode(
    String executionId,
    AgentRole role,
    AgentWorkspace workspace,
    AgentResult result,
  ) async {
    final delta = await probe.probe(
      workingDirectory: workspace.path,
      startingRevision: workspace.startingRevision,
    );
    if (!delta.isReadable) {
      return SuccessArtifactVerdict.undetermined(
        SuccessArtifactKind.committedCode,
        '${SuccessArtifactArtifacts.marker} whether $role execution '
        '$executionId produced its artifact could not be established: '
        '${delta.unreadableReason}. This is NOT recorded as having produced '
        'nothing: the platform could not look, and reporting a tooling fault as '
        'an agent that did nothing would be a verdict asserted without a '
        'reading.',
        details: {'undetermined': true, 'probeFailure': delta.unreadableReason},
      );
    }
    if (delta.hasChanges) {
      return const SuccessArtifactVerdict.satisfied(
        SuccessArtifactKind.committedCode,
      );
    }
    final denials = SuccessArtifactArtifacts.denialsOf(result);
    return SuccessArtifactVerdict.missing(
      SuccessArtifactKind.committedCode,
      SuccessArtifactArtifacts.noCommitReason(
        executionId: executionId,
        role: role.wire,
        delta: delta,
        denials: denials,
      ),
      details: {
        'headRevision': delta.headRevision,
        'startingRevision': delta.startingRevision,
        'changedFileCount': delta.changedPaths.length,
        if (denials != null) 'permissionDenials': denials,
      },
    );
  }
}

/// Whether a triage result carries the classification its lane exists to
/// produce.
///
/// A faithful transcription of `TriageProcessor._parseTriageResult`
/// (`apps/server/lib/src/triage/triage_processor.dart`), which is the
/// authoritative definition of a triage artifact: `classification` and `status`
/// must be legal wire tokens, `confidence` a number, `suspectedCategory` a
/// string, and `structuredResult` non-empty. Everything that parser treats as
/// optional stays optional here, so this rule cannot reject a classification the
/// platform would have kept.
///
/// A triage execution's artifact verdict.
///
/// Returns null when the classification IS present.
String? classificationMissingIn(AgentResult result) {
  final structured = result.structuredResult;
  if (structured.isEmpty) {
    return 'the result carried no structured classification at all';
  }

  final classification = structured['classification'];
  if (classification is! String) {
    return 'the result carried no "classification" field';
  }
  try {
    DefectClassification.fromWire(classification);
  } on FormatException catch (e) {
    return '"classification": $classification is not a classification ($e)';
  }

  final status = structured['status'];
  if (status is! String) {
    return 'the result carried no "status" field';
  }
  try {
    DefectStatus.fromWire(status);
  } on FormatException catch (e) {
    return '"status": $status is not a defect status ($e)';
  }

  if (structured['confidence'] is! num) {
    return 'the result carried no numeric "confidence"';
  }
  if (structured['suspectedCategory'] is! String) {
    return 'the result carried no "suspectedCategory" field';
  }
  return null;
}

/// Wraps [classificationMissingIn] in the verdict, so the wording lives in one
/// place for every caller.
SuccessArtifactVerdict classificationVerdict(
  String executionId,
  AgentResult result,
) {
  final missing = classificationMissingIn(result);
  final denials = SuccessArtifactArtifacts.denialsOf(result);
  return missing == null
      ? const SuccessArtifactVerdict.satisfied(
          SuccessArtifactKind.classificationResult,
        )
      : SuccessArtifactVerdict.missing(
          SuccessArtifactKind.classificationResult,
          SuccessArtifactArtifacts.noClassificationReason(
            executionId: executionId,
            detail: missing,
            denials: denials,
          ),
          details: {
            'missingReason': missing,
            if (denials != null) 'permissionDenials': denials,
          },
        );
}

/// Whether a reviewer's result carries a verdict the platform can read.
///
/// ## WHAT "NO VERDICT" MEANS FOR THIS LANE — the explicit decision
///
/// A reviewer execution has produced its artifact iff its `structuredResult`
/// yields a verdict under the SAME reading `engineering_review_gate.dart`'s
/// `_readReviewVerdict` performs, and that reading has one priority order:
///
///  1. `structured['engineeringReviewResult']` is a JSON object. A reviewer may
///     hand back a fully-formed result, which carries its own verdict; the gate
///     reads it first, and a parse failure there falls through rather than
///     aborting. Treated here as a verdict, because the gate will.
///  2. otherwise `structured['verdict']` is a non-empty String that
///     `ReviewVerdict.fromWire` accepts. An unrecognised token is NOT a verdict:
///     reading it as one — as it once was, defaulting to `changes_required` —
///     reports to the operator that a reviewer found problems when it concluded
///     nothing parseable at all.
///  3. otherwise there is no verdict.
///
/// Nothing else is required. `findings` are diagnostics, not the verdict, and
/// the `summary` is prose; neither is consulted, because requiring either would
/// fail a genuine verdict that arrived without them.
///
/// ## WHAT THIS DELIBERATELY DOES NOT DO
///
/// It does not route. Where a verdict-absent review goes next — automatic
/// re-review, the human decision, the verdict-absent autoroute — belongs to
/// `apps/server`, which this package does not own and this rule does not
/// touch. What it does is make the execution's own verdict honest: a reviewer
/// that concluded nothing is recorded as having concluded nothing, permanently,
/// instead of as a completed review.
///
/// It changes no cause code the routing reads, because `_absenceCauseFor` in
/// that gate is reached only when the reviewer execution has NO stored result,
/// and this coordinator always stores one (`_complete` saves it on every path).
/// The gate therefore classifies this case by its `structuredResult` — present
/// but verdictless — and does so identically before and after this change.
String? reviewVerdictMissingIn(AgentResult result) {
  final structured = result.structuredResult;
  if (structured.isEmpty) {
    return 'the reviewer result carried no structured output at all';
  }

  final embedded = structured['engineeringReviewResult'];
  if (embedded is Map) {
    return null;
  }

  final rawVerdict = structured['verdict'];
  if (rawVerdict is! String || rawVerdict.isEmpty) {
    return 'the reviewer returned a result carrying no "verdict" field';
  }
  try {
    ReviewVerdict.fromWire(rawVerdict);
  } on FormatException catch (e) {
    return '"verdict": $rawVerdict is not a review verdict ($e)';
  }
  return null;
}

/// Wraps [reviewVerdictMissingIn] in the verdict.
SuccessArtifactVerdict reviewVerdict(String executionId, AgentResult result) {
  final missing = reviewVerdictMissingIn(result);
  final denials = SuccessArtifactArtifacts.denialsOf(result);
  return missing == null
      ? const SuccessArtifactVerdict.satisfied(
          SuccessArtifactKind.reviewVerdict,
        )
      : SuccessArtifactVerdict.missing(
          SuccessArtifactKind.reviewVerdict,
          SuccessArtifactArtifacts.noVerdictReason(
            executionId: executionId,
            detail: missing,
            denials: denials,
          ),
          details: {
            'missingReason': missing,
            if (denials != null) 'permissionDenials': denials,
          },
        );
}
