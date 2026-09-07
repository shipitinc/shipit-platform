import 'gate_evaluator.dart';
import 'predefined/performance_gate.dart';
import 'predefined/security_scan_gate.dart';
import 'predefined/static_analysis_gate.dart';
import 'predefined/test_coverage_gate.dart';

class GateRegistry {
  final Map<String, GateEvaluator> _evaluators = {};

  void register(GateEvaluator evaluator) {
    _evaluators[evaluator.gateType] = evaluator;
  }

  GateEvaluator? get(String gateType) => _evaluators[gateType];

  List<GateEvaluator> get all => _evaluators.values.toList();
}

final gateRegistry = GateRegistry()
  ..register(StaticAnalysisGate())
  ..register(TestCoverageGate())
  ..register(SecurityScanGate())
  ..register(PerformanceGate());
