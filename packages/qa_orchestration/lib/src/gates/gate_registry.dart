import 'gate_evaluator.dart';
import 'evaluators/change_scope_confinement_gate.dart';
import 'evaluators/declared_validation_outcome_gate.dart';
import 'evaluators/implementation_artifact_provenance_gate.dart';
import 'evaluators/remediation_defect_existence_gate.dart';
import 'evaluators/revision_identity_match_gate.dart';
import 'evaluators/triage_classification_admitted_gate.dart';
import 'evaluators/triage_evidence_grounding_gate.dart';
import 'unwired_sources.dart';

class GateRegistry {
  final Map<String, GateEvaluator> _evaluators = {};

  void register(GateEvaluator evaluator) {
    _evaluators[evaluator.gateType] = evaluator;
  }

  GateEvaluator? get(String gateType) => _evaluators[gateType];

  List<GateEvaluator> get all => _evaluators.values.toList();
}

/// The registry every `QAOrchestration` reaches unless it is handed its own.
///
/// ## The four fabricating evaluators are DE-REGISTERED (slice 3a)
///
/// `StaticAnalysisGate` (`static-analysis`), `TestCoverageGate` (`unit-tests`),
/// `SecurityScanGate` (`security-scan`) and `PerformanceGate` (`performance`)
/// are no longer registered. Each returned a **fabricated `PASSING`** with an
/// audit trail: its collector built a constant `QAEvidence` (e.g.
/// `content: {'tool': …, 'issues': []}`) and `GateEvaluatorImpl._validateEvidence`
/// passed on `evidence.isNotEmpty` — i.e. on the *shape of the config alone*
/// (`gate_evaluator.dart:53-57`). A gate that produces identical output for
/// identical config is a constant, and `substantive-qa-gates.md` §6.4 **N1**
/// fails it trivially. `evaluator-spec.md` §5.2 option 2 — de-registration — is
/// the only option §5.2 leaves open, and it is what §8 **3a** requires *before
/// anything is wired*.
///
/// The four classes and their `predefined/` files are **kept**, not deleted:
/// `packages/qa_orchestration/lib/qa_orchestration.dart` still exports them, so
/// removing the files would break a public barrel a consumer may import. Only
/// their registration — the thing that made them reachable at runtime — is
/// removed. Nothing else in the repository imports them (verified: the only
/// references are the barrel and this file).
///
/// ## The seven reviewed evaluators are REGISTERED (M1)
///
/// Per `substantive-qa-gates.md` §4 and §8 **M1**: five feature-lane types
/// (F1 `implementation-artifact-provenance`, F2 `change-scope-confinement`,
/// F4 `declared-validation-outcome`, F5 `revision-identity-match`) plus the two
/// declared remediation types (R1 `triage-defect-existence`,
/// R2 `triage-evidence-grounding`) and the retained structural R3
/// (`triage-classification-structure`). Registering them is what stops
/// `QAOrchestration.evaluate` from answering `notExecuted` for a declared gate.
///
/// Six of the seven read through a source whose production adapter is **slice
/// 3c** and does not exist yet, so they are wired to the **fail-closed** sources
/// in `unwired_sources.dart`. Those sources can only ever deny a pass; see that
/// library's doc for the per-source answer. R3 (`TriageClassificationAdmittedGate`)
/// is source-free and reads the agent's own structured result.
final gateRegistry = GateRegistry()
  ..register(
    ImplementationArtifactProvenanceGate(
      source: const UnwiredArtifactProvenanceSource(),
    ),
  )
  ..register(
    ChangeScopeConfinementGate(source: const UnwiredChangeScopeSource()),
  )
  ..register(
    DeclaredValidationOutcomeGate(
      verificationReader: const UnwiredPlatformVerificationReader(),
    ),
  )
  ..register(
    RevisionIdentityMatchGate(source: const UnwiredRevisionIdentitySource()),
  )
  ..register(TriageClassificationAdmittedGate())
  ..register(
    RemediationDefectExistenceGate(
      defectReader: const UnwiredDefectRowReader(),
    ),
  )
  ..register(
    TriageEvidenceGroundingGate(
      defectEvidenceReader: const UnwiredDefectEvidenceReader(),
    ),
  );
