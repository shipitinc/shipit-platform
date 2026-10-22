/// A gate registry built over FAIL-CLOSED doubles, for tests that need to ask
/// "is this gate type registered?" and nothing more.
///
/// ## WHY THIS EXISTS, AND WHY IT IS NOT THE SAME THING AS PRODUCTION
///
/// `qa_orchestration` has no global registry. Until slice 3c it exported one
/// wired to six fail-closed stand-ins, and every consumer — production
/// included — silently inherited it (F-204). The global is gone; the registry
/// is now built by whoever assembles it, over sources that reader names
/// explicitly.
///
/// So "is the declared gate type registered?" is no longer a question about a
/// global. It is a question about the registry the ASSEMBLER builds, and the
/// registration itself is a property of `buildGateRegistry` — the seven
/// evaluators it registers do not depend on which sources it is handed.
///
/// This helper therefore builds the registry through the SAME factory
/// production uses, over doubles that can only deny. That is enough to answer
/// the registration question exactly, and it is enough to answer it without a
/// database.
///
/// ## WHY THE DOUBLES FAIL CLOSED
///
/// Every method answers the value the evaluator treats as a failure, never the
/// value that would pass:
///
/// * the artifact-provenance source answers `ExecutionDelta.unreadable` and a
///   `null` re-read — F1 fails with "I could not look";
/// * the change-scope source answers a `null` baseline — F2 fails;
/// * the verification reader answers **no rows** — F4 fails on completeness;
/// * the revision-identity source answers a `null` reviewed revision — F5
///   fails;
/// * the defect-row reader answers `null` — R1 fails;
/// * the defect-evidence reader answers **no rows** — R2 fails.
///
/// None of them is a constant "passed". A double that could grant a pass
/// would be a test that could certify a gate it never ran.
///
/// The doubles declare [QASourceProvenance.failClosed], so a result they
/// produced says so — the same distinction F-204 is about, kept in the test
/// tree where it belongs.
library;

import 'package:qa_orchestration/qa_orchestration.dart';

/// Builds the gate registry over fail-closed doubles.
///
/// Use it to assert that a gate TYPE is registered. Do not use it to assert
/// that a gate PASSES: a pass asserted here would be a pass asserted about a
/// double, not about the platform.
///
/// [changeScopeSource] may be supplied to replace the fail-closed
/// change-scope double with a real reader. That is the one seam a
/// demonstration needs: the change-scope gate's verdict depends on what is
/// actually in a repository, so a demonstration of that verdict cannot be
/// asserted over a double that refuses to look. Every other source stays
/// fail-closed, because a demonstration of ONE gate's verdict must not be
/// able to pass because of another gate's.
GateRegistry buildGateRegistryOverDoubles({
  ChangeScopeSource? changeScopeSource,
}) {
  return buildGateRegistry(
    artifactProvenanceSource: const _FailClosedArtifactProvenanceSource(),
    changeScopeSource:
        changeScopeSource ?? const _FailClosedChangeScopeSource(),
    platformVerificationReader: const _FailClosedVerificationReader(),
    revisionIdentitySource: const _FailClosedRevisionIdentitySource(),
    defectRowReader: const _FailClosedDefectRowReader(),
    defectEvidenceReader: const _FailClosedDefectEvidenceReader(),
  );
}

class _FailClosedArtifactProvenanceSource implements ArtifactProvenanceSource {
  const _FailClosedArtifactProvenanceSource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/artifact-provenance',
  );

  @override
  Future<ExecutionDelta> readDelta(String workItemId) async {
    return const ExecutionDelta.unreadable(
      'this is the fail-closed test double, not the production adapter',
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

class _FailClosedChangeScopeSource implements ChangeScopeSource {
  const _FailClosedChangeScopeSource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/change-scope',
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
    return CommittedDiffPaths(
      startingRevision: startingRevision,
      producedRevision: producedRevision,
      paths: const [],
    );
  }
}

class _FailClosedVerificationReader implements PlatformVerificationReader {
  const _FailClosedVerificationReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/platform-verification',
  );

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    return const [];
  }
}

class _FailClosedRevisionIdentitySource implements RevisionIdentitySource {
  const _FailClosedRevisionIdentitySource();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/revision-identity',
  );

  @override
  Future<String?> readReviewedRevision(String workItemId) async => null;

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async => null;
}

class _FailClosedDefectRowReader implements DefectRowReader {
  const _FailClosedDefectRowReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/defect-row',
  );

  @override
  Future<Defect?> readDefect(String defectId) async => null;
}

class _FailClosedDefectEvidenceReader implements DefectEvidenceReader {
  const _FailClosedDefectEvidenceReader();

  @override
  QASourceProvenance get provenance => const QASourceProvenance.failClosed(
    'apps-server-test/defect-evidence',
  );

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async {
    return const [];
  }
}
