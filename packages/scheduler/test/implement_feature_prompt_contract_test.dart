/// Drift guard for the implementation prompt's QA-contract reference (F-248).
///
/// `implementFeatureInstruction` used to inject
/// `QA CONTRACT: <id> — the acceptance criteria there are the ones this run is
/// judged against`. The id names a row in the control-plane database
/// (`qa-product-<workItemId>`), not a file in the agent's worktree, and the
/// demonstrated consequence — F-247's diagnosis — was the agent burning its
/// turn hunting the unreachable contract, asking for an `external_directory`
/// permission, being denied, ending its turn, and leaving no artifact. Two
/// different models failed identically.
///
/// The fix keeps the id as informational provenance — the instruction is
/// persisted on the job row and the id is the join key back to the contract —
/// while telling the agent, plainly, that the record cannot be opened from
/// where it is working and that the criteria it can act on are already in the
/// instruction. These tests pin both halves: the hunt-stopping wording and
/// the absence of the wording that caused the hunt.
library;

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

WorkItem _item({String? qaContractId, Map<String, dynamic>? metadata}) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: 'wi-impl-1',
    productId: 'p-1',
    category: WorkItemCategory.feature,
    title: 'Implement the calculator',
    description: 'add() for the calculator contract',
    state: WorkItemState.implementationReady,
    qaContractId: qaContractId,
    metadata: metadata,
    createdAt: now,
    updatedAt: now,
  );
}

String _prompt({String? qaContractId, Map<String, dynamic>? metadata}) =>
    implementFeatureInstruction(
      _item(qaContractId: qaContractId, metadata: metadata),
      implementFeatureDefinition,
    );

void main() {
  group('the QA contract reference can no longer send the agent hunting', () {
    test(
      'the contract id is still present, for the audit trail on the job row',
      () {
        expect(
          _prompt(qaContractId: 'qa-product-wi-impl-1'),
          contains('qa-product-wi-impl-1'),
          reason:
              'the id is the join key from the persisted instruction back to '
              'the contract row; dropping it was never the defect.',
        );
      },
    );

    test('the wording that claimed the criteria live there is gone', () {
      final prompt = _prompt(qaContractId: 'qa-product-wi-impl-1');
      expect(prompt, isNot(contains('the acceptance criteria there')));
      expect(
        prompt,
        isNot(contains('are the ones this run is judged against')),
        reason:
            'that sentence is what told the agent the criteria it must satisfy '
            'live inside an artifact it cannot reach — the F-247 trigger.',
      );
    });

    test('the reference is marked informational and unreachable', () {
      final prompt = _prompt(
        qaContractId: 'qa-product-wi-impl-1',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(prompt, contains('informational only'));
      expect(prompt, contains('not a file in this worktree'));
      expect(prompt, contains('cannot be opened'));
      expect(
        prompt,
        contains('do not look for it'),
        reason:
            'the demonstrated failure was the agent spending its turn '
            'locating the contract. The instruction has to forbid the hunt, '
            'not merely stop encouraging it.',
      );
    });

    test('the agent is told where the criteria it can act on already are', () {
      final prompt = _prompt(
        qaContractId: 'qa-product-wi-impl-1',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        prompt,
        contains('are already above'),
        reason:
            'the requirement is that the agent gets the criteria in reach or '
            'stops being pointed at an unreachable artifact; this names the '
            'in-reach half.',
      );
      expect(prompt, contains('DESCRIPTION'));
      expect(prompt, contains('ACCEPTANCE CRITERIA'));
      expect(prompt, contains('WORKING INSTRUCTIONS'));
    });

    test('no contract line is emitted when the item carries no contract', () {
      expect(_prompt(), isNot(contains('QA CONTRACT')));
    });
  });

  group('the in-reach criteria are still genuinely present', () {
    test('metadata acceptance criteria are inlined verbatim', () {
      final prompt = _prompt(
        qaContractId: 'qa-product-wi-impl-1',
        metadata: const {
          'acceptanceCriteria': 'add(2, 3) returns 5; add(-1, 1) returns 0',
        },
      );
      expect(prompt, contains('ACCEPTANCE CRITERIA:'));
      expect(
        prompt,
        contains('add(2, 3) returns 5; add(-1, 1) returns 0'),
        reason:
            'the agent-facing criteria are the metadata ones, inlined — this '
            'is the half the contract never carried.',
      );
    });

    test('the instruction still demands a commit, which the gates assert', () {
      final prompt = _prompt(qaContractId: 'qa-product-wi-impl-1');
      expect(prompt, contains('Commit your work'));
      expect(
        prompt,
        contains('Committing nothing is not a valid way to finish'),
      );
    });
  });
}
