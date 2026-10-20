import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// The platform's answer about one execution's workspace, in the three-valued
/// shape F1 judges.
///
/// ## Why this is a value type here and not `WorkspaceDelta`
///
/// `WorkspaceDelta` lives in `execution_coordinator`
/// (`workspace_delta_probe.dart:14`), which `qa_orchestration` does not depend
/// on — the same boundary that keeps every evaluator in this directory behind
/// a typed source ([ArtifactProvenanceSource] below). The fields mirror
/// `WorkspaceDelta`'s load-bearing facts exactly, including its deliberate
/// three-valuedness (`workspace_delta_probe.dart:87-96`), so the production
/// adapter is a field-for-field mapping rather than a translation with room
/// for a decision to creep in.
///
/// ## The one fact that must not be collapsed
///
/// [headMoved] is `null` when **HEAD was never read** — `GitWorkspaceDeltaProbe`
/// short-circuits on a dirty tree and returns
/// `WorkspaceDelta.changed(headRevision: null, headMoved: null)`
/// (`workspace_delta_probe.dart:199-217`). A `null` here is "not established",
/// never "established as no", and this gate re-reads `HEAD` rather than
/// guessing at either meaning (see [ImplementationArtifactProvenanceGate]).
class ExecutionDelta {
  /// The worktree is clean and `HEAD` still equals [startingRevision]: the only
  /// value that means "produced nothing" (`workspace_delta_probe.dart:21-27`).
  const ExecutionDelta.unchanged({
    required this.startingRevision,
    required this.headRevision,
  }) : isReadable = true,
       headMoved = false,
       worktreeDirty = false,
       unreadableReason = null;

  /// The worktree carries changes. [headRevision] and [headMoved] are `null`
  /// when the probe declined to read `HEAD` — the short-circuit this gate's
  /// re-read exists to answer (`workspace_delta_probe.dart:210-216`).
  const ExecutionDelta.changed({
    required this.startingRevision,
    this.headRevision,
    this.headMoved,
  }) : isReadable = true,
       worktreeDirty = true,
       unreadableReason = null;

  /// The worktree is clean and `HEAD` is no longer [startingRevision]: the
  /// execution committed its own work (`workspace_delta_probe.dart:61-67`).
  const ExecutionDelta.committed({
    required this.startingRevision,
    required this.headRevision,
  }) : isReadable = true,
       headMoved = true,
       worktreeDirty = false,
       unreadableReason = null;

  /// The delta could not be established. "I could not look" is a value here,
  /// never folded into "looked and saw nothing"
  /// (`workspace_delta_probe.dart:71-76`).
  const ExecutionDelta.unreadable(String this.unreadableReason)
    : isReadable = false,
      startingRevision = null,
      headRevision = null,
      headMoved = null,
      worktreeDirty = null;

  /// Whether the probe produced a usable answer at all.
  final bool isReadable;

  /// The revision the execution started from, when known.
  final String? startingRevision;

  /// `HEAD` at settle time as the probe saw it, when it read `HEAD` at all.
  final String? headRevision;

  /// Whether `HEAD` differed from [startingRevision] **according to the probe**.
  ///
  /// This gate does not judge on it: it is `null` on every dirty tree, and F1's
  /// pass condition is stated in terms of the unconditional re-read
  /// (`[ImplementationArtifactProvenanceGate]`), so a probe implementation
  /// change cannot re-open the hole.
  final bool? headMoved;

  /// Whether `git status --porcelain` was non-empty when the probe ran.
  ///
  /// `null` when the delta is unreadable (nobody looked). Only used to make the
  /// unmoved-HEAD failure reason say *uncommitted work* instead of *nothing was
  /// produced* — a dirty tree with no commit and a clean tree with no commit
  /// are both failures, but they are different findings.
  final bool? worktreeDirty;

  /// Why the probe could not answer, when [isReadable] is false.
  final String? unreadableReason;

  /// The committer's predicate, `dirty || moved`
  /// (`workspace_delta_probe.dart:113-114`).
  ///
  /// **Deliberately not read by this gate.** It is true for a dirty tree with
  /// no commit at all, so accepting it would pass the seven-of-seven case
  /// wearing a different predicate (design §3.1 F1, "the deliberate non-goal").
  /// It exists on this type so that predicate and this gate's own condition
  /// stay nameable side by side — and testable against each other.
  bool get hasChanges =>
      isReadable && (worktreeDirty == true || headMoved == true);
}

