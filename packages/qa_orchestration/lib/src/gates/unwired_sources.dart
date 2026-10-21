/// **PROVISIONAL, FAIL-CLOSED, NON-PRODUCTION SOURCES — slice 3c replaces every
/// one of these with a real adapter.**
///
/// ## Why these exist, and why they are not a fabricated pass
///
/// M1 (`substantive-qa-gates.md` §8) registers the seven reviewed evaluators so
/// that no contract ever declares a gate whose type has no evaluator. Six of the
/// seven evaluators read their facts through a source interface
/// ([ArtifactProvenanceSource], [ChangeScopeSource],
/// [PlatformVerificationReader], [RevisionIdentitySource], [DefectRowReader],
/// [DefectEvidenceReader]) whose production implementation is **slice 3c's**, and
/// does not exist yet (`AGENTS.md`'s shared-ownership rule and the design's own
/// §9 gap 5 both keep the readers out of this lane).
///
/// The alternative to wiring them here is to leave the six types unregistered,
/// which is what M1 exists to end — an unregistered type answers
/// `QAGateStatus.notExecuted` (`qa_orchestration.dart:19-31`), which reads as "no
/// evaluator exists" rather than "the gate ran and failed". Registration with a
/// source that **cannot pass** is the honest state: the evaluator runs, and it
/// fails closed on every input a production path can produce today.
///
/// ## What "fail closed" means here, per source
///
/// Every method answers the value the evaluator treats as a failure, never the
/// value that would pass:
///
/// * [UnwiredArtifactProvenanceSource] returns an [ExecutionDelta.unreadable]
///   delta and a `null` re-read → F1 fails with "I could not look".
/// * [UnwiredChangeScopeSource] returns a `null` baseline → F2 fails.
/// * [UnwiredPlatformVerificationReader] returns **no rows** → F4 fails on
///   completeness ("declared check … has no platform verification row").
/// * [UnwiredRevisionIdentitySource] returns a `null` reviewed revision → F5
///   fails.
/// * [UnwiredDefectRowReader] returns `null` → R1 fails.
/// * [UnwiredDefectEvidenceReader] returns **no rows** → R2 fails.
///
/// None of these is a constant `passed`. Each is the negative answer the
/// evaluator's own predicate reads as a failure, so a source that is not yet
/// wired can only ever **deny** a pass, never grant one.
///
/// ## What this does NOT do
///
/// It does not decide `OD-6`, it does not implement P1's readers, and it does
/// not make any feature gate green. It makes each gate **evaluable and red**
/// until 3c supplies the adapter — which is the state M1 is allowed to ship in,
/// because M1 follows E1–E3 and §8's ordering obligation is "no contract
/// declares a gate with no evaluator", not "every gate is green".
library;

import 'package:platform_contracts/platform_contracts.dart';

import 'evaluators/change_scope_confinement_gate.dart';
import 'evaluators/declared_validation_outcome_gate.dart';
import 'evaluators/implementation_artifact_provenance_gate.dart';
import 'evaluators/remediation_defect_existence_gate.dart';
import 'evaluators/revision_identity_match_gate.dart';
import 'evaluators/triage_evidence_grounding_gate.dart';

/// F1's [ArtifactProvenanceSource], unwired: "I could not look", never "nothing
/// was produced".
///
/// The delta is [ExecutionDelta.unreadable], whose `isReadable == false` makes
/// F1 fail regardless of anything else, and the re-read returns `null` so the
/// "HEAD could not be established" branch is the one that fires.
class UnwiredArtifactProvenanceSource implements ArtifactProvenanceSource {
  const UnwiredArtifactProvenanceSource();

  @override
  Future<ExecutionDelta> readDelta(String workItemId) async {
    return const ExecutionDelta.unreadable(
      'the execution workspace probe is not wired to this gate yet; the '
      'production adapter is slice 3c (substantive-qa-gates.md §8 P1)',
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
class UnwiredChangeScopeSource implements ChangeScopeSource {
  const UnwiredChangeScopeSource();

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
      'the committed-diff path collector is not wired to this gate yet; the '
      'production adapter is slice 3c (substantive-qa-gates.md §8 P1)',
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
class UnwiredPlatformVerificationReader implements PlatformVerificationReader {
  const UnwiredPlatformVerificationReader();

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    return const [];
  }
}

/// F5's [RevisionIdentitySource], unwired: no reviewed revision and no produced
/// head, so the gate fails.
class UnwiredRevisionIdentitySource implements RevisionIdentitySource {
  const UnwiredRevisionIdentitySource();

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
class UnwiredDefectRowReader implements DefectRowReader {
  const UnwiredDefectRowReader();

  @override
  Future<Defect?> readDefect(String defectId) async {
    return null;
  }
}

/// R2's [DefectEvidenceReader], unwired: no evidence rows, so a cited id cannot
/// be grounded.
class UnwiredDefectEvidenceReader implements DefectEvidenceReader {
  const UnwiredDefectEvidenceReader();

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async {
    return const [];
  }
}
