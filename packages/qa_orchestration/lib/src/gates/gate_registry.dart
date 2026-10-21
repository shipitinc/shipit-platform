import 'gate_evaluator.dart';
import 'evaluators/change_scope_confinement_gate.dart';
import 'evaluators/declared_validation_outcome_gate.dart';
import 'evaluators/implementation_artifact_provenance_gate.dart';
import 'evaluators/remediation_defect_existence_gate.dart';
import 'evaluators/revision_identity_match_gate.dart';
import 'evaluators/triage_classification_admitted_gate.dart';
import 'evaluators/triage_evidence_grounding_gate.dart';

/// The registry of gate evaluators, keyed by the gate `type` a contract
/// declares.
///
/// ## A REGISTRY IS BUILT, NEVER REACHED FOR
///
/// There is no global registry. A registry is assembled by
/// [buildGateRegistry] from a named set of sources, and whoever assembles it
/// is the party that decides which reader answers each gate.
///
/// That is not a style preference. Until slice 3c this file exported a global
/// `gateRegistry` wired to the six fail-closed stand-ins in
/// `unwired_sources.dart`, which meant every consumer — production included —
/// silently inherited stand-ins whose evidence rows named the same
/// `artifactRef` as the production adapters' (`workspace_delta_probe`,
/// `workspace_head_reader`, `platform_verification`, `engineering_review_result`),
/// because the `artifactRef` names the READER, not the READER'S BINDING. A
/// persisted `QAGateResult` therefore could not say whether it had been
/// produced by the platform or by a stand-in (F-204). The stand-ins are gone
/// from `lib/` entirely; the same doubles now live in the test tree, where a
/// stand-in is what it should be — something a test reaches for on purpose.
class GateRegistry {
  final Map<String, GateEvaluator> _evaluators = {};

  void register(GateEvaluator evaluator) {
    _evaluators[evaluator.gateType] = evaluator;
  }

  GateEvaluator? get(String gateType) => _evaluators[gateType];

  List<GateEvaluator> get all => _evaluators.values.toList();
}

/// Builds the registry of the seven reviewed evaluators, over the sources the
/// caller supplies.
///
/// ## WHAT IS REGISTERED
///
/// Per `substantive-qa-gates.md` §4 and §8 **M1**: five feature-lane types
/// (F1 `implementation-artifact-provenance`, F2 `change-scope-confinement`,
/// F4 `declared-validation-outcome`, F5 `revision-identity-match`) plus the
/// two declared remediation types (R1 `triage-defect-existence`,
/// R2 `triage-evidence-grounding`) and the retained structural R3
/// (`triage-classification-structure`). Registering them is what stops
/// `QAOrchestration.evaluate` from answering `notExecuted` for a declared gate.
///
/// The four fabricating evaluators — `StaticAnalysisGate`
/// (`static-analysis`), `TestCoverageGate` (`unit-tests`), `SecurityScanGate`
/// (`security-scan`) and `PerformanceGate` (`performance`) — are **not**
/// registered, and are not registrable through this factory. Each returned a
/// **fabricated `PASSING`** with an audit trail: its collector built a
/// constant `QAEvidence` (e.g. `content: {'tool': …, 'issues': []}`) and
/// `GateEvaluatorImpl._validateEvidence` passed on `evidence.isNotEmpty` —
/// i.e. on the *shape of the config alone* (`gate_evaluator.dart:53-57`). A
/// gate that produces identical output for identical config is a constant,
/// and `substantive-qa-gates.md` §6.4 **N1** fails it trivially.
/// `evaluator-spec.md` §5.2 option 2 — de-registration — is the only option
/// §5.2 leaves open, and it is what §8 **3a** requires *before anything is
/// wired*.
///
/// The four classes and their `predefined/` files are **kept**, not deleted:
/// the package barrel still exports them, so removing the files would break a
/// public barrel a consumer may import. Only their registration — the thing
/// that made them reachable at runtime — is removed.
///
/// ## R3 IS SOURCE-FREE
///
/// R3 (`TriageClassificationAdmittedGate`) reads the agent's own structured
/// result and needs no source, so it takes no argument here.
///
/// ## THE SOURCES ARE THE CALLER'S TO CHOOSE
///
/// The six source-backed evaluators are handed the sources. A production
/// composition root hands it the production adapters; a test hands it
/// fail-closed doubles. Every source declares its own
/// `QASourceProvenance`, so the resulting gate results say which of the two
/// produced them, and the record is not a claim about the platform when it was
/// not.
GateRegistry buildGateRegistry({
  required ArtifactProvenanceSource artifactProvenanceSource,
  required ChangeScopeSource changeScopeSource,
  required PlatformVerificationReader platformVerificationReader,
  required RevisionIdentitySource revisionIdentitySource,
  required DefectRowReader defectRowReader,
  required DefectEvidenceReader defectEvidenceReader,
}) {
  return GateRegistry()
    ..register(
      ImplementationArtifactProvenanceGate(source: artifactProvenanceSource),
    )
    ..register(ChangeScopeConfinementGate(source: changeScopeSource))
    ..register(
      DeclaredValidationOutcomeGate(
        verificationReader: platformVerificationReader,
      ),
    )
    ..register(RevisionIdentityMatchGate(source: revisionIdentitySource))
    ..register(TriageClassificationAdmittedGate())
    ..register(RemediationDefectExistenceGate(defectReader: defectRowReader))
    ..register(
      TriageEvidenceGroundingGate(defectEvidenceReader: defectEvidenceReader),
    );
}
