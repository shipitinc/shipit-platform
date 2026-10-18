import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

/// §7.4 **C2** — `QAOrchestration.isOverallPass`, whose fix is one clause:
/// *"invert the iteration — loop `requiredGates` and look each one up in
/// `results`, failing on a miss — so it agrees with C1 by construction rather
/// than by parallel maintenance."*
///
/// Rows mirror `design/qa-contracts-feature-remediation/substantive-qa-gates.md`
/// §7.2's table, in the same order, so a reviewer can map each assertion to the
/// row it closes. §7.3 records that `isOverallPass` carried the guard's defect:
/// it filtered `results` by required gate ids and looped the **results**, so a
/// contract declaring three required gates and handed one passing result
/// returned `true` with two required gates never evaluated.
///
/// **§7.2 row 7 has no counterpart here, and that is a structural fact rather
/// than a gap in the coverage.** The guard's seventh hole was a `qaContract`
/// absent from `context`; `isOverallPass` takes the contract as a non-nullable
/// positional parameter, so there is no state in which the declared gate set is
/// absent. Asserting "the contract cannot be absent" is a type-level property
/// with no runtime observation to make.
///
/// Two things are deliberately **not** pinned here, because §7.4 specifies no
/// fix for either and inventing one is not an implementer's call:
///
///   * a contract declaring zero gates, or only `required: false` gates, still
///     passes vacuously — there is no required gate to be `not_executed` (F-106);
///   * `passCriteria.allRequiredGatesMustPass == false` skips the required-gate
///     branch entirely, so the missing-result check below never runs.
///
/// Both are reported, not asserted. Pinning either as correct would record a
/// design decision this lane has no authority to make.
void main() {
  const workItemId = '123e4567-e89b-12d3-a456-426614174001';

  final orchestration = QAOrchestration();

  QAGateDefinition gate(String gateId, {required bool isRequired}) =>
      QAGateDefinition(
        gateId: gateId,
        type: gateId,
        required: isRequired,
        config: const {},
        evidenceTypes: const ['test-report'],
      );

  QAContract contract(
    List<QAGateDefinition> gates, {
    QAPassCriteria? passCriteria,
  }) => QAContract(
    contractId: 'qa-1',
    workItemCategory: WorkItemCategory.feature,
    gates: gates,
    version: '1.0.0',
    passCriteria: passCriteria,
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

  QAGateResult skippedWithAuthority(String gateId) => QAGateResult(
    gateId: gateId,
    workItemId: workItemId,
    status: QAGateStatus.skipped,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
    evidenceDeterminations: [
      QAEvidenceDetermination(
        evidenceId: 'E-01',
        determination: EvidenceDetermination.skipped,
        reasons: 'Manual charter covers this journey',
        authorityRef: 'decision-123',
      ),
    ],
  );

  // A three-required-gate contract, used by rows 1-6 of §7.2.
  final threeRequired = [
    gate('static-analysis', isRequired: true),
    gate('unit-tests', isRequired: true),
    gate('security-scan', isRequired: true),
  ];

  group('isOverallPass — substantive-qa-gates.md §7.2', () {
    test('row 1: three required, three results all satisfied -> true', () {
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.passed),
        ], contract(threeRequired)),
        isTrue,
      );
    });

    test('row 2: three required, three results, one failed -> false', () {
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.failed),
        ], contract(threeRequired)),
        isFalse,
      );
    });

    test('row 3: three required, three results, one notExecuted -> false', () {
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.notExecuted),
        ], contract(threeRequired)),
        isFalse,
      );
    });

    test('row 4: three required, only the passing result supplied -> false', () {
      // PRE-FIX: TRUE. `results.where((r) => requiredGates.contains(...))`
      // filtered to the single passing element and the loop over one satisfied
      // element never returned false.
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
        ], contract(threeRequired)),
        isFalse,
        reason: 'a required gate with no result is not_executed, not absent',
      );
    });

    test('row 5: three required, empty results -> false', () {
      // PRE-FIX: TRUE. The filtered iterable was empty, so the loop body never
      // ran and the method fell through to `return true`.
      expect(orchestration.isOverallPass([], contract(threeRequired)), isFalse);
    });

    test('row 6: three required, results for undeclared gates -> false', () {
      // PRE-FIX: TRUE. Every result filtered out because no contract gate id
      // matched, leaving nothing to iterate.
      expect(
        orchestration.isOverallPass([
          result('docs', QAGateStatus.passed),
          result('changelog', QAGateStatus.passed),
          result('notes', QAGateStatus.passed),
        ], contract(threeRequired)),
        isFalse,
      );
    });

    test('row 4 again, one gate short of the declared set', () {
      // The subset hole is not specific to "one of three"; two of three fails
      // identically.
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
        ], contract(threeRequired)),
        isFalse,
      );
    });
  });

  group('isOverallPass — fail-closed properties', () {
    test('a duplicate result cannot mask a failing one', () {
      // §7.4 requires agreement with C1 *by construction*. C1 does not
      // collapse duplicates, so neither does this: a last-wins map keyed by
      // gate id would report the gate satisfied if the passing result landed
      // last.
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('static-analysis', QAGateStatus.failed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.passed),
        ], contract(threeRequired)),
        isFalse,
      );
    });

    test('optional gates are not required to have results', () {
      // The over-rejection guard. Inverting the iteration must not make an
      // optional gate mandatory, or the fix would reject contracts whose
      // optional gates were never run.
      expect(
        orchestration.isOverallPass(
          [
            result('static-analysis', QAGateStatus.passed),
            result('unit-tests', QAGateStatus.passed),
          ],
          contract([
            gate('static-analysis', isRequired: true),
            gate('unit-tests', isRequired: true),
            gate('docs', isRequired: false),
          ]),
        ),
        isTrue,
      );
    });

    test('an optional gate that did run is still counted by its threshold', () {
      // The optional branch is untouched by C2; this pins that it still runs
      // after the required branch was rewritten.
      final mixed = contract([
        gate('static-analysis', isRequired: true),
        gate('performance', isRequired: false),
      ], passCriteria: const QAPassCriteria(optionalGateFailuresAllowed: 1));

      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('performance', QAGateStatus.failed),
        ], mixed),
        isTrue,
      );
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('performance', QAGateStatus.failed),
          result('performance', QAGateStatus.failed),
        ], mixed),
        isFalse,
      );
    });

    test('a waived required gate with an authority ref is still satisfied', () {
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          skippedWithAuthority('security-scan'),
        ], contract(threeRequired)),
        isTrue,
      );
    });

    test('a required gate skipped WITHOUT authority still fails', () {
      // The present result is what distinguishes this from row 4: the result
      // exists, so the missing-result check cannot be what fails it.
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan', QAGateStatus.skipped),
        ], contract(threeRequired)),
        isFalse,
      );
    });

    test(
      'an unrelated failing result cannot rescue a missing required gate',
      () {
        // Two independent reasons to fail. Supplying a failing result for the
        // missing gate would attribute the verdict to the status alone, so the
        // subset case is asserted above with every declared gate present — this
        // test only pins that adding an unrelated failure cannot make a missing
        // required gate pass.
        expect(
          orchestration.isOverallPass([
            result('static-analysis', QAGateStatus.passed),
            result('unit-tests', QAGateStatus.failed),
          ], contract(threeRequired)),
          isFalse,
        );
      },
    );

    test('results for gates outside the contract do not satisfy it', () {
      // The inverse of the optional-gate property: an id the contract never
      // declared is not evidence that a declared gate was evaluated.
      expect(
        orchestration.isOverallPass([
          result('static-analysis', QAGateStatus.passed),
          result('unit-tests', QAGateStatus.passed),
          result('security-scan-legacy', QAGateStatus.passed),
        ], contract(threeRequired)),
        isFalse,
      );
    });
  });
}
