library qa_orchestration;

export 'package:platform_contracts/platform_contracts.dart'
    show
        QAContract,
        QAContractSpec,
        QAGateDefinition,
        QAGateResult,
        QAGateSpec,
        QAGateStatus,
        QAEvidence,
        QAEvidenceDetermination,
        EvidenceDetermination,
        QAPassCriteria,
        QAWaiver,
        WorkItemCategory,
        QAEvidenceRow,
        AgentResult,
        PlatformVerification,
        WorkspaceHead,
        CommittedDiffPaths,
        Defect;

export 'src/gates/evaluators/change_scope_confinement_gate.dart';
export 'src/gates/evaluators/declared_validation_outcome_gate.dart';
export 'src/gates/evaluators/implementation_artifact_provenance_gate.dart';
export 'src/gates/evaluators/remediation_defect_existence_gate.dart';
export 'src/gates/evaluators/revision_identity_match_gate.dart';
export 'src/gates/gate_evaluator.dart';
export 'src/gates/gate_registry.dart';
export 'src/gates/predefined/static_analysis_gate.dart';
export 'src/gates/predefined/test_coverage_gate.dart';
export 'src/gates/predefined/security_scan_gate.dart';
export 'src/gates/predefined/performance_gate.dart';
export 'src/evidence/evidence_collector.dart';
export 'src/lane_g_qa_contract_store.dart';
export 'src/lane_g_triage_qa_contract.dart';
export 'src/product_qa_contract_spec_store.dart';
export 'src/product_qa_contract.dart';
export 'src/qa_orchestration.dart';
