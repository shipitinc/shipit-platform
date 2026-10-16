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

  /// `kind` for the ordinary artifact-missing path. Deliberately NOT one of the
  /// transient markers: a run that finished cleanly and produced nothing will
  /// produce nothing again on an automatic retry, so it must not be returned to
  /// a lane entry state.
  static String noCommitReason({
    required String executionId,
    required String role,
    required WorkspaceDelta delta,
  }) =>
      '$marker $role execution $executionId produced no commit: its '
      'workspace is identical to the revision it started from '
      '(HEAD ${delta.headRevision ?? 'unknown'}, '
      'starting ${delta.startingRevision ?? 'unknown'}, no modified, staged or '
      'untracked paths). It produced a report, not an artifact. This is a '
      'permanent failure: the run finished cleanly, so an automatic retry would '
      'produce nothing again, and it is left for a human whose retry is '
      'uncounted.';

  static String noClassificationReason({
    required String executionId,
    required String detail,
  }) =>
      '$marker TRIAGE_DEFECT execution $executionId completed without a '
      'structured classification result: $detail. Triage writes its '
      'deliverable as a classification and never as code, so an empty or '
      'unparseable result is this lane having produced nothing.';

  static String noVerdictReason({
    required String executionId,
    required String detail,
  }) =>
      '$marker ENGINEERING_REVIEWER execution $executionId completed without a '
      'parseable verdict: $detail. The review is its verdict; a run that '
      'concluded nothing cannot be recorded as a review that concluded '
      'something, and the platform never supplies one on the reviewer\'s '
      'behalf.';
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
    return SuccessArtifactVerdict.missing(
      SuccessArtifactKind.committedCode,
      SuccessArtifactArtifacts.noCommitReason(
        executionId: executionId,
        role: role.wire,
        delta: delta,
      ),
      details: {
        'headRevision': delta.headRevision,
        'startingRevision': delta.startingRevision,
        'changedFileCount': delta.changedPaths.length,
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
  return missing == null
      ? const SuccessArtifactVerdict.satisfied(
          SuccessArtifactKind.classificationResult,
        )
      : SuccessArtifactVerdict.missing(
          SuccessArtifactKind.classificationResult,
          SuccessArtifactArtifacts.noClassificationReason(
            executionId: executionId,
            detail: missing,
          ),
          details: {'missingReason': missing},
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
  return missing == null
      ? const SuccessArtifactVerdict.satisfied(
          SuccessArtifactKind.reviewVerdict,
        )
      : SuccessArtifactVerdict.missing(
          SuccessArtifactKind.reviewVerdict,
          SuccessArtifactArtifacts.noVerdictReason(
            executionId: executionId,
            detail: missing,
          ),
          details: {'missingReason': missing},
        );
}