/// Reads the two facts F1 judges, each from the source the design names.
///
/// ## Why this is an interface
///
/// `qa_orchestration` does not depend on `execution_coordinator`, where both
/// production readers live (`WorkspaceDeltaProbe`,
/// `workspace_delta_probe.dart:118-123`; `WorkspaceHeadReader`,
/// `workspace_head_reader.dart:38`). The production implementation is those
/// two readers behind one adapter (slice 3c); a gate must be evaluable in a
/// test without a worktree.
abstract interface class ArtifactProvenanceSource {
  /// The platform's probe answer for the lane's execution — the
  /// `WorkspaceDelta` mapped field-for-field into [ExecutionDelta].
  Future<ExecutionDelta> readDelta(String workItemId);

  /// P1's unconditional `HEAD` re-read
  /// (`workspace_head_reader.dart:54-86`) for the lane's workspace.
  ///
  /// [startingRevision] is passed by the evaluator from
  /// `delta.startingRevision`, exactly as the design's snippet does, so the
  /// baseline the comparison used is visible in the evaluator rather than
  /// re-derived behind the interface. The production implementation is
  /// `WorkspaceHeadReader().read(workingDirectory: execution.workspace.path,
  /// startingRevision: startingRevision)` — the workspace path is an execution
  /// fact this package cannot reach, which is the only part the adapter
  /// resolves.
  ///
  /// Returns `null` **verbatim** when `HEAD` could not be established, and
  /// never returns a `WorkspaceHead` it could not fill in. It does not throw:
  /// "could not look" is this reader's own specified answer
  /// (`workspace_head_reader.dart:96-103`), and a gate must receive it as a
  /// value it can fail on rather than an exception it might leak.
  Future<WorkspaceHead?> reReadHead(
    String workItemId, {
    required String? startingRevision,
  });
}

/// The feature lane's F1 gate: a commit exists at a **recorded** revision.
///
/// ## The re-read is the gate, not a fallback
///
/// `GitWorkspaceDeltaProbe` short-circuits on a dirty tree and **never reads
/// `HEAD`** (`workspace_delta_probe.dart:199-217`), so `delta.headMoved == null`
/// means "the probe declined to look", not "HEAD did not move". This gate runs
/// [ArtifactProvenanceSource.reReadHead] **unconditionally** — on a clean tree,
/// on a dirty tree, on an unreadable delta — and passes iff
/// `delta.isReadable && head.headMoved == true`, where `head` is the re-read's
/// answer.
///
/// The consequences the design spells out (§3.1 F1):
///
/// * `headMoved: null` → re-read → `true` ⇒ **PASS**. Failing that run fails
///   every correctly-committing lane that leaves an untracked file — which is
///   every lane here — and teaches operators to waive the gate.
/// * re-read returns `null` ⇒ **FAIL** with *"HEAD could not be established"*,
///   never *"nothing was produced"*: a tooling fault reported as an agent that
///   did nothing would be settled as the permanent failure that wording
///   exists to prevent.
/// * `delta.isReadable == false` ⇒ **FAIL** regardless of what the re-read
///   found. *"I could not look" is never laundered into "I looked and saw
///   nothing"* (`workspace_delta_probe.dart:8-11`).
/// * `AgentResult.changedFiles` is read into the evidence row and **never**
///   into the predicate: the agent's claim cannot substitute for git's reading.
///
/// ## What it does not do
///
/// It does not accept `delta.hasChanges` (`dirty || moved`) — that is the
/// committer's predicate, true for a dirty tree with no commit
/// (design §3.1 F1's deliberate non-goal). It decides on **a commit existing**,
/// which is the claim F2 and F5 both need downstream.
///
/// `config['evidenceTypes']` is **not** validated here: per design §3.0 rule 2
/// it is the contract derivation's read-back
/// (`product_qa_contract.dart:168-189`), and an absent key legally yields `[]`.
/// The evaluator pins the three flags that change what the gate judges.
class ImplementationArtifactProvenanceGate implements GateEvaluator {
  ImplementationArtifactProvenanceGate({required this.source});

  final ArtifactProvenanceSource source;

  @override
  String get gateType => 'implementation-artifact-provenance';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _FeatureCommittedConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final delta = await source.readDelta(workItemId);

    // Unconditional. Never `if (delta.headMoved == null)`, never skipped for a
    // clean tree or an unreadable delta: the pass condition is stated in terms
    // of THIS answer so a probe implementation change cannot silently re-open
    // the hole (design §3.1 F1, "REPROBE, never accept").
    final head = await source.reReadHead(
      workItemId,
      startingRevision: delta.startingRevision,
    );

    final failures = <String>[];

    if (!delta.isReadable) {
      failures.add(
        'the workspace delta could not be read '
        '(${delta.unreadableReason}); this is "I could not look" and is never '
        'recorded as "nothing was produced"',
      );
    }

