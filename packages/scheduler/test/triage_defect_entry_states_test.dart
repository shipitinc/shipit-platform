import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

void main() {
  group('triageDefectDefinition entryStates', () {
    test('does not contain designApproved', () {
      // This test verifies that designApproved has been removed from
      // triageDefectDefinition.entryStates per §5.4(c).
      expect(
        triageDefectDefinition.entryStates,
        isNot(contains(WorkItemState.designApproved)),
        reason:
            'designApproved must not be in triageDefectDefinition.entryStates '
            'per design-revision.md §5.4(c)',
      );
    });

    test('contains expected entry states', () {
      // Verify the remaining entry states are still present.
      expect(
        triageDefectDefinition.entryStates,
        containsAll([
          WorkItemState.designNotRequired,
          WorkItemState.reviewRejected,
          WorkItemState.planned,
        ]),
      );
    });

    test('entryStates has exactly 3 states', () {
      // Exact count to catch accidental additions.
      expect(triageDefectDefinition.entryStates.length, 3);
    });

    test('entryProbeTargets does not reference designApproved', () {
      // The probe targets map should not have designApproved as a key.
      expect(
        triageDefectDefinition.entryProbeTargets.keys,
        isNot(contains(WorkItemState.designApproved)),
      );
    });

    test('entryProbeTargets only covers reviewRejected and planned', () {
      // These are the only two states that need custom probe targets
      // (they don't have the default -> agentExecuting edge).
      expect(
        triageDefectDefinition.entryProbeTargets.keys.toSet(),
        equals({WorkItemState.reviewRejected, WorkItemState.planned}),
      );
      expect(
        triageDefectDefinition.entryProbeTargets[WorkItemState.reviewRejected],
        WorkItemState.designNotRequired,
      );
      expect(
        triageDefectDefinition.entryProbeTargets[WorkItemState.planned],
        WorkItemState.designNotRequired,
      );
    });
  });
}
