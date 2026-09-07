import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

void main() {
  group('QAOrchestration', () {
    late QAOrchestration orchestration;

    setUp(() {
      orchestration = QAOrchestration();
    });

    test('evaluates all gates in contract', () async {
      final contract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'static-analysis',
            type: 'static-analysis',
            required: true,
            config: {'tool': 'dart analyze'},
            evidenceTypes: ['static-analysis-report'],
          ),
          QAGateDefinition(
            gateId: 'unit-tests',
            type: 'unit-tests',
            required: true,
            config: {'threshold': 0.8},
            evidenceTypes: ['coverage-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final agentResult = AgentResult(
        resultId: 'result-1',
        sessionId: 'session-1',
        workItemId: 'work-1',
        status: AgentResultStatus.completed,
        artifacts: [],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 1000,
          toolCalls: 5,
          errors: [],
          warnings: [],
        ),
        structuredResult: {},
        completedAt: DateTime.now(),
      );

      final results = await orchestration.evaluate(
        'work-1',
        agentResult,
        contract,
      );

      expect(results.length, equals(2));
      expect(
        results.map((r) => r.gateId).toSet(),
        equals({'static-analysis', 'unit-tests'}),
      );
    });

    test('returns overall pass when all required gates pass', () {
      final contract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'static-analysis',
            type: 'static-analysis',
            required: true,
            config: {},
            evidenceTypes: ['static-analysis-report'],
          ),
          QAGateDefinition(
            gateId: 'unit-tests',
            type: 'unit-tests',
            required: true,
            config: {},
            evidenceTypes: ['coverage-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final results = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'work-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'unit-tests',
          workItemId: 'work-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
      ];

      expect(orchestration.isOverallPass(results, contract), isTrue);
    });

    test('returns overall fail when required gate fails', () {
      final contract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'static-analysis',
            type: 'static-analysis',
            required: true,
            config: {},
            evidenceTypes: ['static-analysis-report'],
          ),
          QAGateDefinition(
            gateId: 'unit-tests',
            type: 'unit-tests',
            required: true,
            config: {},
            evidenceTypes: ['coverage-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final results = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'work-1',
          status: QAGateStatus.failed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'unit-tests',
          workItemId: 'work-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
      ];

      expect(orchestration.isOverallPass(results, contract), isFalse);
    });

    test('allows optional gate failures within threshold', () {
      final contract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'static-analysis',
            type: 'static-analysis',
            required: true,
            config: {},
            evidenceTypes: ['static-analysis-report'],
          ),
          QAGateDefinition(
            gateId: 'performance',
            type: 'performance',
            required: false,
            config: {},
            evidenceTypes: ['performance-metrics'],
          ),
        ],
        version: '1.0.0',
        passCriteria: QAPassCriteria(optionalGateFailuresAllowed: 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final results = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'work-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'performance',
          workItemId: 'work-1',
          status: QAGateStatus.failed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
      ];

      expect(orchestration.isOverallPass(results, contract), isTrue);
    });

    test('fails when optional failures exceed threshold', () {
      final contract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'static-analysis',
            type: 'static-analysis',
            required: true,
            config: {},
            evidenceTypes: ['static-analysis-report'],
          ),
          QAGateDefinition(
            gateId: 'performance',
            type: 'performance',
            required: false,
            config: {},
            evidenceTypes: ['performance-metrics'],
          ),
          QAGateDefinition(
            gateId: 'security-scan',
            type: 'security-scan',
            required: false,
            config: {},
            evidenceTypes: ['security-scan-report'],
          ),
        ],
        version: '1.0.0',
        passCriteria: QAPassCriteria(optionalGateFailuresAllowed: 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final results = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'work-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'performance',
          workItemId: 'work-1',
          status: QAGateStatus.failed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'security-scan',
          workItemId: 'work-1',
          status: QAGateStatus.failed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
      ];

      expect(orchestration.isOverallPass(results, contract), isFalse);
    });
  });
}
