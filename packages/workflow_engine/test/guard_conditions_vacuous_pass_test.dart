import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// One row per row of `design/qa-contracts-feature-remediation/
/// substantive-qa-gates.md` §7.2, in the same order, so a reviewer can map
/// each assertion to the table it closes.
///
/// §7.2's table has three rows that were green-and-wrong on the pre-fix tree
/// (rows 4, 5 and 6) plus a fourth hole the table records as its last row
/// (contract absent). Each is asserted here as a failure, so the invariant
/// *"a required gate with no result is `not_executed`, not absent"* is pinned
/// as executable knowledge rather than as prose.
///
/// These assert the guard directly rather than through a whole transition, so
/// a failure names the row instead of a failed edge.
void main() {
  const workItemId = '123e4567-e89b-12d3-a456-426614174001';

  final engine = const WorkflowEngine();

  QAGateDefinition gate(String gateId, {required bool isRequired}) =>
      QAGateDefinition(
        gateId: gateId,
        type: gateId,
        required: isRequired,
        config: const {},
        evidenceTypes: const ['test-report'],
      );

  QAContract contract(List<QAGateDefinition> gates) => QAContract(
    contractId: 'qa-1',
    workItemCategory: WorkItemCategory.feature,
    gates: gates,
    version: '1.0.0',
    createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
  );

  QAGateResult result(String gateId, QAGateStatus status) => QAGateResult(
    gateId: gateId,
    workItemId: workItemId,
    status: status,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
  );

  GuardResult evaluate({
    required List<QAGateDefinition> gates,
    List<QAGateResult>? gateResults,
    bool includeContract = true,
  }) {
    final context = <String, dynamic>{
      if (includeContract) 'qaContract': contract(gates),
      'gateResults': gateResults ?? const [],
    };
    return engine
        .evaluateWorkItemTransition(
          from: WorkItemState.qaInProgress,
          to: WorkItemState.qaPassed,
          trigger: TransitionTrigger.agentResult,
          actor: const WorkflowActor(
            actorId: 'qa-1',
            actorType: ActorType.qaExecutor,
          ),
          context: context,
        )
        .guardResults
        .firstWhere((g) => g.name == 'all_required_gates_passed');
  }

  // A three-required-gate contract, used by rows 1-6 of §7.2.
  final threeRequired = [
    gate('static-analysis', isRequired: true),
    gate('unit-tests', isRequired: true),
    gate('security-scan', isRequired: true),
  ];

  group('allRequiredGatesPassed — substantive-qa-gates.md §7.2', () {
    test('row 1: three required, three results all satisfied -> pass', () {
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.passed),
        ],
      );
      expect(verdict.passed, isTrue);
    });

    test('row 2: three required, three results, one failed -> fail', () {
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.failed),
        ],
      );
      expect(verdict.passed, isFalse);
    });

    test('row 3: three required, three results, one notExecuted -> fail', () {
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.notExecuted),
        ],
      );
      expect(verdict.passed, isFalse);
    });

    test('row 4: three required, only the passing result supplied -> FAIL', () {
      // PRE-FIX: PASS. `gateResults.where(...)` filtered to the single passing
      // element and `.every()` on one element is true.
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [result('static-analysis', QAGateStatus.passed)],
      );
      expect(
        verdict.passed,
        isFalse,
        reason: 'a required gate with no result is not_executed, not absent',
      );
      expect(verdict.message, contains('unit-tests'));
    });

    test('row 5: three required, empty results -> FAIL', () {
      // PRE-FIX: PASS. `.every()` over an empty iterable is true.
      final verdict = evaluate(gates: threeRequired, gateResults: []);
      expect(verdict.passed, isFalse);
      expect(verdict.message, contains('static-analysis'));
    });

    test('row 6: three required, results for three optional gates -> FAIL', () {
      // PRE-FIX: PASS. Every result was filtered out because no contract gate
      // matched, leaving `.every()` over nothing.
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('docs', QAGateStatus.passed),
          result('changelog', QAGateStatus.passed),
          result('notes', QAGateStatus.passed),
        ],
      );
      expect(verdict.passed, isFalse);
      expect(verdict.message, contains('static-analysis'));
    });

    test('row 7: contract absent, results present -> FAIL', () {
      // PRE-FIX: PASS. `context?['qaContract']?... ?? false` made every result
      // filter out.
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [result('static-analysis', QAGateStatus.passed)],
        includeContract: false,
      );
      expect(verdict.passed, isFalse);
      expect(verdict.message, contains('qaContract'));
    });
  });

  group('allRequiredGatesPassed — fail-closed properties', () {
    test('no gateResults key at all still fails', () {
      final context = <String, dynamic>{'qaContract': contract(threeRequired)};
      final transition = engine.evaluateWorkItemTransition(
        from: WorkItemState.qaInProgress,
        to: WorkItemState.qaPassed,
        trigger: TransitionTrigger.agentResult,
        actor: const WorkflowActor(
          actorId: 'qa-1',
          actorType: ActorType.qaExecutor,
        ),
        context: context,
      );
      expect(transition.isValid, isFalse);
      expect(transition.failedGuards, contains('all_required_gates_passed'));
    });

    test('a duplicate result cannot mask a failing one', () {
      // Both results carry the same gate id. A lookup that collapses
      // duplicates (map keyed by gateId, last-wins) would report the gate
      // satisfied if the passing result happened to be last.
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('static-analysis', QAGateStatus.failed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.passed),
        ],
      );
      expect(verdict.passed, isFalse);
    });

    test('the first missing gate is named, not a generic message', () {
      final verdict = evaluate(
        gates: threeRequired,
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
        ],
      );
      expect(verdict.passed, isFalse);
      expect(verdict.message, contains('security-scan'));
    });

    test('optional gates are not required to have results', () {
      // A required gate still governs the verdict; an optional gate with no
      // result must not itself fail the guard, or the fix would over-reject.
      final verdict = evaluate(
        gates: [
          gate('static-analysis', isRequired: true),
          gate('unit-tests', isRequired: true),
          gate('docs', isRequired: false),
        ],
        gateResults: [
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
        ],
      );
      expect(verdict.passed, isTrue);
    });
  });

  group('qaPassed reachability', () {
    test('the guard cannot be bypassed to reach qaPassed', () {
      final permissive = engine.evaluateWorkItemTransition(
        from: WorkItemState.qaInProgress,
        to: WorkItemState.qaPassed,
        trigger: TransitionTrigger.agentResult,
        actor: const WorkflowActor(
          actorId: 'qa-1',
          actorType: ActorType.qaExecutor,
        ),
        context: {
          'qaContract': contract(threeRequired),
          'gateResults': [result('static-analysis', QAGateStatus.passed)],
        },
      );
      expect(permissive.isValid, isFalse);
      expect(permissive.failedGuards, contains('all_required_gates_passed'));
    });
  });
}
