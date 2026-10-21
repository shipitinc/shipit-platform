import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';
import '../source_provenance.dart';

/// The two facts F5 compares, each obtained from the source the design names.
///
/// ## Why this is an interface and not a `String`
///
/// The design is explicit that `producedRevision` is what **P1's
/// `WorkspaceHeadReader` re-read established**, not a value F1 recorded on a run
/// whose `headMoved` was `null`. Under the old arrangement a re-run that
/// committed and left an untracked file produced a `null` that had never been
/// established, and `nullRevisionIsFailure` fired on a correct run.
///
/// So [readProducedHead] returns P1's own output type — [WorkspaceHead], with
/// its three-valued `headMoved` and its non-nullable `headRevision` — rather
/// than a `String?`. There is no shape here in which a recorded string can
/// stand in for the re-read: the production implementation must call
/// `WorkspaceHeadReader.read(...)` and return its result verbatim, and the
/// evaluator reads the revision from `WorkspaceHead.headRevision`.
///
/// The implementation lives on the production side (slice 3c) because
/// `qa_orchestration` does not depend on `execution_coordinator`, and the
/// reader's inputs — the execution's workspace path and the delta's
/// `startingRevision` — are execution facts this package cannot reach.
abstract interface class RevisionIdentitySource
    implements QASourceProvenanceAware {
  /// The revision the engineering review verdict recorded for [workItemId].
  ///
  /// `null` when no verdict exists or the verdict recorded none. Both are
  /// failures under `nullRevisionIsFailure: true`.
  Future<String?> readReviewedRevision(String workItemId);

  /// P1's re-read of `HEAD` for [workItemId].
  ///
  /// `null` means **"HEAD could not be established"** — P1's "I could not
  /// look" — and is never `WorkspaceHead(headMoved: false)`.
  Future<WorkspaceHead?> readProducedHead(String workItemId);
}

/// The feature lane's F5 gate: the revision engineering review approved is the
/// revision the commit produced.
///
/// Passes iff the reviewed revision is a non-null, non-empty string **equal**
/// to the produced revision P1 re-read. A null or empty reviewed revision is a
/// failure (`nullRevisionIsFailure: true`), never `notApplicable`.
class RevisionIdentityMatchGate implements GateEvaluator {
  RevisionIdentityMatchGate({required this.source});

  final RevisionIdentitySource source;

  @override
  String get gateType => 'revision-identity-match';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _RevisionIdentityConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final reviewedRevision = await source.readReviewedRevision(workItemId);
    final producedHead = await source.readProducedHead(workItemId);
    final producedRevision = producedHead?.headRevision;

    final failures = <String>[];

    if (reviewedRevision == null) {
      failures.add(
        'the engineering review verdict records no reviewed revision '
        '("${config.reviewedRevisionField}" is null); nullRevisionIsFailure is '
        'true',
      );
    } else if (reviewedRevision.isEmpty) {
      failures.add(
        'the engineering review verdict records an empty reviewed revision; an '
        'empty string is not a revision',
      );
    }

    if (producedHead == null) {
      failures.add(
        'HEAD could not be established by the platform re-read, so no produced '
        'revision exists to compare; this is "I could not look", not "nothing '
        'was produced"',
      );
    } else if (producedHead.headRevision.isEmpty) {
      failures.add(
        'the platform re-read returned an empty produced revision; '
        'WorkspaceHead.headRevision is non-empty by contract',
      );
    }

    if (reviewedRevision != null &&
        reviewedRevision.isNotEmpty &&
        producedRevision != null &&
        producedRevision.isNotEmpty &&
        reviewedRevision != producedRevision) {
      failures.add(
        'the reviewed revision "$reviewedRevision" is not the produced '
        'revision "$producedRevision"',
      );
    }

    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:review_verdict:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'review_verdict',
          artifactRef: 'engineering_review_result',
          content: <String, dynamic>{
            config.reviewedRevisionField: reviewedRevision,
            'established': reviewedRevision != null,
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
            config.producedRevisionField: producedRevision,
            'startingRevision': producedHead?.startingRevision,
            'headMoved': producedHead?.headMoved,
            'established': producedHead != null,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'reviewedRevision': reviewedRevision,
        'producedRevision': producedRevision,
        // WHERE the two revisions came from. `artifactRef` names the READER
        // (`engineering_review_result`, `workspace_head_reader`), and those
        // names are the same for the production adapter and for a fail-closed
        // stand-in — so without this key a persisted result cannot say which
        // one produced it (F-204).
        qaSourceProvenanceMetadataKey: source.provenance.toJson(),
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }
}

/// F5's declared half, validated up front.
///
/// `reviewedRevisionField` and `producedRevisionField` name the fields the
/// evidence rows carry. Only the design's field names are supported: a config
/// that names a field this source does not read would otherwise look as though
/// the gate read it.
class _RevisionIdentityConfig {
  const _RevisionIdentityConfig({
    required this.reviewedRevisionField,
    required this.producedRevisionField,
  });

  static const String supportedReviewedRevisionField = 'endingRevision';
  static const String supportedProducedRevisionField = 'producedRevision';

  final String reviewedRevisionField;
  final String producedRevisionField;

  static _RevisionIdentityConfig from(QAGateDefinition gate) {
    final reviewedField = gate.config['reviewedRevisionField'];
    if (reviewedField != supportedReviewedRevisionField) {
      throw FormatException(
        'gate ${gate.gateId} declares "reviewedRevisionField" as '
        '$reviewedField; the only supported value is '
        '"$supportedReviewedRevisionField"',
      );
    }

    final producedField = gate.config['producedRevisionField'];
    if (producedField != supportedProducedRevisionField) {
      throw FormatException(
        'gate ${gate.gateId} declares "producedRevisionField" as '
        '$producedField; the only supported value is '
        '"$supportedProducedRevisionField" (P1\'s re-read)',
      );
    }

    if (gate.config['requireStringEquality'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "requireStringEquality": true; '
        'anything else compares revisions by a rule no design defines',
      );
    }

    if (gate.config['nullRevisionIsFailure'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "nullRevisionIsFailure": true; a '
        'null revision was never established and cannot be a pass',
      );
    }

    return const _RevisionIdentityConfig(
      reviewedRevisionField: supportedReviewedRevisionField,
      producedRevisionField: supportedProducedRevisionField,
    );
  }
}
