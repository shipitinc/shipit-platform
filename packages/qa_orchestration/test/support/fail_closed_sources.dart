/// **FAIL-CLOSED TEST DOUBLES — the six source-backed gate sources, unwired.**
///
/// ## WHY THEY ARE HERE AND NOT IN `lib/`
///
/// Until slice 3c these six sources lived in
/// `packages/qa_orchestration/lib/src/gates/unwired_sources.dart` and were
/// wired into a global `gateRegistry` that every consumer — production
/// included — silently inherited.
///
/// That was the F-204 hazard. A fail-closed stand-in and a production adapter
/// for the same gate produce evidence rows naming the **same** `artifactRef`,
/// because the `artifactRef` names the READER (`workspace_delta_probe`,
/// `workspace_head_reader`, `platform_verification`,
/// `engineering_review_result`) and not the READER'S BINDING. A persisted
/// `QAGateResult` could therefore not say whether the platform or a stand-in
/// had produced it.
///
/// Slice 3c moved the production adapters into the composition root
/// (`apps/server/lib/src/qa/`), deleted the global registry, and moved these
/// doubles here. A stand-in is now something a test reaches for **on purpose**,
/// from the test tree, where it cannot be inherited by anything that did not
/// ask for it — and every one of them declares
/// [QASourceProvenance.failClosed], so a result they produced says so.
///
/// ## WHAT "FAIL CLOSED" MEANS HERE, PER SOURCE
///
/// Every method answers the value the evaluator treats as a failure, never the
/// value that would pass:
///
/// * [FailClosedArtifactProvenanceSource] returns an [ExecutionDelta.unreadable]
///   delta and a `null` re-read → F1 fails with "I could not look".
/// * [FailClosedChangeScopeSource] returns a `null` baseline → F2 fails.
/// * [FailClosedPlatformVerificationReader] returns **no rows** → F4 fails on
///   completeness ("declared check … has no platform verification row").
/// * [FailClosedRevisionIdentitySource] returns a `null` reviewed revision → F5
///   fails.
/// * [FailClosedDefectRowReader] returns `null` → R1 fails.
/// * [FailClosedDefectEvidenceReader] returns **no rows** → R2 fails.
///
/// None of these is a constant `passed`. Each is the negative answer the
/// evaluator's own predicate reads as a failure, so a source that is not wired
/// can only ever **deny** a pass, never grant one.
library;

import 'package:qa_orchestration/qa_orchestration.dart';

/// F1's [ArtifactProvenanceSource], unwired: "I could not look", never "nothing
/// was produced".
///
/// The delta is [ExecutionDelta.unreadable], whose `isReadable == false` makes
/// F1 fail regardless of anything else, and the re-read returns `null` so the
/// "HEAD could not be established" branch is the one that fires.
class FailClosedArtifactProvenanceSource implements ArtifactProvenanceSource {
  const FailClosedArtifactProvenanceSource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-artifact-provenance',
  );

  @override
  Future<ExecutionDelta> readDelta(String workItemId) async {
    return const ExecutionDelta.unreadable(
      'the execution workspace probe is not wired to this gate; this is the '
      'fail-closed test double, not the production adapter',
    );
  }

  @override
  Future<WorkspaceHead?> reReadHead(
    String workItemId, {
    required String? startingRevision,
  }) async {
    return null;
  }
}

/// F2's [ChangeScopeSource], unwired: no baseline can be read, so the gate
/// fails before it ever enumerates a path.
class FailClosedChangeScopeSource implements ChangeScopeSource {
  const FailClosedChangeScopeSource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-change-scope',
  );

  @override
  Future<CommittedDiffScopeBaseline?> readBaseline(String workItemId) async {
    return null;
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    return null;
  }

  @override
  Future<CommittedDiffPaths> collectPaths({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async {
    // Unreachable while [readBaseline] returns `null`: F2 fails before the
    // collector is consulted. Throwing rather than returning an empty list
    // keeps the "a failed enumeration is never an empty list" contract even on
    // the path that cannot be taken today.
    throw StateError(
      'the committed-diff path collector is not wired to this gate; this is '
      'the fail-closed test double, not the production adapter',
    );
  }
}

/// F4's [PlatformVerificationReader], unwired: no rows, so every declared check
/// fails on completeness.
///
/// This is the honest shape for F4 today: the only verification row a
/// production execution writes carries the triage liveness probe's command
/// (`git rev-parse --verify 'HEAD^{commit}'`), which does not string-equal any
/// declared check command — so even a reader that returned live rows would
/// report a failure. Returning no rows says the same thing without pretending
/// the read happened.
class FailClosedPlatformVerificationReader
    implements PlatformVerificationReader {
  const FailClosedPlatformVerificationReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-platform-verification',
  );

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    return const [];
  }
}

/// F5's [RevisionIdentitySource], unwired: no reviewed revision and no produced
/// head, so the gate fails.
class FailClosedRevisionIdentitySource implements RevisionIdentitySource {
  const FailClosedRevisionIdentitySource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-revision-identity',
  );

  @override
  Future<String?> readReviewedRevision(String workItemId) async {
    return null;
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    return null;
  }
}

/// R1's [DefectRowReader], unwired: no row resolves, so the gate fails.
class FailClosedDefectRowReader implements DefectRowReader {
  const FailClosedDefectRowReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-defect-row',
  );

  @override
  Future<Defect?> readDefect(String defectId) async {
    return null;
  }
}

/// R2's [DefectEvidenceReader], unwired: no evidence rows, so a cited id cannot
/// be grounded.
class FailClosedDefectEvidenceReader implements DefectEvidenceReader {
  const FailClosedDefectEvidenceReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'test-support/fail-closed-defect-evidence',
  );

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async {
    return const [];
  }
}

/// A registry over the six fail-closed doubles and the source-free R3.
///
/// This is what a test uses when it wants the seven reviewed types
/// **registered** without any of them being able to pass.
GateRegistry buildFailClosedTestRegistry() => buildGateRegistry(
  artifactProvenanceSource: const FailClosedArtifactProvenanceSource(),
  changeScopeSource: const FailClosedChangeScopeSource(),
  platformVerificationReader: const FailClosedPlatformVerificationReader(),
  revisionIdentitySource: const FailClosedRevisionIdentitySource(),
  defectRowReader: const FailClosedDefectRowReader(),
  defectEvidenceReader: const FailClosedDefectEvidenceReader(),
);
