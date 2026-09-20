import 'package:control_plane/shared/transition_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the accepted-pair table in
/// `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`
/// (enumerated from source this session) plus the generic non-terminal ->
/// cancelled/terminated escapes, so the plain-copy layer can never silently
/// fall back on a pair the engine actually produces.
const _engineAcceptedPairs = <(String, String)>[
  // Planning
  ('draft', 'planning'),
  ('planning', 'planned'),
  ('planning', 'cancelled'),
  ('planned', 'design_required'),
  ('planned', 'design_not_required'),
  // Design
  ('design_required', 'design_in_review'),
  ('design_in_review', 'waiting_for_human_decision'),
  ('waiting_for_human_decision', 'design_approved'),
  ('waiting_for_human_decision', 'design_rejected'),
  ('waiting_for_human_decision', 'design_in_review'),
  ('design_approved', 'agent_executing'),
  ('design_rejected', 'design_in_review'),
  // Execution
  ('design_not_required', 'agent_executing'),
  ('agent_executing', 'agent_completed'),
  ('agent_executing', 'agent_failed'),
  ('agent_failed', 'agent_executing'),
  // Engineering review
  ('agent_completed', 'review_in_progress'),
  ('review_in_progress', 'waiting_for_human_decision'),
  ('waiting_for_human_decision', 'review_approved'),
  ('waiting_for_human_decision', 'review_rejected'),
  ('waiting_for_human_decision', 'agent_executing'),
  ('review_approved', 'qa_in_progress'),
  ('review_rejected', 'agent_executing'),
  ('review_rejected', 'design_in_review'),
  // QA
  ('qa_in_progress', 'qa_passed'),
  ('qa_in_progress', 'qa_failed'),
  ('qa_passed', 'waiting_for_human_decision'),
  ('qa_failed', 'waiting_for_human_decision'),
  ('waiting_for_human_decision', 'qa_passed'),
  ('waiting_for_human_decision', 'completed'),
  // Deployment
  ('qa_passed', 'deploying'),
  ('deploying', 'waiting_for_human_decision'),
  ('waiting_for_human_decision', 'deployed'),
  ('waiting_for_human_decision', 'deployment_failed'),
  ('deploying', 'deployed'),
  ('deploying', 'deployment_failed'),
  ('deployment_failed', 'deploying'),
  ('deployed', 'completed'),
  // generic escapes from every non-terminal state
  ('agent_executing', 'cancelled'),
  ('planning', 'terminated'),
];

void main() {
  group('plainTransitionMessage', () {
    test('every engine-accepted pair has dedicated plain copy', () {
      final unmatched = _engineAcceptedPairs
          .where((p) => knownTransitionMessage(p.$1, p.$2) == null)
          .toList();
      expect(
        unmatched,
        isEmpty,
        reason:
            'pairs produced by the engine must never hit the neutral '
            'default: $unmatched',
      );
    });

    test('default copy is plain, not a raw pair', () {
      expect(
        plainTransitionMessage('pending', 'running'),
        'The work moved to a new stage.',
      );
      expect(
        plainTransitionMessage('pending', 'running'),
        isNot('pending -> running'),
      );
    });

    test('known mappings use human copy, never the raw pair', () {
      expect(plainTransitionMessage('draft', 'planning'), 'Work created');
      expect(
        plainTransitionMessage('waiting_for_human_decision', 'deployed'),
        'Deploy approved',
      );
      expect(
        plainTransitionMessage('agent_executing', 'agent_completed'),
        'Agent finished its work',
      );
    });

    test('neutral default does not fabricate semantics for unknown pairs', () {
      expect(
        plainTransitionMessage('weirdFuture', 'alsoFuture'),
        'The work moved to a new stage.',
      );
    });
  });

  group('technical truth preservation', () {
    test('raw pair is always retrievable for known transitions', () {
      expect(
        rawTransitionPair('waiting_for_human_decision', 'deployed'),
        'waiting_for_human_decision -> deployed',
      );
    });

    test('raw pair is always retrievable for unknown transitions', () {
      expect(rawTransitionPair('pending', 'running'), 'pending -> running');
    });
  });
}
