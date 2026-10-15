import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/shared/transition_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE PROOF for the second false state recorded in
/// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §7.
///
/// The timeline rendered every `work_item_transition` row through
/// `plainTransitionMessage(from, to)`, which maps
/// `('agent_completed','review_in_progress')` to "Independent review started".
///
/// `work_item_transition` is an ATTEMPT log. `DurableWorkflowEngine.transition`
/// appends a row and changes NOTHING when the policy refuses the edge. On QA,
/// for a work item with a completed implementer and a failed reviewer, 236 of
/// those rows had `outcome = 'rejected'` — and all 236 were rendered as a
/// transition that never happened.
///
/// ## WHY BOTH DIRECTIONS ARE ASSERTED
///
/// "Refused rows are worded differently" is only half the fix. If `accepted`
/// rows were ALSO reworded, the screen would be technically accurate and
/// operationally useless: an operator could no longer read what actually
/// happened. So each direction is pinned separately, and the pairing
/// (`accepted` for one row, `rejected` for another, SAME pair) is what proves
/// the distinction is carried and not merely that the copy changed.
void main() {

  group('the refusal wording', () {
    test(
      'a refused agent_completed -> review_in_progress attempt is MARKED as '
      'not applied, so it cannot be read as a move',
      () {
        final message = timelineMessageFor(
          from: 'agent_completed',
          to: 'review_in_progress',
          outcome: 'rejected',
        );

        // The move copy is reused INVERTED, so the row NAMES the attempt it
        // failed to make. What it must never do is present that name bare —
        // `refusedTransitionPrefix` is the whole difference between the
        // operator reading "review started" and "a review was tried and not
        // applied", and it is the absence of this prefix that rendered 236
        // refused attempts on QA as 236 transitions.
        expect(message, startsWith(refusedTransitionPrefix));
        expect(
          message,
          isNot(
            plainTransitionMessage('agent_completed', 'review_in_progress'),
          ),
          reason:
              'equality with the bare move sentence is what an operator would '
              'have read as "review started". It must differ by the marker, and '
              'the marker is what makes it an attempt',
        );
      },
    );

    test('it names what was ATTEMPTED, in the product own vocabulary', () {
      final message = refusedTransitionMessage(
        'agent_completed',
        'review_in_progress',
      );

      // Reusing the move copy INVERTED, so the operator sees both halves: what
      // the platform wanted to do, and that it was not applied.
      expect(
        message,
        '$refusedTransitionPrefix${plainTransitionMessage('agent_completed', 'review_in_progress')}',
      );
      expect(message, 'Not applied — Independent review started');
    });

    test('it works for a pair with no dedicated copy too', () {
      final message = refusedTransitionMessage('a_state', 'another_state');

      expect(
        message,
        '$refusedTransitionPrefix$kUnknownTransitionMessage',
        reason:
            'an unknown pair must still be marked as not applied. Falling back '
            'to the bare unknown-copy here would drop the refusal marker and '
            'reintroduce the false state for exactly the pairs nobody wrote '
            'copy for',
      );
    });
  });

  group('the accepted direction is UNCHANGED', () {
    test(
      'an accepted agent_completed -> review_in_progress row still reads '
      '"Independent review started"',
      () {
        expect(
          timelineMessageFor(
            from: 'agent_completed',
            to: 'review_in_progress',
            outcome: 'accepted',
          ),
          plainTransitionMessage('agent_completed', 'review_in_progress'),
        );
        expect(
          timelineMessageFor(
            from: 'agent_completed',
            to: 'review_in_progress',
            outcome: 'accepted',
          ),
          'Independent review started',
        );
      },
    );

    test(
      'the two directions differ for the SAME pair — the distinction is '
      'carried, not incidental',
      () {
        final accepted = timelineMessageFor(
          from: 'agent_completed',
          to: 'review_in_progress',
          outcome: 'accepted',
        );
        final rejected = timelineMessageFor(
          from: 'agent_completed',
          to: 'review_in_progress',
          outcome: 'rejected',
        );

        expect(
          accepted,
          isNot(rejected),
          reason:
              'if these matched, an operator would have no way to tell a move '
              'from a refusal — which is the defect, not a wording preference',
        );
      },
    );
  });

  group('a MISSING outcome is treated as refused, not as accepted', () {
    test('null is not evidence that the item moved', () {
      final message = timelineMessageFor(
        from: 'agent_completed',
        to: 'review_in_progress',
        outcome: null,
      );

      expect(message, startsWith(refusedTransitionPrefix));
      expect(
        message,
        isNot(plainTransitionMessage('agent_completed', 'review_in_progress')),
        reason:
            'defaulting a null outcome to "accepted" reintroduces the original '
            'defect the moment a client meets a row without the field. An '
            'attempt whose outcome cannot be read is not a move',
      );
    });

    test('an unrecognised outcome value is also refused, not accepted', () {
      final message = timelineMessageFor(
        from: 'agent_completed',
        to: 'review_in_progress',
        outcome: 'something_new_the_platform_adds_later',
      );

      expect(message, startsWith(refusedTransitionPrefix));
    });
  });

  group('RunEvent carries the distinction', () {
    final refused = RunEvent(
      type: 'review_in_progress',
      message: 'Not applied — Independent review started',
      raw: 'agent_completed -> review_in_progress',
      timestamp: DateTime.utc(2026, 1, 1),
      outcome: 'rejected',
    );

    test('wasRefused is true for a rejected row', () {
      expect(refused.wasRefused, isTrue);
    });

    test('wasRefused is false for an accepted row', () {
      final accepted = RunEvent(
        type: 'review_in_progress',
        message: 'Independent review started',
        raw: 'agent_completed -> review_in_progress',
        timestamp: DateTime.utc(2026, 1, 1),
        outcome: 'accepted',
      );
      expect(accepted.wasRefused, isFalse);
    });

    test(
      'a REFUSED row never tints as handing control to the operator, whatever '
      'state it names',
      () {
        // `waiting_for_human_decision` is amber on an ACCEPTED row: it really
        // did hand over. On a refused one nothing was handed over, so tinting it
        // would claim a handover that never happened — the same category of
        // error as rendering the row as a move.
        final refusedHandover = RunEvent(
          type: 'waiting_for_human_decision',
          message: 'Not applied — Sent to you for approval',
          raw: 'x -> waiting_for_human_decision',
          timestamp: DateTime.utc(2026, 1, 1),
          outcome: 'rejected',
        );
        expect(refusedHandover.needsOperator, isFalse);

        final acceptedHandover = RunEvent(
          type: 'waiting_for_human_decision',
          message: 'Sent to you for approval',
          raw: 'x -> waiting_for_human_decision',
          timestamp: DateTime.utc(2026, 1, 1),
          outcome: 'accepted',
        );
        expect(acceptedHandover.needsOperator, isTrue);
      },
    );
  });
}