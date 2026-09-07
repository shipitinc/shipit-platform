library qa_orchestration;

export 'package:platform_contracts/platform_contracts.dart'
    show
        QAContract,
        QAGateDefinition,
        QAGateResult,
        QAGateStatus,
        QAEvidence,
        QAPassCriteria,
        QAWaiver,
        WorkItemCategory,
        AgentResult;

export 'src/gates/gate_evaluator.dart';
export 'src/gates/gate_registry.dart';
export 'src/gates/predefined/static_analysis_gate.dart';
export 'src/gates/predefined/test_coverage_gate.dart';
export 'src/gates/predefined/security_scan_gate.dart';
export 'src/gates/predefined/performance_gate.dart';
export 'src/evidence/evidence_collector.dart';
export 'src/qa_orchestration.dart';