    final establishedHead = head;
    if (establishedHead == null) {
      failures.add(
        'HEAD could not be established, so no revision can be recorded; this '
        'is "I could not look", not "nothing was produced"',
      );
    } else if (establishedHead.headMoved != true) {
      failures.add(_unmovedReason(delta, establishedHead));
    }

    final passed = failures.isEmpty;
    final producedRevision = establishedHead?.headRevision;
    final agentClaimedPaths = [
      for (final file in agentResult.changedFiles ?? const <ChangedFile>[])
        file.path,
    ];

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:execution_delta:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'execution_delta',
          artifactRef: 'workspace_delta_probe',
          content: <String, dynamic>{
            'isReadable': delta.isReadable,
            'startingRevision': delta.startingRevision,
            'probeHeadRevision': delta.headRevision,
            'probeHeadMoved': delta.headMoved,
            'worktreeDirty': delta.worktreeDirty,
            'unreadableReason': delta.unreadableReason,
            // Recorded so the evidence shows the claim was SEEN. It never
            // reaches the predicate below — see the class doc.
            'agentReportedChangedFilePaths': agentClaimedPaths,
          },
          collectedAt: evaluatedAt,
        ),
        QAEvidence(
          evidenceId:
              '${gate.gateId}:committed_revision:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'committed_revision',
          artifactRef: 'workspace_head_reader',
          content: <String, dynamic>{
            if (config.recordProducedRevision)
              'producedRevision': producedRevision,
            'startingRevision': establishedHead?.startingRevision,
            'headMoved': establishedHead?.headMoved,
            'established': establishedHead != null,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'deltaIsReadable': delta.isReadable,
        'reReadHeadMoved': establishedHead?.headMoved,
        if (config.recordProducedRevision) 'producedRevision': producedRevision,
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }

  /// Why an established `HEAD` that is not `true` on [headMoved] fails, in
  /// terms that fit the input that produced it.
  ///
  /// The three branches are three different findings and must not read alike:
  /// a re-read with no baseline could not compare; a dirty tree holds
  /// uncommitted work that is not an artefact; a clean tree with `HEAD` at the
  /// starting revision produced nothing. The last is the seven-of-seven case
  /// and the only one for which "nothing was produced" is true.
  String _unmovedReason(ExecutionDelta delta, WorkspaceHead head) {
    if (head.headMoved == null) {
      return 'the re-read returned HEAD at "${head.headRevision}" without a '
          'starting revision to compare it against, so headMoved is "not '
          'established" and cannot be true';
    }
    if (delta.worktreeDirty == true) {
      return 'HEAD did not move: the worktree is dirty but nothing is '
          'committed, and uncommitted work is not an artefact a later review '
          'can pin a revision to (HEAD stays at "${head.headRevision}")';
    }
    return 'nothing was produced at a recorded revision: HEAD '
        '"${head.headRevision}" still equals the starting revision '
        '"${head.startingRevision ?? delta.startingRevision}"';
  }
}

/// F1's declared half, validated up front — before any read, so a malformed
/// declaration is refused rather than evaluated against a weaker predicate.
///
/// Each refusal carries a distinct reason because the three flags refuse
/// different damage: dropping any of them would silently widen what the gate
/// accepts, and a `FormatException` that said only "bad config" would not tell
/// the manifest author which hole they opened.
class _FeatureCommittedConfig {
  const _FeatureCommittedConfig({required this.recordProducedRevision});

  /// Pinned `true` by [from]; carried so the evidence builder reads the
  /// declaration rather than a literal.
  final bool recordProducedRevision;

  static _FeatureCommittedConfig from(QAGateDefinition gate) {
    final requireReadableDelta = gate.config['requireReadableDelta'];
    if (requireReadableDelta != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "requireReadableDelta": true; an '
        'unreadable delta is "I could not look" and must FAIL, never be read '
        'as "missing"',
      );
    }

    final requireHeadMoved = gate.config['requireHeadMoved'];
    if (requireHeadMoved != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "requireHeadMoved": true; a dirty '
        'tree with no commit must FAIL — accepting it is the '
        'delta.hasChanges non-goal the design refuses',
      );
    }

    final recordProducedRevision = gate.config['recordProducedRevision'];
    if (recordProducedRevision != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "recordProducedRevision": true; the '
        'produced revision is what F2 and F5 need downstream, and a gate that '
        'does not record it strands them on a null it never established',
      );
    }

    return const _FeatureCommittedConfig(recordProducedRevision: true);
  }
}
